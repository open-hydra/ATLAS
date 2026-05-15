#!/bin/bash

set -e  # Exit on any command failure
set -u  # Treat unset variables as an error

PROGRAM=$(basename "$0")
readonly DIR=$(pwd)
BUILD_DIR="$DIR/build"
VERBOSE=false
project=ATLAS

function usage() {
    cat <<EOF

Compile script for ATLAS

Usage:
  $PROGRAM [OPTIONS]

Options:
  -v       , --verbose      Enable verbose output

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


# Parse options
while getopts "v-:" opt; do
    case "$opt" in
        -)
            case "$OPTARG" in
                verbose) VERBOSE=true ;;
                *) error "Unknown global option '--$OPTARG'"; usage ;;
            esac
            ;;
        v) VERBOSE=true ;;
        ?) error "Unknown option '-$OPTARG'"; usage ;;
    esac
done
shift $((OPTIND -1))

if [[ $# -gt 0 ]]; then
  error "Unexpected arguments: $*"
  usage
fi

task "Compiling $project using CMakePresets"
cmake --preset default || exit 1
cmake --build "$BUILD_DIR" || exit 1
log "[OK] Compilation successful"
