# BCB Types

Source: `src/hydra-tools/BCB/types_bc.f90`, `types_block.f90`

::: warning Work in progress
:::

## `bc_type` (module `bc_mod`)

Stores the data for a single boundary face group.

| Component | Type | Description |
|-----------|------|-------------|
| `bc_code` | `integer` | Numeric BC type code |
| `face_tag` | `character(len=64)` | Mesh face tag string |
| `n_faces` | `integer` | Number of faces in the group |
| `data` | `real(8), allocatable(:)` | Prescribed state data (where applicable) |

## `block_type` (module `bc_block_mod`)

Top-level container for all BCs belonging to one mesh block.

| Component | Type | Description |
|-----------|------|-------------|
| `block_id` | `integer` | Block index |
| `bcs` | `type(bc_type), allocatable(:)` | Array of BC groups |
