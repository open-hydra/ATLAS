# ICB Types

Source: `src/hydra-tools/ICB/types_block.f90`

::: warning Work in progress
:::

## `ic_block_type` (module `ic_block_mod`)

| Component | Type | Description |
|-----------|------|-------------|
| `block_id` | `integer` | Block index |
| `strategy` | `character(len=64)` | IC strategy identifier |
| `nx, ny, nz` | `integer` | Block dimensions |
| `q` | `real(8), allocatable(:,:,:,:)` | Conservative-variable array $(i,j,k,\text{neq})$ |
