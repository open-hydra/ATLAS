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
| `ICB-type-refused` | ICB | `ICB/ICB-type-refused` | A zone `type` that no writer knows stops ICB naming the value. |
| `IG-interp-2D` | ICB | `ICB/IG-interp-2D` | Pure-2D source onto a pure-2D target (index law). |
| `IG-interp-2Dto3D` | ICB | `ICB/IG-interp-2Dto3D` | Pure-2D source onto a revolved 3D target: the source mesh is classified in its own configuration and the product keeps the 3D layout (tolerance 1e-12). |
| `IG-interp-rans-src` | ICB | `ICB/IG-interp-rans-src` | Source with a trailing turbulence band: the SA model of the source is adopted and `mi_t` interpolated. |
| `IG-interp-3D` | ICB | `ICB/IG-interp-3D` | 3D source onto a 3D target (index law). |
| `IG-interp-extrude` | ICB | `ICB/IG-interp-extrude` | `interpolation-law = extrude` (`theta`, `nz`) on a target revolved with the same cells gives the field of the index law. |
| `IG-zones-index-direction` | ICB | `ICB/IG-zones-index-direction` | Zones ranged by cell index (`direction = i`) give the field of the same zones ranged by coordinate. |
| `IG-zone-interp-range` | ICB | `ICB/IG-zone-interp-range` | An interpolation zone writes the cells of its range only (both zone orders give the same field). |
| `SP-interp` | ICB | `ICB/SP-interp` | A solid field interpolated onto its own mesh is the source field. |
| `IG-pfile-oneplane-2block` | ICB | `ICB/IG-pfile-oneplane-2block` | One-plane (K=1) `p-file` sources on two blocks: the source array keeps its plane. |
| `IG-zone-unwritten-refused` | ICB | `ICB/IG-zone-unwritten-refused` | Cells that no zone writes stop ICB naming block, phase and count. |
| `IG+DP-phase-order` | ICB | `ICB/IG+DP` | `phase = particles gas` builds as `gas particles`: the dispersed state derives from the gas state. |
| `ICB-phase-key-refused` | ICB | `ICB/IG+DP` | A phase name that no phase file declares, and a dispersed phase without the gas it derives from, stop ICB naming the cause. |
| `IG-pfile-oneplane-noK` | ICB | `ICB/IG-pfile-oneplane-2block` | A two-block pure 2-D p-file written without K in its ZONE lines reads like K = 1: the product equals the K = 1 reference. |
| `IG-zone-interp-range-turb` | ICB | `ICB/IG-zone-interp-range-turb` | A partial interpolation zone that adopts the source turbulence model writes `mi_t` in its range only; the cells of the other zone keep 0. |
| `IG-range-separator-refused` | ICB | `ICB/IG-multizone` | A TAB between the two values of `range<n>` stops ICB naming the separator (the values are read on blanks). |
| `IG-turbulence-zero-refused` | ICB | `ICB/IG-turbulence-zero-refused` | A k-omega zone (nrans = 2) with `kappa` and no `omega` stops ICB (omega = 0 would divide in the solver kernels); nothing is written. |
| `IG-state-not-physical` | ICB | `ICB/IG-state-not-physical` | A zone with a negative pressure stops ICB naming the first cell and the state; nothing is written. |
| `IG-interp-band-refused` | ICB | `ICB/IG-interp-band-refused` | An interpolation source whose band after the velocities is `T`, not `p`, stops ICB naming the band; nothing is written. |
| `IG-species-profile-linear` | ICB | `ICB/IG-species-profile-linear` | `y<species>-file` tables along x (`yH2` linear, `yN2` its complement) next to a constant `yO2`: every cell holds the analytic mass fractions, summing to 1, and a density that follows its own composition. |
| `IG-interp-2D-wband` | ICB | `ICB/IG-interp-2D-wband` | The source of `IG-interp-2D` with a third velocity band `w = 0` after `v`: read, same `gas-ic.tec`. |
| `IG-block-no-section` | ICB | `ICB/IG-block-no-section` | A block that no `[ICB-Block<n>]` or `[ICB-Block*]` section describes stops ICB naming the block. |
| `IG-phase-unbuilt` | ICB | `ICB/IG-phase-unbuilt` | A phase that no block names is not written (one `[WARNING]`, no `part-ic.tec`). |
| `IG-interp-spherical-3D` | ICB | `ICB/IG-interp-spherical-3D` | `interpolation-law = spherical_minimum_distance` on a 3-D target: from a one-cell source it equals `minimum_distance`. |
| `IG-interp-src-3coord-plane` | ICB | `ICB/IG-interp-src-3coord-plane` | An interpolation source written as a slice (x y z on one node plane, `K = 1`, z nodal, bands cell-centred) gives the `ic.tec` of the same source written with x y only. |
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
| `qvol-direction-combined` | STB | `STB/qvol-direction-combined` | A qvol profile with `direction = xy` is read along x with a `[WARNING]`: `st.tec` equals the one of `direction = x`. |
| `mesh-p3d-fallback` | BCB | `BCB/mesh-p3d-fallback` | An unreadable `mesh.p3d` is followed by `mesh.szplt` with a WARNING naming both files. |
| `IG-table-header-skipped` | BCB | `BCB/IG-table-header-skipped` | A table row that is not two numbers is skipped with a WARNING; the product is that of the file without the row. |
| `IG-table-not-monotone` | BCB | `BCB/IG-table-not-monotone` | A table whose coordinate column turns back is refused: the table reader names the row where it turns back; no `bc.txt`. |
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
- `mesh-p3d-fallback`: validate the mesh search (`mesh.tec` -> `mesh.p3d` -> `mesh.szplt`) when `mesh.p3d` cannot be read.
- `IG-duplicate-section-lenient`: validate the lenient key check of a section written twice (the options of the next sections are all read).
- `IG-duplicate-section-identical`, `IG-duplicate-section-conflict`: validate the rule for a section written twice: two copies with the same keys and values only warn, copies that differ stop the tool unless `strict-keys = false`.
- `mesh-p3d-single-plane`: validate a PLOT3D mesh written with one node plane (read as the pure-2D mesh of its x-y plane).
- `mesh-p3d-plane-perpendicular`: validate the refusal of a single node plane perpendicular to x-y.
- `mesh-tec-single-plane`: validate the same rule for a Tecplot mesh with x y z on one node plane (`K = 1`).
- `IG-table-header-skipped`: validate the tables with a non-numeric row.
- `IG-table-decreasing`: validate a table with decreasing coordinates (read in increasing order).
- `IG-table-not-monotone`: validate the refusal of a table whose coordinate column turns back.

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
- `IG-interp-*`: validate interpolation-based field initialization: `IG-interp-mindist` (distance law on a real MOSE dump),
  the `index` law from a pure-2D source onto pure-2D and revolved 3D targets, from a 3D source and from a source with a
  turbulence band (`IG-interp-2D`, `IG-interp-2Dto3D`, `IG-interp-3D`, `IG-interp-rans-src`), and the revolved source of
  `interpolation-law = extrude` (`IG-interp-extrude`); the species/decomposition folders are not registered.
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
- `qvol-direction-combined`: validate a combined `direction` of a qvol profile (read along its first letter, with a warning).
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
