#!/bin/bash

set -e  # Exit on any command failure
set -u  # Treat unset variables as an error

PROGRAM=$(basename "$0")
readonly DIR=$(pwd)
BUILD_DIR="$DIR/build"
VERBOSE=false

function usage() {
    cat <<EOF

Install script for ATLAS

Usage:
  $PROGRAM [GLOBAL_OPTIONS] COMMAND [COMMAND_OPTIONS]

Global Options:
  -h       , --help         Show this help message and exit
  -v       , --verbose      Enable verbose output

Commands:
  build                     Perform a full build
    --compiler=<name>       Set compilers suit (intel,gnu)
    --master=<name>         Set master (None, hydra)
    --use-openmp            Use OpenMP
    --use-tecio             Use TecIO

  compile                   Compile the program using the CMakePresets file

  update                    Download git submodules
    --remote                Use the latest remote commit

  setvars                   Set project paths in environment variables

EOF
    exit 1
}


function log() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
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


# Create default CMakePresets.json if it doesn't exist
function write_presets() {
  FC=$(grep '^CMAKE_Fortran_COMPILER:FILEPATH=' "$BUILD_DIR/CMakeCache.txt" | cut -d= -f2-)
  CXX=$(grep '^CMAKE_CXX_COMPILER:FILEPATH=' "$BUILD_DIR/CMakeCache.txt" | cut -d= -f2-)

  cat <<EOF > CMakePresets.json
{
  "version": 3,
  "cmakeMinimumRequired": {
    "major": 3,
    "minor": 23
  },
  "configurePresets": [
    {
      "name": "default",
      "description": "Default preset",
      "binaryDir": "\${sourceDir}/build",
      "cacheVariables": {
        "MASTER": "${MASTER_TYPE}",
        "CMAKE_BUILD_TYPE": "${BUILD_TYPE}",
        "CMAKE_Fortran_COMPILER": "${FC}",
        "CMAKE_CXX_COMPILER": "${CXX}",
        "USE_TECIO": "${USE_TECIO}",
        "USE_OPENMP": "${USE_OPENMP}"
      }
    }
  ]
}
EOF

}


# Default global values
COMMAND=""
MASTER_TYPE=""
COMPILERS=""
USE_OPENMP="false"
USE_TECIO="false"
REMOTE="false"
BUILD_TYPE="RELEASE"

# Define allowed options for each command using regular arrays
CMD_OPTIONS_BUILD=("--master" "--compilers" "--use-openmp" "--use-tecio")
CMD_OPTIONS_UPDATE=("--remote")

# Parse options with getopts
while getopts "hv:-:" opt; do
    case "$opt" in
        -)
            case "$OPTARG" in
                verbose) VERBOSE=true ;;
                help) usage ;;
                *) echo "Error: Unknown global option '--$OPTARG'"; usage ;;
            esac
            ;;
        h) usage ;;
        v) VERBOSE=true ;;
        *) echo "Error: Unknown global option '-$opt'"; usage ;;
    esac
done
shift $((OPTIND -1))

# Ensure a command was provided
if [[ $# -eq 0 ]]; then
    echo "Error: No command provided!"
    usage
fi

COMMAND="$1"
shift

# Parse command-specific options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --master=*)
            [[ "$COMMAND" == "build" ]] || { echo "Error: --master is only valid for 'build' command"; exit 1; }
            if [[ ! "$1" =~ ^--master=(None|hydra)$ ]]; then
                echo "Error: Invalid value for --master. Valid values are 'None' or 'hydra'."
                exit 1
            fi
            MASTER_TYPE="${1#*=}"
            ;;
        --compilers=*)
            [[ "$COMMAND" == "build" ]] || { echo "Error: --compilers is only valid for 'build' command"; exit 1; }
            if [[ ! "$1" =~ ^--compilers=(intel|gnu)$ ]]; then
                echo "Error: Invalid value for --compilers. Valid values are 'intel' or 'gnu'."
                exit 1
            fi
            COMPILERS="${1#*=}"
            ;;       
        --use-openmp)
            [[ "$COMMAND" == "build" ]] || { echo "Error: --use-openmp is only valid for 'build' command"; exit 1; }
            USE_OPENMP="true"
            ;;
        --use-tecio)
            [[ "$COMMAND" == "build" ]] || { echo "Error: --use-tecio is only valid for 'build' command"; exit 1; }
            USE_TECIO="true"
            ;;
        --remote)
            [[ "$COMMAND" == "update" ]] || { echo "Error: --remote is only valid for 'update' command"; exit 1; }
            REMOTE="true"
            ;;
        *)
            echo "Error: Unknown option '$1' for command '$COMMAND'. Valid options: ${CMD_OPTIONS_$COMMAND[@]}"
            exit 1
            ;;
    esac
    shift
done


# Execute the selected command
case "$COMMAND" in
    build)
        if [[ -z "$MASTER_TYPE" ]]; then
            echo "Error: --master is required for the 'build' command!"
            exit 1
        fi
        log "Building project with master: $MASTER_TYPE"
        log "Use OpenMP: $USE_OPENMP"
        log "Use TecIO: $USE_TECIO"
        rm -rf $BUILD_DIR
        if [[ $MASTER_TYPE == "None" ]]; then
          log "Stand-alone building"
          git submodule update --init --recursive
        elif [[ $MASTER_TYPE == "hydra" ]]; then
          log "Hydra-related building"
          git submodule update --init lib/NewCEA
          git submodule update --init lib/PiNeR
        fi
        if [[ $COMPILERS == "intel" ]]; then 
            log "Using Intel compilers"
            export FC=ifx
            export CC=icx
            export CXX=icpx
        elif [[ $COMPILERS == "gnu" ]]; then 
            log "Using GNU compilers"
            export FC=gfortran
            export CC=gcc
            export CXX=g++
        fi
        # Compile the project
        cmake -B $BUILD_DIR -DMASTER=$MASTER_TYPE -DUSE_TECIO=$USE_TECIO -DUSE_OPENMP=$USE_OPENMP -DCMAKE_BUILD_TYPE=$BUILD_TYPE || exit 1
        cmake --build $BUILD_DIR || exit 1
        # Write CMakePresets.json
        echo -e "\033[0;34mWrite CMakePresets.json ...\033[0m"
        write_presets
        # Define environment variables
        echo -e "\033[0;34mDefine environment variables ...\033[0m"
        cd lib/NewCEA
        ./install.sh setvars
        cd $DIR
        define_path
        # Create Conda environment
        echo -e "\033[0;34mCreate Conda environment...\033[0m"
        #conda env remove --name ct-env --yes
        conda env create -f ct-env.yaml
        echo -e "\033[0;32mInstallation completed successfully.\033[0m"
        ;;
    compile)
        # Configure and build using the default preset
        cmake --preset default || exit 1
        cmake --build build || exit 1
        ;;
    update)
        if [[ "$REMOTE" == "true" ]]; then
            log "Updating submodules to latest remote commit"
            git submodule update --init --remote
        else
            log "Updating submodules to current commit"
            git submodule update --init
        fi
        ;;
    setvars)
        log "Setting project environment variables"
        define_path
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        usage
        ;;
esac