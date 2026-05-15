# Fortran Module Reference

This page lists the Fortran modules compiled by ATLAS and their purpose. Module files (`.mod`) are generated in `build/modules/`.

::: warning Work in progress
Descriptions are being filled in as the codebase is documented.
:::

## BCB Modules

| Module | File | Description |
|--------|------|-------------|
| `bc_mod` | `types_bc.f90` | Core BC data types: condition tags, conditions, condition vectors |
| `bc_block_mod` | `types_block.f90` | Multi-block BC container and block-level metadata |
| `bc_builder_mod` | `builder_block.f90` | Block-level BC construction from INI specifications |
| `bc_cell_builder_mod` | `builder_face.f90` | Face/cell-level BC construction and assembly |
| `bc_connection_mod` | `connection_standard.f90` | Standard block-to-block connectivity handling |
| `bc_chimera_mod` | `connection_chimera.f90` | Chimera overset grid connectivity and interpolation |
| `bc_names` | `bc_names.f90` | BC type name constants and enumerations |

## ICB Modules

| Module | File | Description |
|--------|------|-------------|
| `ic_block_mod` | `types_block.f90` | IC block container: fields, metadata, block arrays |
| `ic_builder_mod` | `builder.f90` | Top-level IC dispatcher: routes to phase-specific builders |
| `ic_builder_ig_mod` | `builder_ig.f90` | Ideal-gas IC builder: temperature, pressure, species fields |
| `ic_builder_rf_mod` | `builder_rf.f90` | Real-fluid IC builder: compressible mixture initialization |
| `ic_builder_sp_mod` | `builder_sp.f90` | Solid-particle IC builder: Lagrangian particle initialization |
| `ic_interpolation_mod` | `interpolation_general.f90` | General field interpolation (linear, cubic, RBF) |

## STB Modules

| Module | File | Description |
|--------|------|-------------|
| `area_variation_mod` | `area_variation.f90` | Area schedule computation and geometry updates |
| `area_law` | `area_variation.f90` | Area law profiles: convergent-divergent nozzles |

## Shared/Common Modules

| Module | File | Purpose |
|--------|------|----------|
| `global_mod` | `common/global_mod.f90` | Global constants and parameters |
| `grid_mod` | `common/grid_mod.f90` | Grid representation and access |
| `read_mesh_mod` | `common/read_mesh_mod.f90` | Mesh file I/O and parsing |
| `io_ini_mod` | `common/io_*.f90` | INI configuration file I/O |
| `Lib_ORION_data` | (ORION library) | ORION block structure and metadata |
