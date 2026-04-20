# Tutorial: Fixed-Gas Mixture

**Source case:** `test/GPB/IG-fixgas`

This tutorial shows how to define an ideal-gas phase entirely from explicit physical constants — no species database required. Use this approach when you have experimental or reference values for viscosity and thermal conductivity.

## What You'll Learn

- How to specify a multi-species ideal-gas phase using scalar property lists
- Which properties are required and which are derived automatically

## The Input File

```ini
[GPB-Phase1]
name    = gasmix
type    = ideal-gas
species = N2f Hef
gamma   = 1.4  1.66
mw      = 28.0 4.0
mil     = 1e-5 1.3e-5
kl      = 0.25 0.30
```

### Key Points

| Key | Meaning |
|-----|---------|
| `species = N2f Hef` | Two species: nitrogen-frozen (`N2f`) and helium (`Hef`) — arbitrary names |
| `gamma = 1.4 1.66` | Specific-heat ratios; one value per species |
| `mw = 28.0 4.0` | Molar masses (g mol⁻¹) |
| `mil = 1e-5 1.3e-5` | Dynamic viscosities (Pa s) — constant (calorically perfect) |
| `kl = 0.25 0.30` | Thermal conductivities (W m⁻¹ K⁻¹) — constant |

GPB derives $c_p = \gamma R / (\gamma - 1)$, $c_v = c_p / \gamma$, and $R = R_u / M_w$ automatically.

::: tip Over-specified sets
You can provide more keys than strictly needed (e.g. both `gamma` and `cp`). GPB will check consistency and raise an error if the set is contradictory.
:::

## Running

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/IG-fixgas
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/gasmix.bin
```

The file contains constant $c_p$, $\mu$, $\lambda$ arrays on the requested $T$ grid (default 1–5000 K).
