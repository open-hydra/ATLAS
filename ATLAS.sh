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
export ATLASDIR   # GPB (src/GPB/config.py) reads it from the environment

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
   ATLAS GUI        (the case: GPB, BCB and ICB sections, and their runs)
   ATLAS BCB-GUI    (the same GUI, opened on the boundaries stage)
   ATLAS ICB
   ATLAS STB
   ATLAS MDB

Other tools:
   ATLAS CEA <file>
   ATLAS KAnT

Repo documentation:
   ATLAS DOCS

Every tool runs in the case directory: it reads the mesh there, and its setup in
input.ini (written by 'ATLAS GUI', or by hand), and writes into
fromATLAStoSolver/. BCB, ICB and MDB read each *phase.txt of the case
directory, else the one GPB wrote into fromATLAStoSolver/, so that
'ATLAS GPB BCB ICB' needs no copy; of fromATLAStoSolver/, BCB and ICB read
only the phases of the [GPB-Phase*] sections of the INI, when it has some.

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

# The phase file each [GPB-Phase<N>] section of the INI $1 makes GPB write, N = 1, 2, ... up to the
# first missing, as GPB reads them (src/GPB/ini/common.py): <name>-phase.txt, or phase.txt for a
# phase with no name.
function gpb_phase_files {
  awk '
    { line = $0; sub(/\r$/, "", line); sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
    line == "" || line ~ /^[#;]/ { next }
    line ~ /^\[.*\]$/ { sec = substr(line, 2, length(line) - 2); if (sec ~ /^GPB-Phase[0-9]+$/) seen[sec] = 1; next }
    sec ~ /^GPB-Phase[0-9]+$/ && tolower(line) ~ /^name[ \t]*[=:]/ {
      v = line; sub(/^[^=:]*[=:][ \t]*/, "", v); name[sec] = v
    }
    END { for (k = 1; ("GPB-Phase" k) in seen; k++) print (name["GPB-Phase" k] != "" ? name["GPB-Phase" k] "-" : "") "phase.txt" }
  ' "$1"
}

# BCB and ICB discover the '*phase.txt' through filelist.txt (see
# src/common/read_phase.f90): those of the case directory (written by hand, or
# copied there) and those GPB wrote into fromATLAStoSolver/; the tools read each
# from the case directory when it is there, else from fromATLAStoSolver/
# (phase_dir in src/common/global.f90). Of fromATLAStoSolver/, only the phase
# files of the [GPB-Phase*] sections of the INI are listed, when it has some:
# GPB never removes a file there, so the phase of an earlier deck stays. It is
# written again before each of them runs, so that in 'ATLAS GPB BCB' BCB finds
# what GPB has just written, and removed at the end; a filelist.txt the user
# already has is used as it is.
USER_FILELIST=0
[ -e filelist.txt ] && USER_FILELIST=1
FILELIST_CREATED=0
function write_filelist {
  [ "$USER_FILELIST" -eq 1 ] && return
  local ini="${INPUT:-input.ini}" declared="" listed="" name
  [ -f "$ini" ] && declared=$(gpb_phase_files "$ini")
  for name in $( { ls *phase.txt; cd fromATLAStoSolver && ls *phase.txt; } 2>/dev/null | sort -u); do
    if [ ! -f "$name" ] && [ -n "$declared" ] && ! grep -qxF "$name" <<< "$declared"; then
      echo "[WARNING] fromATLAStoSolver/$name is not read: no [GPB-Phase*] section of $ini writes it (an earlier GPB run left it)" >&2
      continue
    fi
    if [ -f "$name" ] && [ -f "fromATLAStoSolver/$name" ] && ! cmp -s "$name" "fromATLAStoSolver/$name"; then
      if [ -z "$declared" ] || grep -qxF "$name" <<< "$declared"; then
        echo "[WARNING] $name of the case directory is read, not the one GPB wrote into fromATLAStoSolver/: remove it to read GPB's" >&2
      fi
    fi
    listed+="$name"$'\n'
  done
  printf '%s' "$listed" > filelist.txt
  FILELIST_CREATED=1
}

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

    GUI )
      if activate_python_env; then
        "$(python_bin)" -B "$ATLASDIR/GUI/ATLAS_GUI.py" \
          ${INPUT:+--ini "$INPUT"} "${EXTRA[@]}"
        status=$?
        deactivate_python_env
      else
        status=1
      fi
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
        # The automatic arrays of the Fortran tools live on the stack: ICB on a 3-D mesh (IG-nozzle3D)
        # overflows the default 8 MB and dies with SIGSEGV. Raise the soft limit, as figaro does for the
        # solvers and the CI before ctest; a hard limit below unlimited keeps whatever it allows.
        ulimit -s unlimited 2>/dev/null || true
        case $program in BCB | ICB ) write_filelist ;; esac
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
