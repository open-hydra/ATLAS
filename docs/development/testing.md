# Testing

This page describes ATLAS tests in plain terms: what each test is trying to prove.

## What A Test Checks

Most regression tests run one tool (`GPB`, `BCB`, `ICB`, `MDB`, or `STB`) from a case folder and then compare produced files with reference files.

If outputs match, the test objective is considered met.

## Active CTest Regression Cases

These are the cases currently registered in `test/CMakeLists.txt`.

| Test name | Tool | Case folder | Main goal |
|---|---|---|---|
| `ceafile-reactive-OG` | GPB | `GPB/IG-ceafile-reactive-OG` | Reactive gas setup from CEA data produces the expected composition/chemistry output. |
| `SP-basic` | ICB | `ICB/SP-basic` | Basic solid initial-condition field generation. |
| `IG-nozzle3D` | ICB | `ICB/IG-nozzle3D` | 3D nozzle initial-condition generation and VTK export path. |
| `IG-interp-mindist` | ICB | `ICB/IG-interp-mindist` | Minimum-distance interpolation onto a grid carrying solver-style extra variables. |
| `IG-inflow-nozzle` | BCB | `BCB/IG-inflow-nozzle` | Nozzle inflow boundary-condition construction. |
| `IG-inflow-ceafile-inertmix` | BCB | `BCB/IG-inflow-ceafile-inertmix` | Inflow BC creation using CEA-based inert-mixture inputs. |
| `IG-multipatch-file` | BCB | `BCB/IG-multipatch-file` | Multipatch BC assignment when patches are provided by file. |
| `IG-multipatch-1D` | BCB | `BCB/IG-multipatch-1D` | 1D multipatch face mapping and resulting BC output. |
| `IG-chimera` | BCB | `BCB/IG-chimera` | Chimera/overset boundary metadata generation. |
| `IG-chimera+connection` | BCB | `BCB/IG-chimera+connection` | Chimera and standard connection coexisting on one layout. |
| `IG-force-chimera` | BCB | `BCB/IG-force-chimera` | `BC-force-chimera` on a partial interface. |
| `mesh-p3d-3D` | BCB | `BCB/mesh-p3d-3D` | A PLOT3D mesh alone, with three coordinates and several node planes, is read as 3D: `bc.txt` equals the one of the same grid in Tecplot. |
| `DP-basic` | BCB | `BCB/DP-basic` | Dispersed-phase BC assignment and export. |
| `IG+CD` | BCB | `BCB/IG+CD` | A gas phase and a dispersed phase on one inlet: `gas-bc.txt` and `particles-bc.txt` are written together. |
| `IG-plate-keys` | BCB | `BCB/IG-plate-keys` | The plate keys `full-plate` and `z-hydra` pass the key check and give the product of `IG-multipatch-file`. |
| `IG-renamed-keys-lenient` | BCB | `BCB/IG-renamed-keys-lenient` | `rt` and `force-connect` are unknown keys: with `strict-keys = false` a WARNING naming the current key. |
| `IG-value-not-a-number` | BCB | `BCB/IG-value-not-a-number` | A value with a trailing comment (`T0 = 3400.0 ! K`) stops BCB naming the key: it is not a number; nothing is written. |
| `DP-phase-type-refused` | BCB | `BCB/DP-phase-type-refused` | `<phase>-type` on a face where no reader uses it stops BCB naming the key and the face type. |
| `IG-keys-documented` | BCB | `BCB/IG-keys-documented` | `Ae_At = 0`, `a1-a3 = 0` (not given) are silent; `u` and `p-time-file` get one WARNING each and do not stop BCB. |
| `IG-nozzle-arearatio` | BCB | `BCB/IG-nozzle-arearatio` | BC 420 from `Ae_At` on a constant-cp gas (closed-form thresholds). |
| `IG-borda-2D` | BCB | `BCB/IG-borda-2D` | BC 421 Borda injector on a 2D mesh; the product passes `scripts/check-bc.py`. |
| `IG-inflow-405a` | BCB | `BCB/IG-inflow-405a` | The supersonic 405 given by `mach`, `p0`, `T0` (static state of the isentropic expansion). |
| `IG-composition-sum-refused` | BCB | `BCB/IG-composition-sum-refused` | Mass fractions of an inlet that sum to 0.99 stop BCB naming the section and the sum; nothing is written. |
| `IG-nozzle-inlet-envelope-refused` | BCB | `BCB/IG-nozzle-inlet-envelope-refused` | A nozzle inlet (BC 420) with `psup` above `psub` stops BCB (0 < psup <= psub < p0 is required); nothing is written. |
| `IG-2D-inlet-408-refused` | BCB | `BCB/IG-2D-inlet-408-refused` | A normal-velocity inlet (BC 408) on a pure 2-D mesh stops BCB: Q2D, which reads 2-D meshes, does not implement BC 408; nothing is written. |
| `IG-force-connect-plate` | BCB | `BCB/IG-force-connect-plate` | `BC-force-connect` on an injection plate declared inlet with hole blocks: hole cells connected (101), the rest keeps the inlet, one LOG line. |
| `IG-time-file-long-name` | BCB | `BCB/IG-time-file-long-name` | A time-file name over 32 characters: accepted with `line-file` (32-character file and record), refused for a user file. |
| `IG-linefile-sector-axis` | BCB | `BCB/IG-linefile-sector-axis` | A line-file strip over a quarter of the lap, `n-repeat = 4` and `axis = x`, on a face whose inward normal is -x: every face cell holds the closed-form law of the strip at 4 theta, the axial velocity enters the domain, one `[INFO]` line; `axis = y`, parallel to the face, stops BCB. |
| `IG-multipatch-410-linefile` | BCB | `BCB/IG-multipatch-410-linefile` | A 410 inlet written from a line-file as the one patch of a multipatch face gives the `bc.txt` of the same face declared directly; two patches run. |
| `IG-ablation` | BCB | `BCB/IG-ablation` | BC 505 (ablation, surface reactions): the model id is written as an integer, as the solver reads it. |
| `IG-table-no-data` | BCB | `BCB/IG-table-no-data` | A table file without any row of two numbers is refused as a file without data rows, not as a missing file. |
| `IG-multigrid-2D` | BCB | `BCB/IG-multigrid-2D` | `MG-levels = 3` on a pure-2D mesh: `bc2.txt` and `bc3.txt` are pure 2D, equal to `bc.txt` of the level meshes given directly. |
| `BCB-direction-refused` | BCB | `BCB/IG-xtheta-variable-T` | A direction letter outside x, y, z, r, t, i, j, k (here `X`) stops BCB naming the key. |
| `SP-wall-305` | BCB | `BCB/SP-wall-305` | A solid wall with `hconv`, `eps` and `Tref` is written as BC 305 with the payload in the order FUSS reads it (`hconv, eps, Tref`); `eps` and `Tref` alone stay 304. |
| `balance-only` | MDB | `MDB/balance-only` | Load-balancing pass without splitting. |
| `block-directions` | MDB | `MDB/block-directions` | Per-direction block splitting behaviour. |
| `halo-trade` | MDB | `MDB/halo-trade` | Halo exchange bookkeeping between partitions. |
| `mg3-granularity` | MDB | `MDB/mg3-granularity` | Partition granularity under 3 multigrid levels. |
| `split-longest` | MDB | `MDB/split-longest` | Splitting along the longest block direction. |
| `grid-p3d-3D` | BCB + MDB | `MDB/grid-p3d-3D` | A 3D grid given to MDB as a PLOT3D file is split as the same grid in Tecplot. |
| `split-solution` | MDB | `MDB/split-solution` | Splitting a case that carries a solution field. |
| `coupled-phases` | BCB + MDB | `MDB/coupled-phases` | Two-phase interface: type-`103` donors remapped against the other phase's decomposition. |
| `dispersed-populations` | BCB + MDB | `MDB/dispersed-populations` | A dispersed phase with two materials, one of them in two populations, on two multigrid levels: the per-(material, population) tables are split block by block. |
| `coupled-phases-ks` | BCB + MDB | `MDB/coupled-phases-ks` | `coupled-phases` with a uniform roughness `ks` on the gas connection: MDB carries it through the split; the solid files are unchanged. |
| `coupled-phases-ksfile` | BCB + MDB | `MDB/coupled-phases-ksfile` | The same interface with a real-fluid gas and `ks` read from a file along x: each 103 record gets the value at its own centre. |
| `x-variable` | STB | `STB/x-variable` | Spatially varying source-term generation along x. |
| `area-any-order` | STB | `STB/area-any-order` | An area profile in any row order gives the area law of the sorted profile. |
| `mesh-p3d-fallback` | BCB | `BCB/mesh-p3d-fallback` | An unreadable `mesh.p3d` is followed by `mesh.szplt` with a WARNING naming both files. |
| `IG-table-header-skipped` | BCB | `BCB/IG-table-header-skipped` | A table row that is not two numbers is skipped with a WARNING; the product is that of the file without the row. |
| `IG-table-not-monotone` | BCB | `BCB/IG-table-not-monotone` | A table whose coordinate column turns back is refused: the reader names the row and BCB says the file is refused for its content. |
| `IG-table-decreasing` | BCB | `BCB/IG-table-decreasing` | A table with decreasing coordinates gives the `bc.txt` of the same rows in increasing order. |
| `IG-duplicate-section-lenient` | BCB | `BCB/IG-duplicate-section-lenient` | With `strict-keys = false` a section written twice in the `BCB-file` gets one WARNING; `bc.txt` is that of the deck without the copy. |
| `IG-duplicate-section-identical` | BCB | `BCB/IG-duplicate-section-identical` | With the default settings a section written twice with the same keys and values (other key order, a comment line, a blank line) gets one WARNING that says so; `bc.txt` is that of the deck with one copy. |
| `IG-duplicate-section-conflict` | BCB | `BCB/IG-duplicate-section-conflict` | Two copies of a section that differ: the ERROR and no `bc.txt` with the default settings; one WARNING and the `bc.txt` of the first copy with `strict-keys = false`. |
| `mesh-p3d-single-plane` | BCB | `BCB/mesh-p3d-single-plane` | A PLOT3D mesh with one node plane (`Ni Nj 1`) is the pure-2D mesh of its x-y plane: `bc.txt` of the same grid in Tecplot. |
| `mesh-p3d-plane-perpendicular` | BCB | `BCB/mesh-p3d-plane-perpendicular` | A PLOT3D mesh with one node plane in x-z (no area on x-y) is refused. |
| `mesh-tec-single-plane` | BCB | `BCB/mesh-tec-single-plane` | A Tecplot mesh with x y z on one node plane (`K = 1`) follows the PLOT3D rule: on z = 0 and on a tilted plane the `bc.txt` of `mesh-p3d-single-plane` (a WARNING for the tilted plane); on x-z it is refused. |
| `IG-comment-lines` | BCB | `BCB/IG-basic` | Comment lines starting with `#`, `;` or `!` that hold an equals sign are ignored: `bc.txt` equals the one of the deck without them. |
| `IG-massfraction-range` | BCB | `BCB/IG-massfraction-range` | A `y<species>` value outside [0, 1] stops BCB with one message naming the key and the value; a value outside by rounding only (1.0000000000000002, -1.0e-20) is read as 1 and 0. |
| `IG+SP-force-chimera` | BCB | `BCB/IG+SP-force-chimera` | Inter-phase chimera: with `BC-force-chimera` the facelets between a gas block and a solid block are written as 104 in both `gas-bc.txt` and `solid-bc.txt`. |
| `DP-multigrid` | BCB | `BCB/DP-multigrid` | One dispersed-phase BC file per multigrid level, each with its own table and every (material, population) copy. |
| `DP-z-variable-krho` | BCB | `BCB/DP-z-variable-krho` | Dispersed-phase inlet with a `krho` profile read along z and phase-prefixed keys. |
| `DP-tokens-tolerated` | BCB | `BCB/DP-tokens-tolerated` | `key=value` tokens on the material line of a dispersed-phase file are for the solvers: BCB ignores them and writes the `drop-bc.txt` of `DP-basic`. |
| `DP-bad-name` | BCB | `BCB/DP-bad-name` | A phase file name with two dashes is refused. |
| `DP-substring-names` | BCB | `BCB/DP-substring-names` | Phase names nested in each other (`part`, `partL`) are refused before any BC file is built. |
| `DP-two-phases` | BCB | `BCB/DP-two-phases` | Two dispersed phases on the same faces: each `<name>-bc.txt` carries the ids and payloads of its own phase. |
| `DP-axis-override` | BCB | `BCB/DP-axis-override` | `<phase>-type = outlet` on an axisymmetric face: the dispersed-phase file carries 400 on the axis, the gas file keeps 200. |
| `DP-axis-symmetry` | BCB | `BCB/DP-axis-symmetry` | `<phase>-type = symmetry` on an axisymmetric face: the dispersed-phase file carries 300 on the axis, the gas file keeps 200. |
| `DP-axis-refused` | BCB | `BCB/DP-axis-refused` | Any other `<phase>-type` word on an axisymmetric face stops BCB naming the two accepted ones. |
| `IG+DP` | ICB | `ICB/IG+DP` | Gas and dispersed phase: the dispersed-phase IC file carries the population fields. |

## Test Families And Their Intent

### BCB Cases (`test/BCB/`)

BCB tests check that boundary-condition definitions are translated into correct solver-ready BC files.

- `IG-basic`, `IG-2D`: validate baseline ideal-gas BC setup in different dimensional layouts.
- `IG-periodic`: validate periodic-face pairing logic.
- `IG-multipatch-*`: validate patch indexing, file-driven patches, and multi-face mapping behavior.
- `IG-inflow-*`: validate inflow models, including nozzle and CEA-coupled inflow definitions.
- `IG-chimera`: validate overset/chimera boundary metadata preparation.
- `mesh-p3d-3D`: validate the search of a PLOT3D mesh alone and its 3D reading (the product of the same grid in Tecplot).
- `IG+CD`, `IG+SP`, `DP-*`, `SP-basic`: validate mixed boundary models (ideal gas, condensed, dispersed, solid).
- `IG-nozzle-arearatio`: validate the BC 420 injector nozzle (thresholds from `Ae_At`).
- `IG-borda-2D`: validate the BC 421 Borda injector (a Q2D-only record on a 2D mesh).
- `mesh-p3d-fallback`: validate the mesh search (`mesh.tec` -> `mesh.p3d` -> `mesh.szplt`) when `mesh.p3d` cannot be read.
- `IG-table-not-monotone`: validate the refusal of a table whose coordinate column turns back (the message says the file is refused, not missing).
- `IG-table-decreasing`, `IG-table-no-data`: validate a table with decreasing coordinates (read in increasing order) and the refusal of a table file without data rows (not reported as missing).
- `IG-duplicate-section-lenient`: validate the lenient key check of a section written twice (the options of the next sections are all read).
- `IG-duplicate-section-identical`, `IG-duplicate-section-conflict`: validate the rule for a section written twice: two copies with the same keys and values only warn, copies that differ stop the tool unless `strict-keys = false`.
- `mesh-p3d-single-plane`: validate a PLOT3D mesh written with one node plane (read as the pure-2D mesh of its x-y plane).
- `mesh-p3d-plane-perpendicular`: validate the refusal of a single node plane perpendicular to x-y.
- `mesh-tec-single-plane`: validate the same rule for a Tecplot mesh with x y z on one node plane (`K = 1`).
- `IG-multigrid-2D`: validate the coarse levels of a pure-2D mesh (pure 2D on every level).
- `IG-force-connect-plate`, `IG-plate-keys`, `IG-keys-documented`, `IG-renamed-keys-lenient`, `IG-time-file-long-name`, `IG-table-header-skipped`: validate `BC-force-connect` on a declared inlet, the documented keys and defaults that must not stop BCB, the keys of older decks, the series file names and the tables with a non-numeric row.
- `SP-wall-305`: validate the choice between the solid-wall records 304 and 305 and the order of the 305 payload.

### GPB Cases (`test/GPB/`)

GPB tests check that phase-property builders generate physically consistent tables for different thermodynamic models.

- `IG-fixgas`, `IG-party`: validate fixed ideal-gas workflows.
- `IG-reactive`, `IG-ceafile-reactive-*`: validate reactive chemistry table generation from CEA/case inputs.
- `IG-ceafile-frozen-mixing-HG`, `IG-mixture-HG`: validate heavy-gas and mixing assumptions.
- `IG-ct-equilibrium`, `*-cantera`: validate Cantera-backed equilibrium/property paths.
- `RF-*`: validate real-fluid table generation (e.g., water, CO2).
- `CP-*`, `SP-*`: validate condensed and solid phase-property workflows.

### ICB Cases (`test/ICB/`)

ICB tests check that initial-condition fields are built correctly on different grids and initialization strategies.

- `IG-1D`, `IG-2D`: validate baseline dimensional initialization.
- `IG-nozzle2D`, `IG-nozzle3D`: validate nozzle-specific initialization workflows.
- `IG-interp-*`: validate interpolation-based field initialization (distance/species/decomposition).
- `IG-multizone`: validate multi-zone initialization logic.
- `IG+CD`, `IG+SP`, `SP-basic`, `RF-basic`: validate coupled gas/condensed/solid/real-fluid IC outputs.

### KAnT Cases (`test/KAnT/`)

KAnT tests check chemistry-analysis workflows produce expected trends and outputs for canonical kinetics studies.

- `equilibrium`: validate equilibrium-state computations.
- `ignition_delay`, `ignition_delay_exp`: validate ignition-delay predictions and experiment-style setup handling.
- `time_evolution`: validate transient 0D species/temperature evolution workflows.
- `counterflow`: validate counterflow chemistry/flame workflow setup.

### MDB Cases (`test/MDB/`)

MDB tests check that a mesh and its BC data are split consistently across parallel partitions.

- `split-longest`, `block-directions`: validate the choice of split direction.
- `grid-p3d-3D`: validate a 3D grid given to MDB as a PLOT3D file (read as 3D: the products of the same grid in Tecplot).
- `balance-only`: validate load balancing when no split is required.
- `halo-trade`: validate halo/ghost bookkeeping between partitions.
- `mg3-granularity`: validate partition sizing under multigrid constraints.
- `split-solution`: validate splitting a case that also carries a solution field.
- `coupled-phases`: validate cross-phase (`103`) donor remapping when two phases are cut at different indices.

### STB Cases (`test/STB/`)

STB tests check source-term field generation.

- `uniform`: validate constant source-term generation.
- `x-variable`: validate spatially varying source terms.
- `area-any-order`: validate an area profile given in any row order.

## Running The Registered Regression Set

```bash
cd build
ctest --output-on-failure
```

To run one specific test objective only:

```bash
cd build
ctest -R IG-nozzle3D --output-on-failure
```

---

See also [Project Structure](./structure.md) and [Build Instructions](./build.md).

## The standard of a registered test

Each registered test is one case folder under `test/<TOOL>/` and one `add_test` in `test/CMakeLists.txt`, of one
of two kinds:

1. **Golden**: the tool runs on a fixture and the product is compared with `reference/` (`diff` for exact
   products, `test/numdiff.awk` at `tol = 1e-12` for interpolated fields and computed records, `1e-6` for
   the chimera cases). The reference is either an independent oracle (a closed form, a hand-written record,
   the product of another tool or of another deck by symmetry) or, when no oracle exists, the tool's own
   product pinned as a regression witness; the registration comment says which.
2. **Negative**: the tool must stop with a non-zero status, print a named diagnostic and write no product.

A test is added for a corrected defect (it fails before the correction), for an added or repaired function
(one positive case) and for a kept refusal (one representative case per kind of refusal). Fixtures are
small (a few cells, a few KB). The upstream tests are kept as they are.
