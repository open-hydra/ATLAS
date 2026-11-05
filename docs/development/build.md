# Build Instructions

How to build ATLAS from source, and how to rebuild it while you work on it. The first build is described in
[Installation](../getting-started/installation.md).

## Prerequisites

**Required:**

- **Compilers**: GNU `gfortran` and `g++`, or Intel oneAPI `ifx` and `icpx` (CI builds with both)
- **CMake**: version 3.23 or later
- **Git**: for cloning and managing submodules
- **Make or Ninja**: for running the build (CMake generates build files for either)

**Optional:**

- **OpenMP**: shared-memory parallelization (off by default; `--use-openmp`, or `-DUSE_OPENMP=true`)
- **TecIO**: binary Tecplot files (off by default; `--use-tecio`, or `-DUSE_TECIO=true`)
- **MPI**: not wired up; the `USE_MPI` option is commented out in `CMakeLists.txt`

**Python (GPB, KAnT, GUI):**

- the conda environment of `ct-env.yaml`, created by `install.sh`;
- or any Python 3 with `cantera` (3.0 or later), `coolprop`, `numpy<2` and `pyyaml`, given to the launcher with
  `ATLAS_PYTHON` (PyQt and PyVista for the GUI)

## First Build

```bash
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
./install.sh build
```

`install.sh build` initializes the submodules, removes `build/`, configures and compiles, and writes
`CMakePresets.json` from the configuration it used (compilers, library paths, TecIO, OpenMP). The preset is
machine-local and git-ignored, so `cmake --preset default` only works after a first `./install.sh build`.

Options of the script:

```bash
# compiler suite
./install.sh build --compilers=gnu
./install.sh build --compilers=intel

# optional features
./install.sh build --use-openmp --use-tecio

# external dependency paths
./install.sh build --include-cea=/path/to/cea \
                   --include-orion=/path/to/ORION \
                   --include-finer=/path/to/FiNeR

# no conda environment
./install.sh build --no-conda
```

## Rebuild After Editing

Do not run `install.sh` again for an incremental build: it removes `build/`. From the source root:

```bash
cmake --preset default && cmake --build build
# or
scripts/compile.sh
```

After switching branches (`git checkout`, `git switch`), run `git submodule update --init --recursive`
before rebuilding: git does not move the submodule checkouts, and an existing build directory would
otherwise compile ATLAS against the ORION, cea or FiNeR commits of the previous branch. `./install.sh build`
does this for the bundled paths (and so resets any other commit checked out in them); CMake stops with
an error when a bundled submodule is not at the commit recorded by ATLAS (configure with
`-DATLAS_PIN_CHECK=WARNING` to build against another checkout on purpose).

## Configuration Variables

To configure by hand, without the preset:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=DEBUG -DUSE_OPENMP=true
cmake --build build
```

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CMAKE_BUILD_TYPE` | String | `RELEASE` (install.sh) | `RELEASE` or `DEBUG` |
| `ORION_PATH` | Path | `lib/ORION` | Path to ORION |
| `FINER_PATH` | Path | `lib/third_party/FiNeR` | Path to FiNeR |
| `CEA_PATH` | Path | `lib/cea` | Path to CEA |
| `USE_OPENMP` | Bool | `false` | Enable OpenMP support |
| `USE_TECIO` | Bool | `false` | Enable TecIO support |
| `ATLAS_PIN_CHECK` | String | `FATAL_ERROR` | `WARNING` builds against submodule checkouts that are not at the recorded commits |
| `CMAKE_Fortran_COMPILER` | Path | auto-detected | Explicit Fortran compiler |
| `CMAKE_CXX_COMPILER` | Path | auto-detected | Explicit C++ compiler |

The executables are written into `bin/` (`BCB`, `ICB`, `MDB`, `STB`); there is no install step.

### TecIO (`USE_TECIO=true`)

TecIO is vendored inside ORION (`lib/ORION/lib/TecIO/`). When ORION is configured with TecIO it looks for an
installed copy in `<ORION_PATH>/lib/TecIO/tecio-install-<suffix>` (`teciompi-install-<suffix>` with MPI), where
`<suffix>` names the compiler pair (`lib/ORION/cmake/SetCompilerID.cmake`), e.g. `GNU` for gfortran + g++ and
`IntelLLVM-IntelLLVM` for ifx + icpx. If that directory does not exist, ORION configures, builds and installs
TecIO there during the CMake configure step (a few minutes, not parallel). The location is set in
`lib/ORION/CMakeLists.txt` and has no `-D` override; an existing install is reused as it is, also after a
compiler upgrade (remove the directory to rebuild it).

## Parallel Build

Every program (ICB, BCB, MDB, STB) compiles the common sources itself and writes its Fortran modules
to a directory of its own, `build/modules/<program>` (ORION's modules stay in `build/modules`), so all
the targets can be built at once with any number of jobs.

```bash
cmake --build build -j 4

# or with Ninja
cmake -B build -G Ninja && cmake --build build -j 4
```

## Verification

```bash
# the executables
ls -l bin/BCB bin/ICB bin/MDB bin/STB

# the registered regression tests
ctest --test-dir build --output-on-failure

# one focused case
ctest --test-dir build -R IG-nozzle3D --output-on-failure
```

See [Testing](testing.md) for the labels and the test families.

## Build Troubleshooting

#### CMake not found

```bash
apt-get install cmake  # Debian/Ubuntu
brew install cmake     # macOS
```

#### Compiler not found

```bash
# Option 1: the install.sh compiler selector
./install.sh build --compilers=gnu

# Option 2: export the compilers before configuring
export FC=gfortran
export CXX=g++
cmake -B build -DCMAKE_BUILD_TYPE=RELEASE
```

#### Link errors

Common causes:

- **Missing dependency path** (`ORION_PATH`, `FINER_PATH`, or `CEA_PATH`)
- **Incomplete submodule checkout**
- **Compiler/toolchain mismatch between cached and current configuration**

```bash
# re-sync the submodules
git submodule update --init --recursive

# reconfigure from a clean build tree
rm -rf build
cmake -B build -DORION_PATH=$PWD/lib/ORION \
               -DFINER_PATH=$PWD/lib/third_party/FiNeR \
               -DCEA_PATH=$PWD/lib/cea
cmake --build build
```

#### Out of memory during build

```bash
cmake --build build -j 2
```

## Continuous Integration

GitHub Actions (`.github/workflows/`):

| Workflow | When | What |
|---|---|---|
| `ctest.yml` | every pull request to `main` | Ubuntu: the full build with `install.sh` and every test (gfortran, conda); TecIO builds with gfortran and with ifx/icpx; an OpenMP build under AddressSanitizer and UndefinedBehaviorSanitizer |
| `docs.yml` | pull requests that change the docs; pushes to `main` | the site built with Zensical in strict mode; published from `main` |
| `authors.yml` | pushes to `main` | regenerates `AUTHORS.md` |

### Local Checks Before Pushing

```bash
cmake --build build
ctest --test-dir build --output-on-failure
```

`git config core.hooksPath .githooks` enables the pre-push hook, which runs the full CTest suite before every push.

See: [Testing](testing.md), [Project Structure](structure.md)

## Submodule pins and external libraries

The configure step compares the checkout of every bundled submodule (`lib/ORION`, `lib/PiNeR`,
`lib/cea`, `lib/third_party/FiNeR`) with the commit this ATLAS commit records and **stops with an
error** when they differ (`lib/ORION is checked out at ..., but this ATLAS commit records ...`): run
`git submodule update --init --recursive` and configure again. To build on purpose against another
checkout of a submodule (an ORION pull request under test inside `lib/ORION`), configure with
`-DATLAS_PIN_CHECK=WARNING`. Tarballs, plain copies and libraries taken from outside the tree
(`-DORION_PATH=/path/to/ORION`, an external ORION route) are not checked: nothing in them is a
registered submodule.

The pinned ORION reads PLOT3D meshes (`mesh.p3d`) with both compiler
suites and exports the variable names of `.szplt` files (adopted by name by ICB, see the ICB
strategies page). Binary Tecplot output (`IC-format = tec-binary`, STB `-o tec-binary`)
needs a build with `-DUSE_TECIO=true`; without it the request is refused at start. The float32 output
option of ORION is an ORION-side default: ATLAS reads both precisions with the pinned readers.
