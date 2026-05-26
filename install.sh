#!/bin/bash

set -e  # Exit on any command failure
set -u  # Treat unset variables as an error

PROGRAM=$(basename "$0")
readonly DIR=$(pwd)
BUILD_DIR="$DIR/build"
SVFILE="$DIR/scripts/setvars.sh"
VERBOSE=false
project=ATLAS

function usage() {
    cat <<EOF

Install script for ATLAS

Usage:
  $PROGRAM [GLOBAL_OPTIONS] COMMAND [COMMAND_OPTIONS]

Global Options:
  -v       , --verbose      Enable verbose output

Commands:
  build                     Perform a full build
    --compilers=<name>      Set compilers suite (intel,gnu)
    --include-cea=<path>    Set external CEA path
    --include-orion=<path>  Set external ORION path
    --include-finer=<path>  Set external FiNeR path
    --use-openmp            Use OpenMP
    --use-tecio             Use TecIO
    --no-conda              Do not create Conda environment

EOF
    exit 1
}


log() {
    if [ "$VERBOSE" = true ]; then
      # Bold and dim gray (ANSI escape: bold + color 90)
      echo -e "\033[1;90m$1\033[0m"
    fi
}

error() {
    # Bold red + [ERROR] tag, output to stderr
    echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
}

task() {
    # Bold yellow + ==> tag, output to stdout
    echo -e "\033[1;38;5;186m==> $1\033[0m"
}


function define_path () {
  rm -f $SVFILE

  echo 'export ATLASDIR='$DIR >> $SVFILE
  echo 'if [[ -f "$ATLASDIR/build/thermo.lib" ]]; then export CEA_DATA_DIR="$ATLASDIR/build"; fi' >> $SVFILE
  if [[ $SHELL == *"zsh"* ]]; then
    echo 'ATLAS () { '$DIR'/ATLAS.sh $@; }' >> $SVFILE
    RCFILE=$HOME/.zshrc
  elif [[ $SHELL == *"bash"* ]]; then
    echo 'function ATLAS () { '$DIR'/ATLAS.sh $@; }' >> $SVFILE
    RCFILE=$HOME/.bashrc
  fi
  log "RC file: $RCFILE"
  echo 'export -f ATLAS' >> $SVFILE
  grep -v "ATLAS" $RCFILE > tmpfile && mv tmpfile $RCFILE
  echo 'source '$SVFILE'' >> $RCFILE
  source $SVFILE
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
        "ORION_PATH": "${ORION_PATH}",
        "FINER_PATH": "${FINER_PATH}",
        "CEA_PATH": "${CEA_PATH}",
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
  log "CMakePresets.json created with default settings."
}


# Default global values
COMMAND=""
COMPILERS=""
CEA_PATH=$(pwd)'/lib/cea/'
ORION_PATH=$(pwd)'/lib/ORION/'
FINER_PATH=$(pwd)'/lib/third_party/FiNeR/'
USE_OPENMP="false"
USE_TECIO="false"
NO_CONDA="false"
REMOTE="false"
BUILD_TYPE="RELEASE"

# Define allowed options for each command using regular arrays
CMD=("build")
CMD_OPTIONS_build=("--include-cea --include-orion --include-finer --compilers --use-openmp --use-tecio --no-conda")

# Parse global options
while getopts "v-:" opt; do
    case "$opt" in
        -)
            case "$OPTARG" in
                verbose) VERBOSE=true ;;
                *) error "Unknown global option '--$OPTARG'"; usage ;;
            esac
            ;;
        v) VERBOSE=true ;;
        ?) error "Unknown global option '-$OPTARG'"; usage ;;
    esac
done
shift $((OPTIND -1))

# Ensure a command was provided
if [[ $# -eq 0 ]]; then
  error "No command provided!"
  usage
fi

COMMAND="$1"
# Check if the command is valid
if [[ ! " ${CMD[@]} " =~ " ${COMMAND} " ]]; then
  error "Unknown command '$COMMAND'"
  usage
fi
shift

# Parse command-specific options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --include-cea=*)
          [[ "$COMMAND" == "build" ]] || { error " --include-cea is only valid for 'build' command"; exit 1; }
          CEA_PATH="${1#*=}"
          ;;
        --include-orion=*)
            [[ "$COMMAND" == "build" ]] || { error " --include-orion is only valid for 'build' command"; exit 1; }
            ORION_PATH="${1#*=}"
            ;;
        --include-finer=*)
            [[ "$COMMAND" == "build" ]] || { error " --include-finer is only valid for 'build' command"; exit 1; }
            FINER_PATH="${1#*=}"
            ;;
        --compilers=*)
            [[ "$COMMAND" == "build" ]] || { error " --compilers is only valid for 'build' command"; exit 1; }
            if [[ ! "$1" =~ ^--compilers=(intel|gnu)$ ]]; then
                error "Invalid value for --compilers. Valid values are 'intel' or 'gnu'."
                exit 1
            fi
            COMPILERS="${1#*=}"
            ;;       
        --use-openmp)
            [[ "$COMMAND" == "build" ]] || { error " --use-openmp is only valid for 'build' command"; exit 1; }
            USE_OPENMP="true"
            ;;
        --use-tecio)
            [[ "$COMMAND" == "build" ]] || { error " --use-tecio is only valid for 'build' command"; exit 1; }
            USE_TECIO="true"
            ;;
        --no-conda)
            [[ "$COMMAND" == "build" ]] || { error " --no-conda is only valid for 'build' command"; exit 1; }
            NO_CONDA="true"
            ;;
        *)
            eval "opts=(\"\${CMD_OPTIONS_${COMMAND}[@]}\")"
            error "Unknown option '$1' for command '$COMMAND'. Valid options: ${opts[@]}"
            exit 1
            ;;
    esac
    shift
done


# Execute the selected command
case "$COMMAND" in
    build)
        task "Building $project"
        
        task "Cloning submodules"
        [[ $CEA_PATH == $(pwd)'/lib/cea/' ]] && git submodule update --init lib/cea
        [[ $ORION_PATH == $(pwd)'/lib/ORION/' ]] && git submodule update --init lib/ORION
        [[ $FINER_PATH == $(pwd)'/lib/third_party/FiNeR/' ]] && git submodule update --init --recursive lib/third_party/FiNeR
        git submodule update --init lib/PiNeR

        task "Configuring and building $project"
        if [[ $COMPILERS == "intel" ]]; then 
          log "Using Intel compilers"
          export FC="ifx"
          export CXX="icpx"
        elif [[ $COMPILERS == "gnu" ]]; then 
          log "Using GNU compilers"
          export FC="gfortran"
          export CXX="g++"
        fi
        log "Build dir: $BUILD_DIR"
        log "Build type: $BUILD_TYPE"
        log "CEA path: $CEA_PATH"
        log "ORION path: $ORION_PATH"
        log "FINER path: $FINER_PATH"
        log "Use TecIO: $USE_TECIO"
        log "Use OpenMP: $USE_OPENMP"
        if [[ -z "${FC+x}" || -z "${CXX+x}" ]]; then
          log "Compilers not set. CMake will decide."
        else
          log "Compilers: FC=$FC, CXX=$CXX"
        fi
        rm -rf $BUILD_DIR
        CMAKE_ARGS=(-B "$BUILD_DIR" -DORION_PATH="$ORION_PATH" -DFINER_PATH="$FINER_PATH" -DUSE_TECIO="$USE_TECIO" -DUSE_OPENMP="$USE_OPENMP" -DCMAKE_BUILD_TYPE="$BUILD_TYPE")
        if [[ -n "$CEA_PATH" ]]; then
          CMAKE_ARGS+=( -DCEA_PATH="$CEA_PATH" )
        fi
        cmake "${CMAKE_ARGS[@]}" || exit 1
        cmake --build $BUILD_DIR || exit 1
        log "[OK] Compilation successful"

        task "Write CMakePresets.json"
        write_presets
        log "[OK] CMakePresets.json created"

        task "Defining environment variables"
        cd $DIR
        define_path
        log "[OK] ATLAS and CEA environment variables defined"

        if [[ "$NO_CONDA" == "false" ]]; then
          task "Create Conda environment"
          if ! command -v conda &> /dev/null; then
            error "Conda is not installed or not in your PATH. Please install Conda before proceeding."
            exit 1
          fi
          #conda env remove --name ct-env --yes
          conda env create -f ct-env.yaml
          log "[OK] Conda environment created"
        fi

        ;;
    *)
        error "Unknown command '$COMMAND'"
        usage
        ;;
esac
