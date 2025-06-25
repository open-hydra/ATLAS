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
  #echo 'export PATH="$ATLASDIR/database/:$PATH"' >> .setvars.sh
  grep -v "ATLAS" $RCFILE > tmpfile && mv tmpfile $RCFILE
  echo 'source '$DIR'/.setvars.sh' >> $RCFILE
}

function create_env () {
  echo -e "\033[0;34mCreating Conda environment...\033[0m"
  cd $DIR
  #conda env remove --name ct-env --yes
  conda env create -f ct-env.yaml
}

function compile_fortran () {
  echo -e "\033[0;34mBuilding Fortran sources via CMake...\033[0m"
  mkdir -p $DIR/build
  cd $DIR/build
  cmake .. -DUSE_TECIO=OFF -DCMAKE_BUILD_TYPE=$TYPE -DMASTER=$Master
  make $EXE
}

function build_project () {

  rm -rf bin build
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
    git submodule update --init lib/NewCEA
    git submodule update --init lib/PiNeR
  fi

  echo -e "\033[0;34mAdd NewCEA path ...\033[0m"
  cd lib/NewCEA
  ./install.sh -s
  cd $DIR

  compile_fortran

  create_env

  echo -e "\033[0;32mInstallation completed successfully.\033[0m"
}

EXE=F
TYPE=F
SETVARS=F
UPDATE=F
LOAD=F
BUILD=F
COMPILE=F

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
      TYPE=RELEASE
      EXE=''
      ;;

    --compile | -c )
      shift
      if [ "$1" != "RELEASE" ] && [ "$1" != "DEBUG" ] && [ "$1" != "TESTING" ]; then
        EXE="$1"
      else
        TYPE="$1"
        EXE="$2"
      fi
      COMPILE=T
      if [ -n "$HYDRADIR" ]; then
        Master=hydra
      else
        Master=None
      fi
      ;;

    --setvars | -s )
      shift
      SETVARS=T
      ;;

    --update | -u )
      shift
      UPDATE=T
      ;;

    --load | -l )
      shift
      LOAD=T
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

if [ "$SETVARS" != "F" ]; then
  define_path

elif [ "$UPDATE" != "F" ]; then
  git submodule update --init --remote

elif [ "$LOAD" != "F" ]; then
  git submodule update --init

elif [[ "$BUILD" != "F" ]]; then
  define_path
  build_project

elif [[ "$COMPILE" != "F" ]]; then
  compile_fortran

else
  usage
fi
