# GPB — Real-Fluid Phase

## Overview

`type = real-fluid` generates a 2-D lookup table in $(p, h)$ space for a single pure fluid. The table is used by Hydra's real-gas thermodynamics module, which interpolates in $(p, h)$ to obtain density, temperature, speed of sound, and transport properties.

## Minimal Example

```ini
[GPB-Phase1]
type = real-fluid
name = co2
fluid = CO2
pmin = 8e6
pmax = 1.5e7
Tmin = 320
Tmax = 450
NP   = 40
NH   = 40
```

## Parameter Reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `fluid` | string | **required** | Fluid identifier (CoolProp or NIST name) |
| `pmin` | real | — | Minimum table pressure (Pa) |
| `pmax` | real | — | Maximum table pressure (Pa) |
| `Tmin` | real | `1.0` | Minimum table temperature (K) |
| `Tmax` | real | `5000.0` | Maximum table temperature (K) |
| `NP` | integer | `200` | Number of pressure nodes |
| `NH` | integer | `200` | Number of enthalpy nodes |
| `model` | string | `coolprop` | EOS backend |

## EOS Backends

### CoolProp (recommended)

Uses CoolProp's high-accuracy equations of state. Supports a large list of fluids including `CO2`, `Water`, `Nitrogen`, `Hydrogen`, `Methane`, etc.

```ini
model = coolprop    ; default — can be omitted
```

### Redlich–Kwong

$$p = \frac{R_u T}{v - b} - \frac{a}{\sqrt{T}\,v(v+b)}$$

Implemented internally. Suitable for quick checks; less accurate than CoolProp near the critical point.

```ini
model = redlich-kwong
```

### Peng–Robinson

$$p = \frac{R_u T}{v - b} - \frac{a\,\alpha(T)}{v(v+b) + b(v-b)}$$

```ini
model = peng-robinson
```

## Grid Size Guidelines

Default $200 \times 200$ provides good accuracy for most cases. Near the critical point, finer grids may be required.

| Accuracy goal | Suggested NP × NH |
|---------------|-------------------|
| Engineering | 100 × 100 |
| Standard | 200 × 200 |
| High (near critical point) | 500 × 500 |

## Cantera Real-Fluid Setup

If Cantera is also needed alongside a real-fluid phase (e.g. for transport properties), add `eq-*` keys as in the ideal-gas case:

```ini
[GPB-Phase1]
type        = real-fluid
name        = co2_ct
fluid       = CO2
pmin        = 8e6
pmax        = 1.5e7
Tmin        = 320
Tmax        = 450
eq-fuel     = CO2
eq-pressure = 10e6
```
