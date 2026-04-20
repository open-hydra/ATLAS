# BCB Output Files

::: warning Work in progress
This page is being populated.
:::

## Output Directory

BCB writes binary block files to the directory specified by `output-dir` (default `./`).

## File Naming

```
BC_block_<tag>.bin
```

Each file corresponds to one boundary group section in the INI file.

## File Content

The binary layout is defined in `src/hydra-tools/BCB/io_output.f90` and follows the Hydra block-file convention. Each file contains:

1. Header (block dimensions, BC type code)
2. Connectivity data (face indices, neighbor block ID for connection BCs)
3. Prescribed state data (where applicable — e.g. inlet conditions)
