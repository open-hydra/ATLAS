#!/bin/bash -
function print_usage {
  echo "Bash srcipt for running ATLAS programs"
  echo "CFD pre-processing tools:"
  echo "   ATLAS GPB"
  echo "   ATLAS BCB"
  echo "   ATLAS ICB"
  echo
  echo "General tools:"
  echo "   ATLAS CEA"
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

if [[ $1 == CEA ]]; then
  #!> CEA
  $ATLASDIR/lib/CEA_wrapper.sh -run $2
else
  for i in $@; do
    if [[ $i == 'GPB' ]]; then
      source $RCFILE > /dev/null 2>&1
      conda activate ct-env
      python3 -B $ATLASDIR/GPB/GPB.py
      conda deactivate
    else
      $ATLASDIR/bin/$i
    fi
  done
fi
