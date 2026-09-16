#!/bin/bash -
#
# Launcher for the ATLAS pre-processing tools.
#
# Usage:  ATLAS <TOOL> [options]      (options may also precede the tool name)

# If ATLASDIR is not set (e.g. when invoked directly from CTest without
# sourcing the user's shell rc file), derive it from the location of this
# script so that all bin/ and src/ references still resolve correctly.
if [[ -z "${ATLASDIR:-}" ]]; then
  ATLASDIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
fi

# Conda environment holding the Python dependencies. Override with
# ATLAS_CONDA_ENV, or bypass conda entirely by pointing ATLAS_PYTHON at an
# interpreter that already has them (e.g. after './install.sh build --no-conda').
CONDA_ENV="${ATLAS_CONDA_ENV:-ct-env}"

function print_usage {
  cat <<'EOF'
Bash script to run ATLAS programs

Usage:
   ATLAS <TOOL> [options]

Hydra pre-processing tools:
   ATLAS GPB
   ATLAS BCB
   ATLAS BCB-GUI
   ATLAS ICB
   ATLAS STB
   ATLAS MDB

Other tools:
   ATLAS CEA <file>
   ATLAS KAnT

Repo documentation:
   ATLAS DOCS

Options:
   --input     | -i <file>   Input file (default: input.ini)
   --verbose   | -v          Verbose output (BCB, ICB, MDB, STB)
   --output    | -o <fmt>    STB output format (default: tec-ascii)
   --plot      | -p          Produce plots (KAnT only)
   --write-config-doc        Regenerate the tool's input-reference page and exit
   --help      | -h          Show this message

Environment:
   ATLASDIR         ATLAS root (auto-detected from this script if unset)
   ATLAS_CONDA_ENV  Conda env with the Python deps (default: ct-env)
   ATLAS_PYTHON     Python interpreter to use instead of activating conda
EOF
}

if [ $# -eq 0 ]; then
  echo "Empty input" >&2
  echo >&2
  print_usage >&2
  exit 1
fi

# ---------------------------------------------------------------- arguments --
TOOLS=()
INPUT=""
EXTRA=()        # trailing args after '--', passed through verbatim
V=""
P=""
W=""

while [ $# -gt 0 ]; do
  case $1 in
    -- )
      shift
      EXTRA+=("$@")
      break
      ;;
    --verbose | -v )
      V="-v"; shift ;;
    --plot | -p )
      P="--plot"; shift ;;
    --write-config-doc )
      W="--write-config-doc"; shift ;;
    --input | -i )
      if [ $# -lt 2 ]; then
        echo "[ERROR] $1 requires a file argument" >&2
        exit 1
      fi
      INPUT="$2"; shift 2 ;;
    --input=* )
      INPUT="${1#*=}"; shift ;;
    -h | --help | -\? )
      print_usage
      exit 0 ;;
    -* )
      echo "[ERROR] Unrecognized option: $1" >&2
      echo >&2
      print_usage >&2
      exit 1 ;;
    * )
      TOOLS+=("$1"); shift ;;
  esac
done

if [ ${#TOOLS[@]} -eq 0 ]; then
  echo "[ERROR] No tool specified" >&2
  echo >&2
  print_usage >&2
  exit 1
fi

if [ -n "$INPUT" ] && [ ! -f "$INPUT" ]; then
  echo "[ERROR] Input file not found: $INPUT" >&2
  exit 1
fi

# ------------------------------------------------------------ python runner --
# Echoes the command prefix needed to run a Python tool, activating conda only
# when ATLAS_PYTHON is not set. Returns non-zero (with a message) if neither a
# usable interpreter nor conda is available.
function activate_python_env {
  if [ -n "${ATLAS_PYTHON:-}" ]; then
    if ! command -v "$ATLAS_PYTHON" >/dev/null 2>&1; then
      echo "[ERROR] ATLAS_PYTHON is set to '$ATLAS_PYTHON', which is not executable." >&2
      return 1
    fi
    return 0
  fi

  if ! command -v conda >/dev/null 2>&1; then
    echo "[ERROR] 'conda' was not found on PATH, and it is needed to run the Python tools." >&2
    echo "        Create the environment:  conda env create -f $ATLASDIR/ct-env.yaml" >&2
    echo "        Or, for a --no-conda install, point ATLAS_PYTHON at an interpreter" >&2
    echo "        that already has cantera, coolprop, numpy<2 and pyyaml installed." >&2
    return 1
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(conda shell.zsh hook)" || return 1
  else
    eval "$(conda shell.bash hook)" || return 1
  fi

  if ! conda activate "$CONDA_ENV" 2>/dev/null; then
    echo "[ERROR] Could not activate conda environment '$CONDA_ENV'." >&2
    echo "        Create it with:  conda env create -f $ATLASDIR/ct-env.yaml" >&2
    echo "        Or select another one with ATLAS_CONDA_ENV=<name>." >&2
    return 1
  fi
  CONDA_ACTIVATED=1
  return 0
}

function deactivate_python_env {
  if [ -n "${CONDA_ACTIVATED:-}" ]; then
    conda deactivate
    unset CONDA_ACTIVATED
  fi
}

function python_bin {
  echo "${ATLAS_PYTHON:-python3}"
}

# ------------------------------------------------------------------- driver --
status=0
NEED_FILELIST=0
for program in "${TOOLS[@]}"; do
  case $program in
    BCB | ICB | MDB | STB ) NEED_FILELIST=1 ;;
  esac
done

# The Fortran tools discover '*phase.txt' through this listing (see
# src/common/read_phase.f90). Only create it when one of them will run, and
# never clobber a file the user already has.
FILELIST_CREATED=0
if [ "$NEED_FILELIST" -eq 1 ] && [ ! -e filelist.txt ]; then
  ls *phase.txt > filelist.txt 2>/dev/null
  FILELIST_CREATED=1
fi

for program in "${TOOLS[@]}"; do
  case $program in

    CEA )
      "$ATLASDIR/build/lib/cea/source/cea" ${INPUT:+"$INPUT"} "${EXTRA[@]}"
      status=$?
      ;;

    DOCS )
      if activate_python_env; then
        "$(python_bin)" -B "$ATLASDIR/src/GPB" --write-config-doc || status=$?
        deactivate_python_env
      else
        status=1
      fi
      for t in BCB ICB STB MDB; do
        "$ATLASDIR/bin/$t" --write-config-doc || status=$?
      done
      ;;

    BCB-GUI )
      if activate_python_env; then
        "$(python_bin)" -B "$ATLASDIR/GUI/BCB_GUI.py" \
          ${INPUT:+--ini "$INPUT"} "${EXTRA[@]}"
        status=$?
        deactivate_python_env
      else
        status=1
      fi
      ;;

    GPB )
      if activate_python_env; then
        # GPB spells the option '--input-file' and has no '--plot'.
        [ -n "$P" ] && echo "[WARN] GPB does not support --plot; ignoring." >&2
        "$(python_bin)" -B "$ATLASDIR/src/GPB" \
          ${INPUT:+--input-file "$INPUT"} $W "${EXTRA[@]}"
        status=$?
        deactivate_python_env
      else
        status=1
      fi
      ;;

    KAnT )
      if activate_python_env; then
        "$(python_bin)" -B "$ATLASDIR/database/KAnT" $P "${EXTRA[@]}"
        status=$?
        deactivate_python_env
      else
        status=1
      fi
      ;;

    BCB | ICB | MDB | STB )
      if [ ! -x "$ATLASDIR/bin/$program" ]; then
        echo "[ERROR] $program is not built: $ATLASDIR/bin/$program not found." >&2
        echo "        Build it with:  ./install.sh build" >&2
        status=1
      else
        "$ATLASDIR/bin/$program" ${INPUT:+--input "$INPUT"} $V $W "${EXTRA[@]}"
        status=$?
      fi
      ;;

    * )
      echo "[ERROR] Unknown tool: $program" >&2
      echo >&2
      print_usage >&2
      status=1
      ;;
  esac

  [ $status -ne 0 ] && break
done

[ "$FILELIST_CREATED" -eq 1 ] && rm -f filelist.txt

exit $status
