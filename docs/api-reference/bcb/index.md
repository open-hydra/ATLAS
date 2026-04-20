# BCB API Reference

Fortran program `BCB` — `src/hydra-tools/BCB/`

::: warning Work in progress
:::

## Modules

| Module | Description |
|--------|-------------|
| [Types](./types) | Derived types: `bc_type`, `block_type` |
| [Builders](./builders) | Block and face builder subroutines |

## Key Source Files

| File | Module | Role |
|------|--------|------|
| `BCB.f90` | (program) | Entry point |
| `config.f90` | `config_mod` | Runtime parameters |
| `types_bc.f90` | `bc_mod` | BC data type |
| `types_block.f90` | `bc_block_mod` | Block data type |
| `builder_block.f90` | `bc_builder_mod` | Block construction |
| `builder_face.f90` | `bc_cell_builder_mod` | Face construction |
| `bc_names.f90` | `bc_names` | Type name constants |
| `io_output.f90` | — | Binary output |
