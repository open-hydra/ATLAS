# BCB Boundary Condition Types

::: warning Work in progress
This page is being populated. See the source file `src/hydra-tools/BCB/bc_names.f90` for the authoritative list.
:::

## Categories

### Inflow / Outflow

| Type | Code | Description |
|------|------|-------------|
| Supersonic inlet | `inlet-supersonic` | All conservative variables specified |
| Supersonic outlet | `outlet-supersonic` | Zero-gradient extrapolation |
| Subsonic inlet | `inlet-subsonic` | Total pressure / total enthalpy specified |
| Subsonic outlet | `outlet-subsonic` | Static pressure specified |

### Wall

| Type | Code | Description |
|------|------|-------------|
| Adiabatic slip | `slip-wall` | Euler wall |
| Adiabatic no-slip | `adiabatic-wall` | Viscous, adiabatic |
| Isothermal no-slip | `isothermal-wall` | Viscous, fixed $T_w$ |

### Connectivity

| Type | Code | Description |
|------|------|-------------|
| Block-to-block | `standard` | Matching structured connection |
| Chimera | `chimera` | Overset grid interpolation |
| Periodic | `periodic` | Periodic pair |

### Special

| Type | Code | Description |
|------|------|-------------|
| Symmetry | `symmetry` | Mirror boundary |
| Injection | `injection` | Mass-flow injection |
