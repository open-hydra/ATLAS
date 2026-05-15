#!/bin/bash -

# If ATLASDIR is not set (e.g. when invoked directly from CTest without
# sourcing the user's shell rc file), derive it from the location of this
# script so that all bin/ and src/ references still resolve correctly.
if [[ -z "${ATLASDIR:-}" ]]; then
  ATLASDIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
fi

function print_usage {
  echo "Bash script to run ATLAS programs"
  echo "Hydra pre-processing tools:"
  echo "   ATLAS GPB"
  echo "   ATLAS BCB"
  echo "   ATLAS ICB"
  echo "   ATLAS STB"
  echo
  echo "Other tools:"
  echo "   ATLAS CEA"
  echo "   ATLAS KAnT"
  echo
  echo "Repo documentation:"
  echo "   ATLAS DOCS"
  echo
  echo "Options:"
  echo "   --input     | -i <file>   Input file (default: input.ini)"
  exit 1
}

if [ $# -eq 0 ] ; then
  echo "Empty input"
  echo
  print_usage
fi

if [[ $SHELL == *"zsh"* ]]; then
  RCFILE=$HOME/.zshrc
elif [[ $SHELL == *"bash"* ]]; then
  RCFILE=$HOME/.bashrc
fi

while test $# -gt 0; do
  if [ x"$1" == x"--" ]; then
    # detect argument termination
    shift
    break
  fi
  case $1 in

    --verbose | -v )
      shift
      V=-v
      ;;

    --plot | -p )
      shift
      P=--plot
      ;;

    --write-config-doc )
      shift
      W=--write-config-doc
      ;;

    -? | --help )
      print_usage
      exit
      ;;

    -* )
      echo "Unrecognized option: $1" >&2
      print_usage
      exit $E_BAD_OPTION
      ;;

    * )
      break
      ;;
  esac
done

if [[ $1 == CEA ]]; then
  $ATLASDIR/build/lib/cea/source/cea $2
else
  ls *phase.txt > filelist.txt 2>/dev/null
  for program in $@; do
    if [[ $program == 'DOCS' ]]; then
      if [ -n "$ZSH_VERSION" ]; then
          eval "$(conda shell.zsh hook)"
      elif [ -n "$BASH_VERSION" ]; then
          eval "$(conda shell.bash hook)"
      fi
      conda activate ct-env
      python3 -B $ATLASDIR/src/GPB --write-config-doc
      conda deactivate
      $ATLASDIR/bin/BCB --write-config-doc
      $ATLASDIR/bin/ICB --write-config-doc
      $ATLASDIR/bin/STB --write-config-doc
    elif [[ $program == 'GPB' || $program == 'KAnT' ]]; then
      if [ -n "$ZSH_VERSION" ]; then
          eval "$(conda shell.zsh hook)"
      elif [ -n "$BASH_VERSION" ]; then
          eval "$(conda shell.bash hook)"
      fi
      conda activate ct-env
      if [[ $program == 'GPB' ]]; then
        python3 -B $ATLASDIR/src/$program $P $W
      else
        python3 -B $ATLASDIR/database/$program $P
      fi
      conda deactivate
    else
      $ATLASDIR/bin/$program $V $W
    fi
  done
  rm -f filelist.txt
fi
