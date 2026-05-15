# Testing

This page describes ATLAS tests in plain terms: what each test is trying to prove.

## What A Test Checks

Most regression tests run one tool (`GPB`, `BCB`, `ICB`, or `STB`) from a case folder and then compare produced files with reference files.

If outputs match, the test objective is considered met.

## Active CTest Regression Cases

These are the cases currently registered in `test/CMakeLists.txt`.

| Test name | Tool | Main goal |
|---|---|---|
| `ceafile-reactive-OG` | GPB | Verify reactive gas setup from CEA data produces stable composition/chemistry outputs. |
| `SP-basic` | ICB | Verify basic solid initial-condition field generation. |
| `IG-nozzle3D` | ICB | Verify 3D nozzle initial-condition generation and VTK export path. |
| `IG-inflow-nozzle` | BCB | Verify nozzle inflow boundary-condition construction. |
| `IG-multipatch-file` | BCB | Verify multipatch BC assignment when patches are provided by file. |
| `IG-multipatch-1D` | BCB | Verify 1D multipatch face mapping and resulting BC output consistency. |
| `IG-inflow-ceafile-inertmix` | BCB | Verify inflow BC creation using CEA-based inert-mixture inputs. |
| `x-variable` | STB | Verify spatially varying source-term generation along x. |

## Test Families And Their Intent

### BCB Cases (`test/BCB/`)

BCB tests check that boundary-condition definitions are translated into correct solver-ready BC files.

- `IG-basic`, `IG-2D`: validate baseline ideal-gas BC setup in different dimensional layouts.
- `IG-periodic`: validate periodic-face pairing logic.
- `IG-multipatch-*`: validate patch indexing, file-driven patches, and multi-face mapping behavior.
- `IG-inflow-*`: validate inflow models, including nozzle and CEA-coupled inflow definitions.
- `IG-chimera`: validate overset/chimera boundary metadata preparation.
- `IG+CD`, `IG+SP`, `CD-*`, `SP-basic`: validate mixed boundary models (ideal gas, condensed, solid).

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

See also [Project Structure](./structure) and [Build Instructions](./build).
