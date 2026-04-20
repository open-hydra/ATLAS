# Tutorial: Heavy-Gas Mixture

**Source case:** `test/GPB/IG-mixture-HG`

This tutorial shows how to define a multi-component mixture that includes a condensed (liquid/solid) species using the heavy-gas model. This is typical of solid rocket motor (SRM) propellant-loaded flows.

## What You'll Learn

- `type = heavy-gas` and what it does
- Mixing condensed species into a gas-phase mixture
- The heavy-gas pressure scaling factor

## The Input File

```ini
[GPB-Phase1]
type      = heavy-gas
mixture   = {N2: 55.4} {O2: 23.3} {Ar: 1.3} {AL2O3(L): 20.0}
transport = CEA
```

### Key Points

| Key | Meaning |
|-----|---------|
| `type = heavy-gas` | Enables the heavy-gas pressure scaling ($\times\, 10^5$) |
| `mixture` | Composition by mass fraction (%); condensed species `AL2O3(L)` included |
| `transport = CEA` | CEA polynomial fits for $\mu$ and $\lambda$ |

### Heavy-Gas Scaling

The heavy-gas model represents propellant-loaded flows where the mixture contains both gaseous and condensed species. GPB multiplies the pressure by `HG_FACTOR = 1e5` internally when computing thermodynamic properties. The output file is named `<name>-HG.bin`.

## Running

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/IG-mixture-HG
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/<name>-HG.bin
```
