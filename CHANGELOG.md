# Changelog

All notable changes to ATLAS are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and ATLAS numbers its releases by
[Semantic Versioning](docs/development/versioning.md). An entry that begins with **Breaking.** asks a user or a
project that uses ATLAS to change with it.

## [Unreleased]

### Added

- `database/chemistry/external/`: a folder whose content git ignores (its README is the only tracked file), for
  mechanisms that are not published. GPB, KAnT and the GUI search it, and its folders that hold YAML files, after
  `database/chemistry/`.

- External clones of ORION and FiNeR from a parent project such as hydra: `-DFETCHCONTENT_SOURCE_DIR_ORION=<path>`
  and `-DFETCHCONTENT_SOURCE_DIR_FINER=<path>` (`install.sh build --include-orion`, `--include-finer`). The
  configure stops when a clone does not satisfy ATLAS's requirement, unless `-DATLAS_PIN_CHECK=WARNING`.
- `ATLAS_FINER_DEPS`: FiNeR's dependencies at their default branches, as `fobis fetch` does (`FREE`, the
  default), or at known-good releases (`BACKUP`).
- The configure checks the release of CEA (`ATLAS_CEA_VERSION`) and of FiNeR (`ATLAS_FINER_TAG`), and names a
  submodule out of its pin by its tags.
- `install.sh build --update-deps`: the newest ORION 2.x again.
- `CHANGELOG.md`, and the release steps in the versioning guide.
- The ATLAS GUI covers the whole case. The Initial stage sets up ICB: a state for every block, zones with their
  coverage on the mesh, profiles (`<key>-file`), the nozzle law and the interpolation of a previous solution, and a
  3-D view of the state every cell takes. The Run stage runs GPB, BCB and ICB on the case, checks beforehand what
  would stop them, and logs their output. Every stage draws what its tool wrote (the property tables, the BC of
  every boundary cell, the initial field), and Review lists the errors and warnings of the last run on the sections
  they name. A case opens from its INI or from a folder of the tools' files, and Settings holds the themes, a theme
  editor and the text size.
- Tutorials: 26 pages, from one feature of one tool to a whole case cut for MPI, each on a case of the test suite.
  `ctest -L tutorial` runs every case they use; the INI files the pages write are in `test/tutorials/`.
- Tests: the cases of the tutorials, the GUI (`GUI-icmodel`, `GUI-icgeom`, `GUI-runner`, `GUI-icfield`,
  `GUI-outputs`, `GUI-layout`), and the new BCB refusals. Large tables and fields are compared on a sample
  (`test/sample_rows.awk`); `test/numdiff.awk -v rel=1` compares with a relative tolerance only.
- The documentation is built with Zensical (`requirements-docs.txt`), in strict mode in CI. It has a new home page,
  an INI Files page, and Testing lists every registered test. The home page's Hydra scheme
  (`docs/stylesheets/hydra.css`) is meant for the home pages of the other Hydra codes too.

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
- **Breaking.** BCB stops on a multipatch face whose ranges leave cells out, naming the face, the count and the
  first cell: those cells were written `0`, a face with no BC. It also stops on a face declared `chimera` with
  `BC-chimera = false`, whose cells that match no cell of another block were written `100`, which no solver reads.
  Make the ranges cover the face, or set `BC-chimera = true`.
- BCB, ICB and MDB read each `*phase.txt` of the case directory, else the one GPB wrote into
  `fromATLAStoSolver/`, so `ATLAS GPB BCB ICB` needs no copy of the phase files. `ATLAS.sh` warns when a copy in
  the case directory differs from GPB's file. The GUI no longer copies the phase tables before BCB and ICB.
  GPB never removes a file of `fromATLAStoSolver/`, so the phase of an earlier deck stays there: when the INI has
  `[GPB-Phase*]` sections, BCB and ICB read there only their phase files, and `ATLAS.sh` and the GUI name the
  others.
- **Breaking.** BCB: the `502` record of a solid-propellant grain is `a rhoGrain SF, n, pRef, Taf, mode` and the
  mass fractions, with the turbulence values of the section in mode 2 only. `grain-wall` sets the mode: `F`, the
  default, an inlet (mode 2); `T`, a wall that blows the products in (mode 1), as every grain was: a deck that
  keeps that wall gives `grain-wall = T`. BCB stops on a grain without `a` (the key or an `a-file`) and on an inlet
  grain with `a = 0`. `Taf-file` and `SFgeo-file` are no longer keys.
- **Breaking.** BCB: `krho` of a dispersed phase is the fraction of the flow of the mixture that it takes: the
  `401` record carries `krho/(1 - krho_tot)`, with `krho_tot` the sum of `krho` over the dispersed phases of the
  cell, and ends with `G`, the mass flux of the phases given by `gp` on the cell. BCB stops on a cell whose
  `krho_tot` is 1 or more, on a negative `krho` and on a negative `gp`. A grain applied as an inlet
  (`grain-wall = F`) is a `401` record with `krho` 0, in place of a `300`, for a phase it does not inject.

### Fixed

- BCB: overlapping multipatch ranges stopped BCB (a later patch built a cell again); a cell now takes the first
  patch whose range holds it, as the BC setup guide says.
- BCB: on a face with a theta direction and no `range`, the bounds that stand for no range (±`huge()`) were
  converted to radians too, which overflows: an infinity, still read as no bound, in a normal build, and a stop in
  a build that traps floating-point exceptions. Only the bounds given are converted now.
- BCB: the input reference (`docs/user-guide/bcb/input-reference.md`) gave the `p0-time-file` series of BC 402 in
  bar; it is in Pa, as in `bc-types.md` and in the text of the key. MOSE reads the series as written, so a series
  in bar gives it a `p0` 1e5 times too small.
- BCB, ICB and MDB guides: the units lines that the tools write into their input references name the values that
  are not SI (BCB: `ds` in cm, the angle `t` of `direction` in degrees; ICB: the angles `t` and `theta` in
  degrees). The guides describe as the code does a face left out of a block, the axis of a 2-D axisymmetric mesh
  in MOSE, the zones and the 1-D tables of ICB, the `T0` range of the stagnation states, the zone times of a
  line-file (also in a BCB warning), the BC file names that MOSE reads and the `rank` column of the MDB map.
- BCB, ICB and MDB guides: the inflow angles `alpha` and `beta` and how MOSE applies them, `rf`, an outlet without
  `p`, the names of the series files, a MOSE solution split by MDB, a block closed by type `200` that MDB cuts
  along k and the old solution that ICB reads are described as the code does them.
- KAnT: `KAnT-out.dat` separates the names of its `VARIABLES` line and quotes the zone titles, so that a
  Tecplot reader parses it.
- GPB: with `transport = CEA`, below the lowest bound of the NASA fits of a record (200 K for N2, O2 and Ar, up to
  1000 K for other species) the viscosity and the conductivity were held at their value at the bound. Below it the
  viscosity now follows its value and slope at the bound (or keeps its value, with an `[INFO]` line, where it does
  not increase with temperature), the conductivity keeps the Prandtl number of its lowest bound, and N2, O2, Ar,
  He, Ne and Kr have fits to reference data below 200 K. Rows at or above the bounds do not change. For the air of
  the GPB guide, at 100 K the viscosity goes from 87.5 % to 0.01 % above the dilute-gas air of Lemmon and Jacobsen
  (2004) and the conductivity from 96.9 % above to 1.85 % below; at 37 K the viscosity goes from 428 % above to
  0.31 % below. A record that cannot give a value stops GPB with a message that names it.

### Removed

- ORION's Python package from `ct-env`: nothing in ATLAS imports it. In an existing environment:
  `conda activate ct-env && pip uninstall ORION`.

## [0.1.0] - 2026-11-04

First release, a pre-release: `main` of 2 November 2026 (`e525d26`), the ATLAS hydra builds. GPB tabulates the
thermodynamic and transport properties of the phases; BCB, ICB, STB and MDB write the boundary conditions, initial
conditions, source terms and mesh decomposition the hydra solvers read; KAnT tests chemical mechanisms with
Cantera. Libraries as submodules: ORION at `a978930`, FiNeR v2.3.0 (`lib/third_party/FiNeR`), CEA from a fork of
v3.3.0, PiNeR v1.2.0.
