# Build Instructions

How to build ATLAS from source.

## Prerequisites

**Required:**
- **Fortran Compiler**: GFortran ≥ 9 or Intel `ifort` ≥ 2021
- **CMake**: Version 3.23 or later
- **Git**: For cloning and managing submodules
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
before rebuilding: git does not move the submodule checkouts, and an existing build directory would
otherwise compile ATLAS against the ORION, cea or FiNeR commits of the previous branch. `./install.sh build`
does this for the bundled paths (and so resets any other commit checked out in them); CMake stops with
an error when a bundled submodule is not at the commit recorded by ATLAS (configure with
`-DATLAS_PIN_CHECK=WARNING` to build against another checkout on purpose).

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

# External dependency paths
./install.sh build --include-cea=/path/to/cea \
				   --include-orion=/path/to/ORION \
				   --include-finer=/path/to/FiNeR

# Skip conda environment creation
./install.sh build --no-conda
```

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CMAKE_BUILD_TYPE` | String | `RELEASE` | Build mode (`Debug`/`Release`) |
| `ORION_PATH` | Path | `lib/ORION/` | Path to ORION dependency |
| `FINER_PATH` | Path | `lib/third_party/FiNeR/` | Path to FiNeR dependency |
| `CEA_PATH` | Path | `lib/cea/` (if available) | Path to CEA dependency |
| `USE_OPENMP` | Bool | `false` (script default) | Enable OpenMP support |
| `USE_TECIO` | Bool | `false` (script default) | Enable TecIO support |
| `CMAKE_Fortran_COMPILER` | Path | auto-detected | Explicit Fortran compiler |
| `CMAKE_CXX_COMPILER` | Path | auto-detected | Explicit C++ compiler |

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

- **Missing dependency path** (`ORION_PATH`, `FINER_PATH`, or `CEA_PATH`)
- **Incomplete submodule checkout**
- **Compiler/toolchain mismatch between cached and current configuration**

```bash
# Re-sync submodules
git submodule update --init --recursive

# Reconfigure from clean build tree
rm -rf build
cmake -B build -DORION_PATH=$PWD/lib/ORION \
			   -DFINER_PATH=$PWD/lib/third_party/FiNeR \
			   -DCEA_PATH=$PWD/lib/cea
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
2. Initialize submodules if needed
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
