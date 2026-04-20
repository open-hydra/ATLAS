# ICB Output Files

::: warning Work in progress
This page is being populated.
:::

## Output Directory

ICB writes binary IC block files to the directory specified by `output-dir` (default `./`).

## File Naming

```
IC_block_<n>.bin
```

Where `<n>` is the block index. Each file contains the full conservative-variable field for that block at $t = 0$.

## File Content

The binary layout follows the Hydra block-file convention (see `src/hydra-tools/ICB/io_fields.f90`):

1. Header (block dimensions, number of equations, phase type code)
2. Conservative variable array in Fortran column-major order: $(\rho, \rho u, \rho v, \rho w, \rho E, \ldots)$
