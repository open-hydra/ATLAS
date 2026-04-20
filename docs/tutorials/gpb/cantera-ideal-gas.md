# Tutorial: Cantera Ideal-Gas

**Source case:** `test/GPB/IG-reactive`

This tutorial shows how to build a reactive gas phase using a Cantera mechanism file for species thermodynamics and transport properties.

## What You'll Learn

- How to reference a Cantera mechanism with `reactions`
- How to add inert species to a reactive mixture
- How `thermo = NASA9` and `transport = cantera` interact

## The Input File

```ini
[GPB-Phase1]
reactions = JLR-nasuti
species   = N2
thermo    = NASA9
transport = cantera
Tmax      = 5000
```

### Key Points

| Key | Meaning |
|-----|---------|
| `reactions = JLR-nasuti` | Cantera mechanism name (must be resolvable by Cantera) |
| `species = N2` | Add $\text{N}_2$ as an inert species (not in the mechanism) |
| `thermo = NASA9` | Use NASA 9-coefficient polynomial fits from Cantera |
| `transport = cantera` | Cantera mixture-averaged transport for $\mu$ and $\lambda$ |
| `Tmax = 5000` | Extend the property table to 5000 K |

::: info
When `type` is not specified, GPB defaults to `type = ideal-gas`.
:::

## Running

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/IG-reactive
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/<mechanism-name>.bin
```
