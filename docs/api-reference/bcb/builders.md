# BCB Builders

Source: `src/hydra-tools/BCB/builder_block.f90`, `builder_face.f90`, `builder_200/300/400*/500.f90`

::: warning Work in progress
:::

## `build_block` (module `bc_builder_mod`)

Top-level subroutine. Reads the INI section for one block and populates a `block_type`.

```fortran
call build_block(cfg, block_idx, blk)
```

## Per-Type Builders

Dispatched from `build_block` based on `bc_code`:

| Builder | File | BC family |
|---------|------|-----------|
| `build_200` | `builder_200.f90` | Inlet BCs |
| `build_300` | `builder_300.f90` | Outlet BCs |
| `build_400_dp` | `builder_400dp.f90` | Dispersed-phase wall |
| `build_400_ig` | `builder_400ig.f90` | Ideal-gas wall |
| `build_500` | `builder_500.f90` | Connection BCs |

## `build_face` (module `bc_cell_builder_mod`)

Populates individual face metadata (connectivity indices, neighbour block).
