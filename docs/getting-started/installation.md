# Installation

This page describes how to build ATLAS from source, with `install.sh` and the conda environment of `ct-env.yaml`.

A standard installation gives:

- the Fortran executables `bin/BCB`, `bin/ICB`, `bin/MDB` and `bin/STB`;
- the `ATLAS` command and the `ATLASDIR` variable, defined in `scripts/setvars.sh`, which your shell start-up
  file sources;
- the conda environment `ct-env`, with the Python dependencies of GPB, KAnT and the GUI.

## Prerequisites

- CMake 3.23 or newer
- Git
- Bash
- one compiler family:
    - GNU: `gfortran` and `g++`
    - Intel oneAPI: `ifx` and `icpx`
- Conda, unless you build with `--no-conda`

Quick check:

```bash
command -v bash git cmake
command -v gfortran g++ || true
command -v ifx icpx || true
command -v conda || true
cmake --version
```

## Dependencies

The Fortran tools are built against libraries bundled as git submodules; the Python tools run in the conda
environment `ct-env`.

| Library | Role | Used by | Source |
|---------|------|---------|--------|
| [CEA](https://github.com/nasa/cea) | NASA chemical equilibrium (Chemical Equilibrium with Applications) | GPB, BCB, ICB, MDB, STB | submodule `lib/cea` |
| [ORION](https://github.com/MarcoGrossi92/ORION) | multi-block I/O: Tecplot, VTK, PLOT3D | BCB, ICB, MDB, STB | submodule `lib/ORION` |
| [FiNeR](https://github.com/szaghi/FiNeR) | Fortran INI parser | BCB, ICB, MDB, STB | submodule `lib/third_party/FiNeR` |
| [PiNeR](https://github.com/MarcoGrossi92/PiNeR) | Python INI parser | GPB, KAnT | submodule `lib/PiNeR`, installed in `ct-env` |
| [Cantera](https://cantera.org) 3.0 or later | thermodynamics, transport and kinetics | GPB, KAnT | `ct-env` (tested with 3.0.1) |
| [CoolProp](http://www.coolprop.org) | real-fluid equations of state | GPB | `ct-env` |
| PyQt, PyVista | windows and 3-D views | GUI | `ct-env` |

Optional: **OpenMP** (shared-memory threads in the Fortran tools) and **TecIO** (binary Tecplot files, `.szplt`),
which ORION builds during the configure step.

## Build With install.sh (Recommended)

Clone the repository first:

```bash
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
```

General form:

```bash
./install.sh [-v|--verbose] build [OPTIONS]
```

`build` is the only command. It initializes the submodules, **removes `build/`**, configures and compiles, writes
`CMakePresets.json`, defines the shell integration and, unless `--no-conda`, creates the conda environment
`ct-env`.

```bash
# default build: CMake picks the compilers, no OpenMP, no TecIO, conda environment created
./install.sh build

# explicit compiler family
./install.sh build --compilers=gnu
./install.sh build --compilers=intel

# optional features
./install.sh build --use-openmp --use-tecio

# no conda environment
./install.sh build --no-conda

# external dependency paths instead of the bundled submodules
./install.sh build \
  --include-cea=/path/to/cea \
  --include-orion=/path/to/ORION \
  --include-finer=/path/to/FiNeR
```

Options of `build`:

| Option | Effect |
|---|---|
| `--compilers=<gnu\|intel>` | `gfortran`/`g++` or `ifx`/`icpx`; without it CMake chooses |
| `--include-cea=<path>`, `--include-orion=<path>`, `--include-finer=<path>` | build against that checkout instead of the submodule |
| `--use-openmp` | OpenMP in the Fortran tools |
| `--use-tecio` | binary Tecplot input and output (TecIO is built on the first configure, a few minutes) |
| `--no-conda` | do not create `ct-env` |

!!! warning "install.sh rewrites your shell start-up file"
    The build writes `scripts/setvars.sh` and appends `source <ATLAS>/scripts/setvars.sh` to `~/.zshrc` or
    `~/.bashrc` (after your login shell). Before that it **removes from that file every line that contains the
    word `ATLAS`**, so that the line is never written twice: keep any other line of yours that contains it in
    another file.

For an incremental rebuild after editing the sources, do not run `install.sh` again (it removes `build/`):

```bash
cmake --preset default && cmake --build build
```

### Build With CMake (Manual)

The equivalent CMake commands, without the presets, the shell integration and the conda environment:

```bash
cmake -B build \
  -DORION_PATH=$(pwd)/lib/ORION/ \
  -DFINER_PATH=$(pwd)/lib/third_party/FiNeR/ \
  -DCEA_PATH=$(pwd)/lib/cea/ \
  -DUSE_TECIO=false \
  -DUSE_OPENMP=false \
  -DCMAKE_BUILD_TYPE=RELEASE

cmake --build build
```

## Conda Environment

Unless `--no-conda` is given, `install.sh build` runs:

```bash
conda env create -f ct-env.yaml
```

The environment `ct-env` holds Python with NumPy, Cantera and CoolProp, PyQt, PyVista and pyvistaqt (the GUI),
Matplotlib (KAnT plots), Ninja, and the editable installs of `lib/PiNeR`, `lib/cea` and `lib/ORION`.

`ATLAS GPB`, `ATLAS KAnT` and `ATLAS GUI` activate it for the run. Two variables change that:

| Variable | Effect |
|---|---|
| `ATLAS_CONDA_ENV` | the conda environment to activate (default `ct-env`) |
| `ATLAS_PYTHON` | a Python interpreter to use instead of conda, for example after `--no-conda`; it needs `cantera`, `coolprop`, `numpy<2` and `pyyaml` |

## Verification

After the installation:

```bash
ls -l bin/BCB bin/ICB bin/MDB bin/STB
test -f CMakePresets.json && echo "CMakePresets.json present"
test -f scripts/setvars.sh && echo "setvars.sh present"
conda env list | grep ct-env || true
```

and, in a new terminal:

```bash
ATLAS --help
```

The test suite runs with CTest; see [Testing](../development/testing.md):

```bash
ctest --test-dir build --output-on-failure
```

## Troubleshooting

- `conda: command not found` during the build:
    - install conda and put it on `PATH`, or run `./install.sh build --no-conda` and set `ATLAS_PYTHON`
- wrong compiler, or compiler not found:
    - pass `--compilers=gnu` or `--compilers=intel`
    - check that the compilers are on `PATH` (`source /opt/intel/oneapi/setvars.sh` for oneAPI)
- dependency path errors for ORION, FiNeR or CEA:
    - run `git submodule update --init --recursive` to check out the bundled submodules at the commits ATLAS
      records
    - or give explicit paths with `--include-orion`, `--include-finer`, `--include-cea`
- `ATLAS` command not found:
    - open a new terminal, or run `source scripts/setvars.sh` from the ATLAS directory
- `ct-env` already exists and the creation fails:

```bash
conda env remove -n ct-env
./install.sh build
```

---

Next: [Quick Start](quick-start.md)
