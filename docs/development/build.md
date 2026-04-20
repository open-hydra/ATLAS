# Build Instructions

How to build ATLAS from source.

## Prerequisites

TODO: Document build prerequisites

- Fortran compiler (GFortran, Intel, etc.)
- CMake 3.15+
- Make or Ninja
- Optional: MPI library for parallel builds
- Optional: OpenMP support

## Quick Build

```bash
# Clone and build
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
mkdir build
cd build
cmake ..
make
```

## Build Options

TODO: Document CMake configuration options

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

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CMAKE_BUILD_TYPE` | String | Release | Build type (Debug/Release) |
| `ENABLE_MPI` | BOOL | OFF | Enable MPI support |
| `ENABLE_OPENMP` | BOOL | ON | Enable OpenMP support |
| TODO | TODO | TODO | TODO |

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

TODO: Document how to verify build

```bash
# Run basic tests
ctest

# Run with verbose output
ctest --output-on-failure
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
TODO: Document compiler setup

```bash
# Specify compiler explicitly
cmake -DCMAKE_Fortran_COMPILER=gfortran ..
```

#### Link errors
TODO: Add link error solutions

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

Alternative build using provided script:

```bash
./install.sh
```

TODO: Document install script options and behavior

## Continuous Integration

TODO: Document CI/CD setup and builds

---

See: [Testing](./testing), [Project Structure](./structure)
