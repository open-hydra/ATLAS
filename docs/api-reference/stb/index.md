# STB API Reference

Fortran program `STB` — `src/hydra-tools/STB/`

::: warning Work in progress
:::

## Source Files

| File | Module | Role |
|------|--------|------|
| `STB.f90` | (program) | Entry point; reads INI, calls area builder |
| `area_variation.f90` | `area_variation_mod`, `area_law` | Area schedule computation |

## `area_variation_mod`

Subroutines:

- `compute_area_schedule(cfg, x, A, dAdx)` — computes $(x_i, A_i, \mathrm{d}A/\mathrm{d}x|_i)$ from the geometry data
- `write_area_schedule(path, x, A, dAdx)` — writes the binary output file

## `area_law`

Optional analytical area distribution laws (e.g. linear, power-law, conic) that can be used instead of a point-cloud geometry file.
