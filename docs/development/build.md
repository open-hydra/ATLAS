# Build Instructions

How to build ATLAS from source.

## Prerequisites

**Required:**
- **Fortran Compiler**: GFortran ≥ 9 or Intel `ifort` ≥ 2021
- **CMake**: Version 3.23 or later
- **Git**: For cloning ATLAS and its submodules (CEA, PiNeR); the first configure also clones the releases of
  ORION and FiNeR, so it needs the network
- **Make or Ninja**: For running the build (CMake generates build files for either)

**Optional:**
- **OpenMP**: For shared-memory parallelization (off by default; enable with `USE_OPENMP=ON`)
- **MPI**: Not currently wired up — the `USE_MPI` option is commented out in `CMakeLists.txt`
- **Doxygen**: For generating API documentation (if needed)

**Python (for GPB tool):**
- Python 3.9 or later
- Required packages: `cantera`, `coolprop`, `numpy<2`, `pyyaml`
- Optional conda environment: Use `ct-env.yaml`

## Quick Build

```bash
# Clone repository and initialize submodules
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
git submodule update --init --recursive

# Build with default preset
mkdir build
cd build
cmake --preset default
cmake --build .
```

After switching branches (`git checkout`, `git switch`), run `git submodule update --init --recursive`
before rebuilding: git does not move the submodule checkouts (`lib/FiNeR`, `lib/cea`, `lib/PiNeR`), and CMake
stops with an error when one is not at the commit recorded by ATLAS (configure with `-DATLAS_PIN_CHECK=WARNING`
to build against another checkout on purpose). ORION is not a submodule: the configure checks out in
`lib/ORION` the release the branch requires (see
[Libraries: releases, pins and external clones](#libraries-releases-pins-and-external-clones)).

## Build Options

ATLAS supports two common build paths:

- **Scripted build** using `install.sh` (recommended for first setup)
- **Direct CMake** configuration (recommended for iterative development)

```bash
# Debug build with symbols
cmake -DCMAKE_BUILD_TYPE=Debug ..

# Release build with optimizations
cmake -DCMAKE_BUILD_TYPE=Release ..

# Enable OpenMP
cmake -DUSE_OPENMP=ON ..

# Custom installation directory
cmake -DCMAKE_INSTALL_PREFIX=/custom/path ..
```

Scripted equivalents:

```bash
# Full default setup
./install.sh build

# Select compiler suite
./install.sh build --compilers=gnu
./install.sh build --compilers=intel

# Optional features
./install.sh build --use-openmp --use-tecio

# External clones in place of the bundled CEA and of the releases of ORION and FiNeR,
# checked against what ATLAS requires
./install.sh build --include-cea=/path/to/cea \
				   --include-orion=/path/to/ORION \
				   --include-finer=/path/to/FiNeR

# Select again the newest release of ORION that ATLAS accepts (deps.lock)
./install.sh build --update-deps

# Skip conda environment creation
./install.sh build --no-conda
```

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CMAKE_BUILD_TYPE` | String | `RELEASE` | Build mode (`Debug`/`Release`) |
| `FETCHCONTENT_SOURCE_DIR_ORION` | Path | empty (the release) | External ORION clone, built in place of the release |
| `FETCHCONTENT_SOURCE_DIR_FINER` | Path | empty (the release) | External FiNeR clone, built in place of the release |
| `SEMVER_UPDATE` | String | `OFF` | `ALL` or `ORION`: select the newest release again at the next configure |
| `ATLAS_FINER_DEPS` | String | `FREE` | FiNeR's dependencies: `FREE` (as `fobis fetch`) or `BACKUP` (known-good releases) |
| `ATLAS_PIN_CHECK` | String | `FATAL_ERROR` | `WARNING`: build a library that differs from what ATLAS requires |
| `CEA_PATH` | Path | `lib/cea/` (if available) | Path to CEA dependency |
| `USE_OPENMP` | Bool | `false` (script default) | Enable OpenMP support |
| `USE_TECIO` | Bool | `false` (script default) | Enable TecIO support |
| `CMAKE_Fortran_COMPILER` | Path | auto-detected | Explicit Fortran compiler |
| `CMAKE_CXX_COMPILER` | Path | auto-detected | Explicit C++ compiler |

### TecIO (`USE_TECIO=true`)

TecIO is vendored inside ORION (`lib/ORION/lib/TecIO/`). When ORION is configured with TecIO it looks for an
installed copy in `lib/TecIO/tecio-install-<suffix>` of the ORION folder (`lib/ORION`, or the external clone;
`teciompi-install-<suffix>` with MPI), where `<suffix>` names the compiler pair
(`lib/ORION/cmake/SetCompilerID.cmake`), e.g. `GNU` for gfortran + g++ and `IntelLLVM-IntelLLVM` for ifx + icpx.
If that directory does not exist, ORION configures, builds and installs TecIO there during the CMake configure
step (a few minutes, not parallel). From ORION 2.1.0, `-DORION_TECIO_DIR=<folder>` puts the TecIO builds in
another folder, which several builds can share. An existing install is reused as it is, also after a compiler
upgrade (remove the directory to rebuild it).

## Parallel Build

Every program (ICB, BCB, MDB, STB) compiles the common sources itself and writes its Fortran modules
to a directory of its own, `build/modules/<program>` (ORION's modules stay in `build/modules`), so all
the targets can be built at once with any number of jobs.

```bash
# Build using 4 cores
make -j 4

# Ninja with parallel build
cmake -G Ninja ..
ninja -j 4
```

## Installation

```bash
# Install to default location
make install

# Install to specific prefix
make install DESTDIR=/custom/prefix
```

## Verification

After compiling, verify both executable availability and regression tests.

```bash
# Confirm executables are present
ls -l ../bin/BCB ../bin/ICB ../bin/STB

# Run registered regression tests
ctest

# Run with verbose output
ctest --output-on-failure

# Run one focused regression case
ctest -R IG-nozzle3D --output-on-failure
```

## Build Troubleshooting

### Common Issues

#### CMake not found
```bash
# Install CMake
apt-get install cmake  # Debian/Ubuntu
brew install cmake     # macOS
```

#### Compiler not found

Use one of the following approaches:

```bash
# Option 1: use install.sh compiler selector
./install.sh build --compilers=gnu

# Option 2: export compilers before configure
export FC=gfortran
export CXX=g++
cmake -B build -DCMAKE_BUILD_TYPE=RELEASE
```

```bash
# Specify compiler explicitly
cmake -DCMAKE_Fortran_COMPILER=gfortran ..
```

#### Link errors

Common causes:

- **Wrong external clone** (`FETCHCONTENT_SOURCE_DIR_ORION`, `FETCHCONTENT_SOURCE_DIR_FINER`, or `CEA_PATH`)
- **Incomplete submodule checkout** (`lib/cea`, `lib/PiNeR`)
- **Compiler/toolchain mismatch between cached and current configuration**

```bash
# Re-sync submodules
git submodule update --init --recursive

# Reconfigure from clean build tree
rm -rf build
cmake -B build -DCEA_PATH=$PWD/lib/cea
cmake --build build
```

#### Out of memory during build
```bash
# Build with fewer parallel jobs
make -j 2
```

## Development Builds

For development, use Debug mode:

```bash
cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_TESTING=ON ..
make
ctest --output-on-failure
```

## Clean Build

```bash
# Remove all build artifacts
rm -rf build/
mkdir build
cd build
cmake ..
make
```

## Using Install Script

Alternatively, use the provided install script for automated configuration and build:

```bash
./install.sh
```

The script will:
1. Check prerequisites (compilers, CMake, Git)
2. Initialize the submodules (CEA, PiNeR); the configure checks out ORION and FiNeR
3. Create and configure the build directory
4. Run the build
5. Optionally install to a system location

**Note**: The script uses the `default` CMake preset. For custom configurations, use CMake directly.

## Continuous Integration

ATLAS uses GitHub Actions for automated testing:

- **Trigger**: Every push and pull request
- **Platforms**: Linux (GFortran), macOS (GFortran/Intel)
- **Status**: Visible in PR checks
- **Logs**: Available in GitHub Actions tab

### Local Pre-Commit Checks

Before pushing, verify the build locally:

```bash
cd build
cmake --build .
ctest --output-on-failure
```

This ensures your changes pass the same checks as CI.

See: [Testing](./testing.md), [Project Structure](./structure.md)

## Libraries: releases, pins and external clones

ATLAS requires its libraries in two ways, described in [Versioning](./versioning.md#how-atlas-requires-its-libraries):

- **ORION**, by a range of releases, with `semver_dependency` of `cmake/SemVerDeps.cmake` (the copy of FLINT's)
  in `CMakeLists.txt`: its major version (`VERSION 2`: the newest 2.x). The configure checks it out in
  `lib/ORION` (ignored by git, kept from a build to the next) and moves the checkout to another release when the
  requirement changes, if it has no changes of its own. The release selected is kept in `deps.lock` (not
  committed); `-DSEMVER_UPDATE=ORION` (or `./install.sh build --update-deps`) selects the newest one again.
- **FiNeR, CEA and PiNeR**, one release each, are git submodules (`lib/FiNeR`, `lib/cea`, `lib/PiNeR`). The
  configure compares each checkout with the commit this ATLAS commit records and **stops with an error** when
  they differ (`lib/cea is checked out at ..., but this ATLAS commit records ...`): run
  `git submodule update --init --recursive` and configure again. The release of FiNeR, in its `VERSION` file, is
  checked against `ATLAS_FINER_TAG`, and the one of CEA, which its `project()` declares, against
  `ATLAS_CEA_VERSION`, also for an external clone (`FETCHCONTENT_SOURCE_DIR_FINER`, `CEA_PATH`).

FiNeR's own dependencies (PENF, StringiFor, FACE, FLAP, BeFoR64) are fetched in its `src/third_party` as its
author does with `fobis fetch`: the default branch of each URL listed in FiNeR's `fobos`
(`ATLAS_FINER_DEPS=FREE`, the default). If an upstream change breaks ATLAS, `ATLAS_FINER_DEPS=BACKUP` checks out
instead the releases of `ATLAS_FINER_BACKUP_PINS` in `CMakeLists.txt`, with which ATLAS builds and passes its
tests.

### External clones

A parent project such as hydra gives ATLAS its own clones of ORION and FiNeR:

```bash
cmake -B build -DFETCHCONTENT_SOURCE_DIR_ORION=/path/to/ORION -DFETCHCONTENT_SOURCE_DIR_FINER=/path/to/FiNeR
# or: ./install.sh build --include-orion=/path/to/ORION --include-finer=/path/to/FiNeR
```

A clone is built as it is, uncommitted changes included, and nothing in it is moved or fetched. It must
satisfy ATLAS's requirement, or the configure **stops with an error**: ORION's version is the newest `vX.Y.Z`
tag in the history of its HEAD (an ORION 1.7.0 clone is refused), FiNeR's the content of its `VERSION` file.
FiNeR's dependencies must be in the clone's `src/third_party` (`fobis fetch --no-build`), and with
`ATLAS_FINER_DEPS=BACKUP` at their backup releases. To build a clone that does not satisfy the requirement on
purpose (an ORION branch under test), configure with `-DATLAS_PIN_CHECK=WARNING`; `-UFETCHCONTENT_SOURCE_DIR_ORION`
goes back to the release, `-UFETCHCONTENT_SOURCE_DIR_FINER` to the submodule.

ORION 2 reads PLOT3D meshes (`mesh.p3d`) with both compiler
suites and exports the variable names of `.szplt` files (adopted by name by ICB, see the ICB
strategies page). Binary Tecplot output (`IC-format = tec-binary`, STB `-o tec-binary`)
needs a build with `-DUSE_TECIO=true`; without it the request is refused at start. The float32 output
option of ORION is an ORION-side default: ATLAS reads both precisions with the ORION readers.
