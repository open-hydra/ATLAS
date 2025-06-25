#!/bin/bash -
#===============================================================================
#
#          FILE: ATLAS.sh
#
#         USAGE: run "./ATLAS.sh [options]"
#
#   DESCRIPTION: A utility script to launch ATLAS programs
#
#       OPTIONS:
#         --verbose, -v   Enable verbose mode
#         --plot, -p      Enable plot generation
#         --help, -?      Display this help message
#
#       ARGUMENTS:
#         CEA             Run the CEA program with the specified input file
#         GPB, KAnT       Run the specified Python-based ATLAS program
#         ICB, BCB        Run the specified Fortran-based ATLAS program
#         YTF             Run the specified Python-based ATLAS program
#       EXAMPLES:
#         ./ATLAS.sh --verbose GPB
#         ./ATLAS.sh CEA inputfile
#
#===============================================================================
function print_usage {
  echo "Bash srcipt to run ATLAS programs"
  echo "CFD pre-processing tools:"
  echo "   ATLAS GPB"
  echo "   ATLAS BCB"
  echo "   ATLAS ICB"
  echo "   ATLAS YTF"
  echo
  echo "General tools:"
  echo "   ATLAS CEA"
  echo "   ATLAS KAnT"
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

    -? | --help )
      usage
      exit
      ;;

    -* )
      echo "Unrecognized option: $1" >&2
      usage
      exit $E_BAD_OPTION
      ;;

    * )
      break
      ;;
  esac
done

if [[ $1 == CEA ]]; then
  cp $2.inp CEAfile.inp
  echo CEAfile >> fileInput
  $NewCEADIR/bin/FCEA2 < fileInput
  rm fileInput CEAfile.inp
  mv CEAfile.out $2.out
  mv CEAfile.plt $2.plt 2>/dev/null
else
  for program in $@; do
    if [[ $program == 'GPB' || $program == 'KAnT' || $program == 'YTF' || $program == 'equilibrate' ]]; then
      # Try to find the path to the conda executable
      CONDA_EXE=$(command -v conda)
      if [ -z "$CONDA_EXE" ]; then
          echo "conda not found in PATH"
          exit 1
      fi
      # Derive the base path of the conda installation
      CONDA_BASE=$(dirname "$(dirname "$CONDA_EXE")")
      # Source the conda.sh script
      source "$CONDA_BASE/etc/profile.d/conda.sh"
      conda activate ct-env
      python3 -B $ATLASDIR/src/$program/$program.py $P
      conda deactivate
    else
      ls *phase.txt > filelist.txt 2>/dev/null
      $ATLASDIR/bin/$program $V
      rm -f filelist.txt
    fi
  done
fi
