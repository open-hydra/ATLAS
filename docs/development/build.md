# Build Instructions

How to build ATLAS from source.

## Prerequisites

**Required:**
- **Fortran Compiler**: GFortran ≥ 9 or Intel `ifort` ≥ 2021
- **CMake**: Version 3.23 or later
- **Git**: For cloning and managing submodules
- **Make or Ninja**: For running the build (CMake generates build files for either)

**Optional:**
- **OpenMP**: For shared-memory parallelization (enabled by default on most systems)
- **MPI**: For distributed-memory parallelization (currently not used by default)
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

## Build Options

ATLAS supports two common build paths:

- **Scripted build** using `install.sh` (recommended for first setup)
- **Direct CMake** configuration (recommended for iterative development)

```bash
# Debug build with symbols
cmake -DCMAKE_BUILD_TYPE=Debug ..

# Release build with optimizations
cmake -DCMAKE_BUILD_TYPE=Release ..

# Enable parallel support
cmake -DENABLE_MPI=ON -DENABLE_OPENMP=ON ..

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

## Parallel Build

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

See: [Testing](./testing), [Project Structure](./structure)
