# Fortran Module Reference

This page lists the Fortran modules compiled by ATLAS and their purpose. Module files (`.mod`) are generated in `build/modules/`.

::: warning Work in progress
Descriptions are being filled in as the codebase is documented.
:::

## BCB Modules

| Module | File | Description |
|--------|------|-------------|
| `bc_mod` | `types_bc.f90` | BC data types |
| `bc_block_mod` | `types_block.f90` | Block data type |
| `bc_builder_mod` | `builder_block.f90` | Block-level BC construction |
| `bc_cell_builder_mod` | `builder_face.f90` | Face-level BC construction |
| `bc_connection_mod` | `connection_standard.f90` | Standard block-to-block connections |
| `bc_chimera_mod` | `connection_chimera.f90` | Chimera overset connections |
| `bc_names` | `bc_names.f90` | BC type name string constants |

## ICB Modules

| Module | File | Description |
|--------|------|-------------|
| `ic_block_mod` | `types_block.f90` | IC block data type |
| `ic_builder_mod` | `builder.f90` | Top-level IC dispatch |
| `ic_builder_ig_mod` | `builder_ig.f90` | Ideal-gas IC builder |
| `ic_builder_rf_mod` | `builder_rf.f90` | Real-fluid IC builder |
| `ic_builder_sp_mod` | `builder_sp.f90` | Solid-particle IC builder |
| `ic_interpolation_mod` | `interpolation_general.f90` | General interpolation |

## STB Modules

| Module | File | Description |
|--------|------|-------------|
| `area_variation_mod` | `area_variation.f90` | Area schedule computation |
| `area_law` | `area_variation.f90` | Area law analytical forms |
