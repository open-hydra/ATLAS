# GPB Ideal-Gas Modules

Source: `src/hydra-tools/GPB/ideal_gas/`

::: warning Work in progress
:::

## `ideal_gas.builder` — Top-Level Builder

```python
from GPB.ideal_gas.builder import build
build(phase_cfg)
```

Dispatches to thermo, transport, and IO sub-builders based on `phase_cfg.thermo` and `phase_cfg.transport` values.

## `ideal_gas.thermo` — Thermodynamic Tables

Generates $c_p(T)$, $h(T)$, $s^\circ(T)$ tables from NASA-9 polynomial fits or CEA curve fits.

## `ideal_gas.transport` — Transport Tables

Generates $\mu(T)$, $\lambda(T)$ from Sutherland, CEA, or Cantera models.

## `ideal_gas.chemistry` — Reaction Mechanism Helpers

Reads a Cantera `.yaml` mechanism file and constructs the species list.

## `ideal_gas.io` — Output Writers

Writes the binary property file to `OUTPATH` (default `fromATLAStoSolver/`).
