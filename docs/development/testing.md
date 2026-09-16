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
| `DP-basic` | BCB | `BCB/DP-basic` | Dispersed-phase BC assignment and export. |
| `balance-only` | MDB | `MDB/balance-only` | Load-balancing pass without splitting. |
| `block-directions` | MDB | `MDB/block-directions` | Per-direction block splitting behaviour. |
| `halo-trade` | MDB | `MDB/halo-trade` | Halo exchange bookkeeping between partitions. |
| `mg3-granularity` | MDB | `MDB/mg3-granularity` | Partition granularity under 3 multigrid levels. |
| `split-longest` | MDB | `MDB/split-longest` | Splitting along the longest block direction. |
| `split-solution` | MDB | `MDB/split-solution` | Splitting a case that carries a solution field. |
| `coupled-phases` | BCB + MDB | `MDB/coupled-phases` | Two-phase interface: type-`103` donors remapped against the other phase's decomposition. |
| `x-variable` | STB | `STB/x-variable` | Spatially varying source-term generation along x. |

## Test Families And Their Intent

### BCB Cases (`test/BCB/`)

BCB tests check that boundary-condition definitions are translated into correct solver-ready BC files.

- `IG-basic`, `IG-2D`: validate baseline ideal-gas BC setup in different dimensional layouts.
- `IG-periodic`: validate periodic-face pairing logic.
- `IG-multipatch-*`: validate patch indexing, file-driven patches, and multi-face mapping behavior.
- `IG-inflow-*`: validate inflow models, including nozzle and CEA-coupled inflow definitions.
- `IG-chimera`: validate overset/chimera boundary metadata preparation.
- `IG+CD`, `IG+SP`, `DP-*`, `SP-basic`: validate mixed boundary models (ideal gas, condensed, dispersed, solid).

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
- `balance-only`: validate load balancing when no split is required.
- `halo-trade`: validate halo/ghost bookkeeping between partitions.
- `mg3-granularity`: validate partition sizing under multigrid constraints.
- `split-solution`: validate splitting a case that also carries a solution field.
- `coupled-phases`: validate cross-phase (`103`) donor remapping when two phases are cut at different indices.

### STB Cases (`test/STB/`)

STB tests check source-term field generation.

- `uniform`: validate constant source-term generation.
- `x-variable`: validate spatially varying source terms.

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
