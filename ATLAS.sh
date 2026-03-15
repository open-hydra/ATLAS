#!/bin/bash -

function print_usage {
  echo "Bash srcipt to run ATLAS programs"
  echo "CFD pre-processing tools:"
  echo "   ATLAS GPB"
  echo "   ATLAS BCB"
  echo "   ATLAS BCB-Q2D"
  echo "   ATLAS ICB"
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
    if [[ $program == 'GPB' || $program == 'KAnT' ]]; then
      if [ -n "$ZSH_VERSION" ]; then
          eval "$(conda shell.zsh hook)"
      elif [ -n "$BASH_VERSION" ]; then
          eval "$(conda shell.bash hook)"
      fi
      conda activate ct-env
      python3 -B $ATLASDIR/src/$program $P
      conda deactivate
    else
      ls *phase.txt > filelist.txt 2>/dev/null
      $ATLASDIR/bin/$program $V
      rm -f filelist.txt
    fi
  done
fi
