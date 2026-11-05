# Cantera Ideal-Gas

**Tool:** GPB · **Case:** `test/GPB/IG-reactive` · **Run time:** a few seconds

This tutorial shows how to build a reactive gas phase using a Cantera mechanism file for species thermodynamics and transport properties.

## What You'll Learn

- How to reference a Cantera mechanism with `reactions`
- How to add inert species to a reactive mixture
- How `thermo = NASA9` and `transport = cantera` interact

## The Case

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

!!! info
    When `type` is not specified, GPB defaults to `type = ideal-gas`.

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-cantera && cd ~/atlas-tutorials/gpb-cantera
cp $ATLASDIR/test/GPB/IG-reactive/input.ini .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/phase.txt
fromATLAStoSolver/thermo.dat
fromATLAStoSolver/transport.dat
fromATLAStoSolver/diffusion.dat
fromATLAStoSolver/composition.txt
fromATLAStoSolver/chemistry-info.txt
fromATLAStoSolver/chemistry-Arrhenius.dat
```

The section has no `name`, so the files have no prefix. The mechanism's reactions give `chemistry-info.txt` and
`chemistry-Arrhenius.dat`, Cantera's transport `diffusion.dat` (binary diffusion of every pair).
