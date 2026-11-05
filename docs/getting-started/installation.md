# Installation

This document describes how to configure and build ATLAS from source.

The instructions follow the current installer implementation in `install.sh` and the Conda environment definition in `ct-env.yaml`.

!!! note
    ATLAS is a pre-processing toolbox composed of Fortran executables and Python tools.
    A standard installation produces:  
    - Fortran binaries such as `bin/BCB`, `bin/ICB`, and `bin/STB`  
    - shell integration (`ATLASDIR` and `ATLAS` command/function via `.setvars.sh`)  
    - optional Conda environment `ct-env` for Python tooling (GPB/KAnT and dependencies)

## Prerequisites

Before building, verify the requirements. In short, you need:

- CMake 3.23 or newer
- Git
- Bash
- one supported compiler family:
  - GNU: `gfortran` and `g++`
  - Intel: `ifx` and `icpx`
- Conda (unless you build with `--no-conda`)

Quick check:

```bash
command -v bash git cmake
command -v gfortran g++ || true
command -v ifx icpx || true
command -v conda || true
cmake --version
```

## Libraries Used By ATLAS

The installer initializes the following submodules during build:

| Path | Purpose |
|------|---------|
| `lib/FiNeR` | INI-style parsing support |
| `lib/cea` | CEA-related thermochemical tooling |
| `lib/PiNeR` | Python package used in ATLAS workflows |

ORION (core I/O and supporting routines) is not a submodule: the configure checks out in `lib/ORION` the
release ATLAS requires.

## Build Methods

Clone the repository first:

```bash
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
```

### Build With install.sh (Recommended)

General form:

```bash
./install.sh [GLOBAL_OPTIONS] COMMAND [COMMAND_OPTIONS]
```

Global options:

- `-v`, `--verbose`: verbose logs

The installer command is `build`.

Performs a clean configure and build cycle, writes `CMakePresets.json`, sets shell variables, and optionally creates Conda env `ct-env`.

```bash
# default build (includes conda env creation)
./install.sh build

# explicit compiler family
./install.sh build --compilers=gnu
./install.sh build --compilers=intel

# optional build features
./install.sh build --use-openmp --use-tecio

# skip conda env creation
./install.sh build --no-conda

# external clones in place of the release of ORION and the submodule FiNeR (checked against what ATLAS requires)
./install.sh build \
  --include-orion=/path/to/ORION \
  --include-finer=/path/to/FiNeR

# select again the newest release of ORION that ATLAS accepts (deps.lock)
./install.sh build --update-deps
```

Options supported by `build`:

- `--compilers=<gnu|intel>`
- `--include-cea=<path>`
- `--include-orion=<path>`
- `--include-finer=<path>`
- `--update-deps`
- `--use-openmp`
- `--use-tecio`
- `--no-conda`

### Build With CMake (Manual)

If you prefer manual control, run the equivalent CMake commands directly.

```bash
cmake -B build \
  -DUSE_TECIO=false \
  -DUSE_OPENMP=false \
  -DCMAKE_BUILD_TYPE=RELEASE

cmake --build build
```

The first configure clones the release of ORION into `lib/ORION` (it needs the network) and initializes the
submodules if `git clone --recursive` did not. External clones replace ORION and FiNeR with `-DFETCHCONTENT_SOURCE_DIR_ORION=<path>` and `-DFETCHCONTENT_SOURCE_DIR_FINER=<path>`; see
[Libraries: releases, pins and external clones](../development/build.md#libraries-releases-pins-and-external-clones).

## Conda Environment Created By Installer

Unless `--no-conda` is used, `install.sh build` executes:

```bash
conda env create -f ct-env.yaml
```

The created environment name is `ct-env`. It includes:

- Python + Cantera + CoolProp
- Ninja
- editable installs of:
  - `lib/PiNeR`
  - `lib/cea`

## Verification

After installation, verify core artifacts:

```bash
ls -l bin/BCB bin/ICB bin/STB
test -f CMakePresets.json && echo "CMakePresets.json present"
test -f scripts/setvars.sh && echo "setvars.sh present"
conda env list | grep ct-env || true
```

You can also confirm shell integration:

```bash
source scripts/setvars.sh
ATLAS --help
```

## Troubleshooting

- `conda: command not found` during build:
  - install Conda, add it to PATH, or run `./install.sh build --no-conda`

- wrong compiler or compiler not found:
  - pass `--compilers=gnu` or `--compilers=intel`
  - verify toolchain binaries are in PATH

- dependency path errors for ORION or FiNeR:
  - run `git submodule update --init --recursive` to initialize the submodules (FiNeR among them)
  - or provide external clones with `--include-orion` and `--include-finer`

- `ATLAS` command not available in current shell:
  - run `source scripts/setvars.sh`
  - open a new terminal if your shell startup file was modified by `setvars`

- `ct-env` already exists and env creation fails:

```bash
conda env remove -n ct-env
./install.sh build
```

---

Next: [Quick Start Guide](./quick-start.md)
