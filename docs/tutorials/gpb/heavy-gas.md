# Heavy-Gas Mixture

**Tool:** GPB · **Case:** `test/GPB/IG-mixture-HG` · **Run time:** a few seconds

This tutorial shows how to define a multi-component mixture that includes a condensed (liquid/solid) species using the heavy-gas model. This is typical of solid rocket motor (SRM) propellant-loaded flows.

## What You'll Learn

- `type = heavy-gas` and what it does
- Mixing condensed species into a gas-phase mixture
- The heavy-gas pressure scaling factor

## The Case

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

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-heavy-gas && cd ~/atlas-tutorials/gpb-heavy-gas
cp $ATLASDIR/test/GPB/IG-mixture-HG/input.ini .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/phase.txt
fromATLAStoSolver/thermo.dat
fromATLAStoSolver/transport.dat
fromATLAStoSolver/composition.txt
```
