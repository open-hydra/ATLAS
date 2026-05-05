# ICB API Reference

Fortran program `ICB` — `src/hydra-tools/ICB/`

::: warning Work in progress
:::

## Modules

| Module | Description |
|--------|-------------|
| [Types](./types) | `ic_block_type` |
| [Builders](./builders) | Per-strategy build subroutines |

## Key Source Files

| File | Module | Role |
|------|--------|------|
| `ICB.f90` | (program) | Entry point |
| `config.f90` | `config_mod` | Runtime parameters |
| `types_block.f90` | `ic_block_mod` | Block data type |
| `builder.f90` | `ic_builder_mod` | Top-level dispatch |
| `builder_ig.f90` | `ic_builder_ig_mod` | Ideal-gas builder |
| `builder_rf.f90` | `ic_builder_rf_mod` | Real-fluid builder |
| `builder_dp.f90` | `ic_builder_dp_mod` | Dispersed-phase builder |
| `builder_sp.f90` | `ic_builder_sp_mod` | Solid-particle builder |
| `interpolation_general.f90` | `ic_interpolation_mod` | Interpolation |
| `interpolation_import.f90` | — | Hydra solution import |
| `io_fields.f90` | — | Binary output |
