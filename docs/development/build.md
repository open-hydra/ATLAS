# Build Instructions

How to build ATLAS from source, and how to rebuild it while you work on it. The first build is described in
[Installation](../getting-started/installation.md).

## Prerequisites

**Required:**

- **Compilers**: GNU `gfortran` and `g++`, or Intel oneAPI `ifx` and `icpx` (CI builds with both)
- **CMake**: version 3.23 or later
- **Git**: for cloning ATLAS and its submodules (CEA, FiNeR, PiNeR); the first configure also checks out the
  release of ORION, so it needs the network
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

# external clones in place of the release of ORION and the submodules (checked against what ATLAS requires)
./install.sh build --include-cea=/path/to/cea \
                   --include-orion=/path/to/ORION \
                   --include-finer=/path/to/FiNeR

# select again the newest release of ORION that ATLAS accepts (deps.lock)
./install.sh build --update-deps

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
before rebuilding: git does not move the submodule checkouts (`lib/FiNeR`, `lib/cea`, `lib/PiNeR`), and CMake
stops with an error when one is not at the commit recorded by ATLAS (configure with `-DATLAS_PIN_CHECK=WARNING`
to build against another checkout on purpose). ORION is not a submodule: the configure checks out in
`lib/ORION` the release the branch requires (see
[Libraries: releases, pins and external clones](#libraries-releases-pins-and-external-clones)).

## Configuration Variables

To configure by hand, without the preset:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=DEBUG -DUSE_OPENMP=true
cmake --build build
```

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CMAKE_BUILD_TYPE` | String | `RELEASE` (install.sh) | `RELEASE` or `DEBUG` |
| `FETCHCONTENT_SOURCE_DIR_ORION` | Path | empty (the release) | an external ORION clone, built in place of the release |
| `FETCHCONTENT_SOURCE_DIR_FINER` | Path | empty (the submodule) | an external FiNeR clone, built in place of `lib/FiNeR` |
| `CEA_PATH` | Path | `lib/cea` | an external CEA clone, built in place of the submodule |
| `SEMVER_UPDATE` | String | `OFF` | `ALL` or `ORION`: select the newest release of ORION again at the next configure |
| `ATLAS_FINER_DEPS` | String | `FREE` | FiNeR's dependencies: `FREE` (as `fobis fetch`) or `BACKUP` (known-good releases) |
| `ATLAS_PIN_CHECK` | String | `FATAL_ERROR` | `WARNING`: build a library that differs from what ATLAS requires |
| `USE_OPENMP` | Bool | `false` | Enable OpenMP support |
| `USE_TECIO` | Bool | `false` | Enable TecIO support |
| `CMAKE_Fortran_COMPILER` | Path | auto-detected | Explicit Fortran compiler |
| `CMAKE_CXX_COMPILER` | Path | auto-detected | Explicit C++ compiler |

The executables are written into `bin/` (`BCB`, `ICB`, `MDB`, `STB`); there is no install step.

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

- **Wrong external clone** (`FETCHCONTENT_SOURCE_DIR_ORION`, `FETCHCONTENT_SOURCE_DIR_FINER`, or `CEA_PATH`)
- **Incomplete submodule checkout** (`lib/cea`, `lib/PiNeR`)
- **Compiler/toolchain mismatch between cached and current configuration**

```bash
# re-sync the submodules
git submodule update --init --recursive

# reconfigure from a clean build tree
rm -rf build
cmake -B build
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
