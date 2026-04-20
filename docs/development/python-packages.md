# Python Package Reference

Top-level modules and their public interfaces for the ATLAS Python tools.

::: warning Work in progress
See the [API Reference](/api-reference/) for detailed per-symbol documentation.
:::

## GPB Package (`src/hydra-tools/GPB/`)

| Module | Public API |
|--------|-----------|
| `GPB.__main__` | CLI entry point; `--input-file`, `--write-config-doc` |
| `GPB.config` | `ATLASDIR`, `OUTPATH`, `HG_FACTOR`, `HG_SUBSTRING`, `CEA_TRANS_FILE` |
| `GPB.input_registry` | `dispatch(section)` |
| `GPB.ini.common` | `parse_common(section)` → `PhaseConfig` |
| `GPB.ini.ideal_gas` | `parse_ideal_gas(section)` |
| `GPB.ini.condensed` | `parse_condensed(section)` |
| `GPB.ini.real_fluid` | `parse_real_fluid(section)` |
| `GPB.ini.equilibrium` | `parse_equilibrium(section)` |
| `GPB.ideal_gas.builder` | `build(phase_cfg)` |
| `GPB.condensed.builder` | `build(phase_cfg)` |
| `GPB.real_fluid.builder` | `build(phase_cfg)` |

## KAnT Package (`src/KAnT/`)

| Module | Public API |
|--------|-----------|
| `KAnT.__main__` | CLI entry point |
| `KAnT.simulations.counterflow` | `run(cfg)` |
| `KAnT.simulations.equilibrium` | `run(cfg)` |
| `KAnT.simulations.ignition_delay` | `run(cfg)` |
| `KAnT.simulations.time_evolution` | `run(cfg)` |
