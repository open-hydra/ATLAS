# Changelog

All notable changes to ATLAS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and ATLAS numbers its releases by
[Semantic Versioning](docs/development/versioning.md). An entry that begins with **Breaking.** asks a user or a
project that uses ATLAS to change with it.

## [Unreleased]

### Added

- `cmake/SemVerDeps.cmake`, FLINT's, unmodified: ORION is required by release in `CMakeLists.txt` and checked
  out by the configure in `lib/ORION`. The release selected is kept in `deps.lock` (not committed);
  `-DSEMVER_UPDATE=ORION`, or `./install.sh build --update-deps`, selects the newest one again.
- External clones of ORION and FiNeR, given by a parent project such as hydra:
  `-DFETCHCONTENT_SOURCE_DIR_ORION=<path>` and `-DFETCHCONTENT_SOURCE_DIR_FINER=<path>`
  (`./install.sh build --include-orion=<path> --include-finer=<path>`). A clone is built as it is; the configure
  stops when it does not satisfy ATLAS's requirement (ORION 2, FiNeR v2.3.0, FiNeR's dependencies present),
  unless `-DATLAS_PIN_CHECK=WARNING`.
- `ATLAS_FINER_DEPS`: FiNeR's dependencies are fetched as its author does (`fobis fetch`: the default branch of
  each, `FREE`, the default), or at known-good releases (`BACKUP`: PENF v2.0.1, StringiFor v1.8.0, FACE v1.1.17,
  FLAP v2.5.3, BeFoR64 v1.2.4), without FoBiS.
- The configure checks the release of CEA against `ATLAS_CEA_VERSION` (3.3.4), also for `CEA_PATH`, and the one
  of FiNeR against `ATLAS_FINER_TAG` (v2.3.0), and names the commits of a submodule out of its pin by their tags.
- `CHANGELOG.md`, and the requirements and the release steps in the versioning guide.

### Changed

- **Breaking.** ORION 2 is required (any 2.x from 2.0.0; tested with 2.0.0 and 2.1.0), in place of the ORION
  commit `a978930` of the submodule `lib/ORION`. ATLAS reads `thermo.dat` and `properties.dat` with
  `tec_read_structured_multiblock`, since ORION 2.0.0 removed `tec_read_points_multivars`. Results are unchanged.
- **Breaking.** `lib/ORION` is no longer a git submodule, and the CMake variables `ORION_PATH` and `FINER_PATH`
  are removed: an external clone is given with `FETCHCONTENT_SOURCE_DIR_ORION` and
  `FETCHCONTENT_SOURCE_DIR_FINER` (the `install.sh` options keep their names).
- The submodule FiNeR (v2.3.0) moves from `lib/third_party/FiNeR` to `lib/FiNeR`: `git submodule update --init`
  checks it out there, and an old `lib/third_party` can be deleted.
- FiNeR's dependencies follow by default the default branch of each, as FiNeR's author fetches them; they were
  pinned at the commits of the releases that `ATLAS_FINER_DEPS=BACKUP` now checks out.
- CEA: the submodule `lib/cea` follows NASA's repository (`nasa/cea`, v3.3.4) in place of a fork (v3.3.0); the
  fork's parser change is part of NASA's release. A clone made before this change needs
  `git submodule sync && git submodule update --init lib/cea`.
- The CMake helpers are in `cmake/`: `AddLibraries.cmake`, `SubmodulePins.cmake`, `FiNeRDependencies.cmake`.

### Removed

- ORION's Python package from the `ct-env` conda environment (`ct-env.yaml`): nothing in ATLAS imports it, and
  `lib/ORION` may be absent when an external ORION is given. In an existing environment:
  `conda activate ct-env && pip uninstall ORION`.
