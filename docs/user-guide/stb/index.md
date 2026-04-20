# STB — Setup Tool Builder

STB is a Fortran executable that pre-processes geometric data for nozzle and duct configurations. Its primary output is the **area schedule** used by Hydra's quasi-1-D geometry option.

## Usage

```bash
./STB -input stb.ini
```

## Sections

- [Input Reference](./input-reference) — INI keys and supported parameters
- [Output Files](./output) — Files written for Hydra

## Overview

STB reads a cross-sectional area distribution (or a set of points defining the contour) and writes the area-variation data needed by Hydra for variable-area duct / nozzle simulations.

Implemented modules (see `src/hydra-tools/STB/`):

- `area_variation.f90` — area schedule computation from geometry input
- `STB.f90` — main program, INI parsing and dispatch

See the [tutorials](/tutorials/stb/) for worked examples.
