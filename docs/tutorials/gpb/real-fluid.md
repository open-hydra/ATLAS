# Tutorial: Real-Fluid Phase — CO₂

**Source case:** `test/GPB/RF-co2`

This tutorial shows how to generate a $(p, h)$ lookup table for supercritical $\text{CO}_2$ using the CoolProp backend.

## What You'll Learn

- `type = real-fluid` configuration
- Specifying pressure and temperature ranges
- Choosing the EOS backend
- Grid sizing trade-offs

## The Input File

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

### Key Points

| Key | Value | Meaning |
|-----|-------|---------|
| `fluid = CO2` | — | CoolProp fluid identifier |
| `pmin = 8e6` | 8 MPa | Lower pressure bound (above critical: 7.38 MPa) |
| `pmax = 1.5e7` | 15 MPa | Upper pressure bound |
| `Tmin = 320` | 320 K | Lower temperature bound (above critical: 304.1 K) |
| `Tmax = 450` | 450 K | Upper temperature bound |
| `NP = 40` | — | 40 pressure nodes (coarse; use ≥ 200 for production) |
| `NH = 40` | — | 40 enthalpy nodes |

::: warning Small grid
The test case uses `NP = NH = 40` for speed. For production simulations, use the default 200 × 200 or larger near the critical point.
:::

## Critical Point Context

$\text{CO}_2$ critical point: $T_c = 304.1\,\text{K}$, $p_c = 7.38\,\text{MPa}$.

The chosen range $[8\,\text{MPa}, 15\,\text{MPa}] \times [320\,\text{K}, 450\,\text{K}]$ covers the supercritical regime used in transcritical injection studies.

## Running

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/RF-co2
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/co2_rf.bin
```

The table contains $\rho$, $T$, $c$ (speed of sound), $\mu$, $\lambda$ sampled on the $(p, h)$ grid.
