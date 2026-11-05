# Cantera Equilibrium

**Tool:** GPB · **Case:** `test/GPB/IG-ct-equilibrium` · **Run time:** a few seconds

This tutorial shows how to compute the equilibrium composition of a fuel–oxidizer mixture with Cantera and use it as the base for the property tables.

## What You'll Learn

- The `eq-*` key family for Cantera equilibrium
- How to specify pressure with units
- Oxidizer-to-fuel (O/F) ratio

## The Case

```ini
[GPB-Phase1]
name         = gasmix
type         = ideal-gas
eq-of        = 6
eq-pressure  = 3000 psi
eq-fuel      = H2
eq-fuel-T    = 300.0
eq-oxidizer  = O2(L)
```

### Key Points

| Key | Meaning |
|-----|---------|
| `eq-of = 6` | Oxidizer-to-fuel mass ratio |
| `eq-pressure = 3000 psi` | Equilibrium pressure; units are parsed automatically |
| `eq-fuel = H2` | Fuel species (Cantera name) |
| `eq-fuel-T = 300.0` | Fuel inlet temperature (K) |
| `eq-oxidizer = O2(L)` | Oxidizer species; `(L)` denotes liquid oxygen |

Cantera computes the adiabatic flame composition at the given conditions, and GPB uses the resulting mixture as the phase composition for table generation.

## Supported Pressure Units

GPB delegates unit parsing to Cantera. Supported unit strings include `Pa`, `atm`, `bar`, `psi`, `Torr`.

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-equilibrium && cd ~/atlas-tutorials/gpb-equilibrium
cp $ATLASDIR/test/GPB/IG-ct-equilibrium/input.ini .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/gasmix-phase.txt
fromATLAStoSolver/gasmix-composition.txt
fromATLAStoSolver/gasmix-thermo.dat
```
