# STB Output Files

::: warning Work in progress
This page is being populated.
:::

## Output

STB writes a single binary file (default `area.bin`) containing the discretized area schedule. The file follows the Hydra block-file convention and is passed directly to the solver via the simulation input deck.

## Format

1. Header (number of axial stations)
2. Array of axial positions $x_i$ (m)
3. Array of cross-sectional areas $A_i$ (m²)
4. Array of area derivatives $\mathrm{d}A/\mathrm{d}x|_i$
