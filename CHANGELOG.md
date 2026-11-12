# Changelog

All notable changes to ATLAS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and ATLAS numbers its releases by [Semantic Versioning](docs/development/versioning.md). An entry that begins with **Breaking.** asks a user or a project that uses ATLAS to change with it.

## [Unreleased]

### Added

- `thermo = custom`: gas species, solids and liquids, and real fluids can be coded in Python, in `custom.py` of the
  case directory or of `database/thermo/`. See [Custom Substances](docs/databases/thermodynamics/custom.md).
- GRI-Mech 3.0 (`reactions = gri30`) is listed in the mechanism catalog. Cantera ships it; it is not a file of
  `database/chemistry/`.
- The figure of the mechanism catalog is drawn by `database/chemistry/resume.py`; the test `database-figure-current`
  fails when it is out of date.
- Git-ignored `external/` folders for data that ATLAS does not distribute: `database/thermo/external/`
  (`burcat.yaml`) and `database/chemistry/external/` (mechanisms). GPB, KAnT and the GUI search them.
- External ORION and FiNeR clones: `-DFETCHCONTENT_SOURCE_DIR_ORION=<path>`, `-DFETCHCONTENT_SOURCE_DIR_FINER=<path>`
  (the configure stops if a clone does not fit; `-DATLAS_PIN_CHECK=WARNING` relaxes it). `ATLAS_FINER_DEPS` picks
  FiNeR's dependency versions, and `install.sh build --update-deps` the newest ORION 2.x (2.1.0 or later).
- `thermo = constant` for a real fluid: `cp`, `rho`, `mu`, `k` (and `a`) given in the section, the same at every
  pressure and enthalpy. See [Constant Properties](docs/user-guide/gpb/real-fluid.md#constant-properties).
- `mil-law = sutherland` for the fixed species of an ideal gas: a Sutherland viscosity, the conductivity from `Pr` or
  `kl`. See [Viscosity law](docs/user-guide/gpb/ideal-gas.md#viscosity-law-of-the-fixed-species).
- `CHANGELOG.md`, and the release steps in the versioning guide.
- The GUI covers the whole case: the Initial stage (ICB), the Run stage, a drawing of what every tool wrote,
  Review, and Settings.
- 26 tutorial pages, each on a case of the test suite (`ctest -L tutorial`), and tests for them, the GUI and the
  BCB refusals.
- The documentation is built with Zensical (strict in CI), with a new home page and an INI Files page.
- GPB, `[GPB-Pyrolysis<n>]`: the pyrolysis-gas tables of a charring ablator, `<phase>-pyrolysis.dat`, by
  `treatment = gas-only` (the default) or `strip`. See [Pyrolysis-Gas Tables](docs/user-guide/gpb/pyrolysis.md).

### Changed

- **Breaking.** `burcat.yaml` is no longer distributed: its licence does not allow it in GPL software. Put it in
  `database/thermo/external/` (see the README there); `thermo = Burcat` stops without it.
- **Breaking.** `sp_custom.py` is replaced by the substances of `custom.py`, with the same seven materials and
  values. `thermo = SP-database` is read as `thermo = custom`, with a warning.
- The real-fluid `model` key is now `thermo`, as in the other phase types. `model` still works, with a warning.
- **Breaking.** ORION 2.1 or a later 2.x is required, in place of the submodule `lib/ORION`. The configure checks it out in
  `lib/ORION`. Results are unchanged.
- **Breaking.** `ORION_PATH` and `FINER_PATH` are removed: use `FETCHCONTENT_SOURCE_DIR_ORION` and
  `FETCHCONTENT_SOURCE_DIR_FINER`.
- FiNeR (v2.3.0) moves to `lib/FiNeR`; delete an old `lib/third_party`. Its dependencies follow their default
  branches (`ATLAS_FINER_DEPS=BACKUP` for the old pins).
- CEA follows `nasa/cea` v3.3.4. An existing clone needs `git submodule sync && git submodule update --init lib/cea`.
- **Breaking.** BCB stops on a multipatch face whose ranges leave cells out, and on a `chimera` face with
  `BC-chimera = false` whose cells match no other block. Make the ranges cover the face, or set `BC-chimera = true`.
- BCB, ICB and MDB read `*phase.txt` from the case directory, else from `fromATLAStoSolver/`: no copy is needed.
  `ATLAS.sh` warns when a copy differs from GPB's file.
- **Breaking.** BCB, grain (`502`): the record is now `a rhoGrain SF, n, pRef, Taf, mode`. `grain-wall` sets the
  mode: `F` (default) an inlet, `T` a wall, as every grain was: add `grain-wall = T` to keep it. `a` is required;
  `Taf-file` and `SFgeo-file` are gone.
- **Breaking.** BCB, `krho` of a dispersed phase is its share of the flow of the mixture; the `401` record carries
  `krho/(1 - krho_tot)` and ends with `G`. BCB stops on `krho_tot` of 1 or more, a negative `krho` or a negative `gp`.
- **Breaking.** BCB, `506` is the pyrolysing ablator: `surface-reactions`, `pyrolysis-gas`, `phi`, `hv0` and `qrad`
  give the record `pyro_id, surf, phi, hv0, qrad, eps`. `pyrolysis-model` with `surface-reactions` (the former
  `506`, which no solver applied) stops BCB: keep one of the two.
- The chemistry pages mention FLINT once, and the upkeep of its contract test is in Testing.

### Fixed

- GPB, a fixed gas given `mil` without `kl` or `Pr` stops with a message (it stopped with a Python error).
- `JLR-nasuti-ct.yaml`, `JLR-frassoldati-ct.yaml` (the forms KAnT runs): the backward H2 step never acted. It is
  refitted, so burnt gas reaches the equilibrium temperature (it was up to 220 K too hot). Their phases are named
  `JLR-Nasuti-ct` and `JLR-Frassoldati-ct`.
- KAnT: an ignition-delay run no longer aborts when the integrator stops after the ignition; `JLR-…-ct` is no longer
  read as `JLR-…-ct-ct`; `KAnT-out.dat` parses in Tecplot readers.
- BCB: overlapping multipatch ranges stopped BCB (the first patch now wins); a face with a theta direction and no
  `range` overflowed; the input reference gave the `p0-time-file` of BC 402 in bar, it is Pa (MOSE read it as Pa).
- BCB, ICB and MDB guides: units, inflow angles, zones, tables and file names now match the code.
- GPB, `transport = CEA` below the lowest bound of a record (200–1000 K): viscosity and conductivity were held at
  the bound, and now follow the record's slope there. Rows at or above the bounds are unchanged.

### Removed

- `sp_custom.py` and `burcat.yaml` (see above), and a duplicated list in the GPB input registry.
- **Breaking.** `ATLAS BCB-GUI`, `GUI/BCB_GUI.py` and the GUI's `--stage` option: the GUI is one program.
- ORION's Python package from `ct-env`: run `conda activate ct-env && pip uninstall ORION`.

## [0.1.0] - 2026-11-04

First release, a pre-release: `main` of 2 November 2026 (`e525d26`), the ATLAS hydra builds. GPB tabulates the
thermodynamic and transport properties of the phases; BCB, ICB, STB and MDB write the boundary conditions, initial
conditions, source terms and mesh decomposition the hydra solvers read; KAnT tests chemical mechanisms with
Cantera. Libraries as submodules: ORION at `a978930`, FiNeR v2.3.0 (`lib/third_party/FiNeR`), CEA from a fork of
v3.3.0, PiNeR v1.2.0.
