# Changelog

All notable changes to ATLAS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and ATLAS numbers its releases by
[Semantic Versioning](docs/development/versioning.md). An entry that begins with **Breaking.** asks a user or a
project that uses ATLAS to change with it.

## [Unreleased]

### Added

- External clones of ORION and FiNeR from a parent project such as hydra: `-DFETCHCONTENT_SOURCE_DIR_ORION=<path>`
  and `-DFETCHCONTENT_SOURCE_DIR_FINER=<path>` (`install.sh build --include-orion`, `--include-finer`). The
  configure stops when a clone does not satisfy ATLAS's requirement, unless `-DATLAS_PIN_CHECK=WARNING`.
- `ATLAS_FINER_DEPS`: FiNeR's dependencies at their default branches, as `fobis fetch` does (`FREE`, the
  default), or at known-good releases (`BACKUP`).
- The configure checks the release of CEA (`ATLAS_CEA_VERSION`) and of FiNeR (`ATLAS_FINER_TAG`), and names a
  submodule out of its pin by its tags.
- `install.sh build --update-deps`: the newest ORION 2.x again.
- `CHANGELOG.md`, and the release steps in the versioning guide.

### Changed

- **Breaking.** ORION 2 is required (2.0.0 or a later 2.x), in place of the submodule `lib/ORION` at `a978930`.
  The configure checks out the newest 2.x in `lib/ORION` with FLINT's `cmake/SemVerDeps.cmake`, and keeps it in
  `deps.lock` (not committed). Results are unchanged.
- **Breaking.** `ORION_PATH` and `FINER_PATH` are removed: use `FETCHCONTENT_SOURCE_DIR_ORION` and
  `FETCHCONTENT_SOURCE_DIR_FINER`.
- The submodule FiNeR (v2.3.0) moves from `lib/third_party/FiNeR` to `lib/FiNeR`; an old `lib/third_party` can
  be deleted.
- FiNeR's dependencies follow their default branches; `ATLAS_FINER_DEPS=BACKUP` checks out the releases they
  were pinned at.
- CEA: the submodule `lib/cea` follows `nasa/cea` v3.3.4 in place of a fork of v3.3.0. An existing clone needs
  `git submodule sync && git submodule update --init lib/cea`.

### Removed

- ORION's Python package from `ct-env`: nothing in ATLAS imports it. In an existing environment:
  `conda activate ct-env && pip uninstall ORION`.

## [0.1.0] - 2026-11-04

First release, a pre-release: `main` of 2 November 2026 (`e525d26`), the ATLAS hydra builds. GPB tabulates the
thermodynamic and transport properties of the phases; BCB, ICB, STB and MDB write the boundary conditions, initial
conditions, source terms and mesh decomposition the hydra solvers read; KAnT tests chemical mechanisms with
Cantera. Libraries as submodules: ORION at `a978930`, FiNeR v2.3.0 (`lib/third_party/FiNeR`), CEA from a fork of
v3.3.0, PiNeR v1.2.0.
