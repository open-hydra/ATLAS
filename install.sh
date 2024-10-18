#!/bin/bash -
#===============================================================================
#
#          FILE: intstall.sh
#
#         USAGE: run "./install.sh [options]" from ATLAS master directory
#
#   DESCRIPTION: A utility script that builds ATLAS project
#===============================================================================

# DEBUGGING
set -e
set -C # noclobber

# INTERNAL VARIABLES AND INITIALIZATIONS
readonly PROJECT="ATLAS"
readonly DIR=$(pwd)
readonly PROGRAM=`basename "$0"`

function usage () {
    echo "Install script of $PROJECT"
    echo "Usage:"
    echo
    echo "$PROGRAM --help|-?"
    echo "    Print this usage output and exit"
    echo
    echo "$PROGRAM --build  |-b <master>"
    echo "    Build the project and libraries via CMake (<master> = standalone,hydra)"
    echo
    echo "$PROGRAM --compile|-c <build> <program>"
    echo "    Compile a program with a build type (<build> = RELEASE,DEBUG,TESTING)"
    echo
    echo "$PROGRAM --setvars|-s"
    echo "    Set the project paths in the environment variables"
    echo
    echo "$PROGRAM --update |-u"
    echo "    Download the latest version of each submodule"
    echo
    echo "$PROGRAM --load |-l"
    echo "    Download the current version of each submodule"
    echo
}


function define_path () {
  rm -f .setvars.sh

  echo 'export ATLASDIR='$DIR >> .setvars.sh
  if [[ $SHELL == *"zsh"* ]]; then
    echo 'ATLAS () { '$DIR'/ATLAS.sh $@; }' >> .setvars.sh
    RCFILE=$HOME/.zshrc
  elif [[ $SHELL == *"bash"* ]]; then
    echo 'function ATLAS () { '$DIR'/ATLAS.sh $@; }' >> .setvars.sh
    RCFILE=$HOME/.bashrc
  fi
  echo 'export -f ATLAS' >> .setvars.sh
  grep -v "ATLAS" $RCFILE > tmpfile && mv tmpfile $RCFILE
  echo 'source '$DIR'/.setvars.sh' >> $RCFILE
  source $RCFILE --force
}


function build_fortran_side () {

  rm -rf bin build && mkdir -p build
  if [[ $BUILD == standalone ]]; then
    echo 
    echo -e "\033[0;32mStand-alone building \033[0m"
    echo
    git submodule update --init --recursive
    Master=None
  elif [[ $BUILD == "hydra" ]]; then 
    echo
    echo -e "\033[0;32mHydra-related building \033[0m"
    echo
    Master=hydra
  fi
  cd $DIR/build
  cmake .. -DUSE_OPENMP=OFF -DUSE_TECIO=OFF -DCMAKE_BUILD_TYPE=RELEASE -DMASTER=$Master
  cmake --build .
}

function build_python_side () {

  if [[ $SHELL == *"zsh"* ]]; then
    RCFILE=$HOME/.zshrc
  elif [[ $SHELL == *"bash"* ]]; then
    RCFILE=$HOME/.bashrc
  fi
  cd $DIR
  conda env create -f ct-env.yaml
  source $RCFILE --force 2>/dev/null
  conda activate ct-env
  cd $DIR/lib/PiNeR
  pip3 install -e .
  cd $DIR/lib/NewCEA
  ./install.sh -b
  pip3 install -e .
  conda deactivate
}

function compile () {
  mkdir -p build
  cd build
  cmake .. -DUSE_TECIO=OFF -DCMAKE_BUILD_TYPE=$TYPE -DMASTER=None
  make $EXE
}


EXE=0
TYPE=0
SETVARS=0
UPDATE=0
LOAD=0
BUILD=0

# RETURN VALUES/EXIT STATUS CODES
readonly E_BAD_OPTION=254

# PROCESS COMMAND-LINE ARGUMENTS
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

while test $# -gt 0; do
  if [ x"$1" == x"--" ]; then
    # detect argument termination
    shift
    break
  fi
  case $1 in

    --build | -b )
      shift
      if (( $# > 0 )); then
        BUILD=$1
      else
        BUILD=standalone
      fi
      ;;

    --compile | -c )
      shift
      if [ "$1" != "RELEASE" ] && [ "$1" != "DEBUG" ] && [ "$1" != "TESTING" ]; then
        EXE="$1"
      else
        TYPE="$1"
        EXE="$2"
      fi
      ;;

    --setvars | -s )
      shift
      SETVARS=1
      ;;

    --update | -u )
      shift
      UPDATE=1
      ;;

    --load | -l )
      shift
      LOAD=1
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

if [ "$SETVARS" != "0" ]; then
  define_path

elif [ "$UPDATE" != "0" ]; then
  git submodule update --init --remote

elif [ "$LOAD" != "0" ]; then
  git submodule update --init

elif [[ "$BUILD" != "0" ]]; then
  define_path
  #build_fortran_side
  build_python_side

elif [[ "$EXE" != "0" ]]; then
  compile

else
  usage
fi
