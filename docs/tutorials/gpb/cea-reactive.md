# CEA Reactive Phase

**Tool:** GPB · **Case:** `test/GPB/IG-ceafile-reactive-OG` · **Run time:** a few seconds

This tutorial shows how to use a pre-run CEA output file as the source for equilibrium composition, combined with a Cantera reaction mechanism for transport properties.

## What You'll Learn

- `CEA-file` / `CEA-section` keys
- Combining CEA composition with `transport = CEA`
- The `inerts-mixing` flag

## The Case

```ini
[GPB-Phase1]
type          = ideal-gas
CEA-file      = CEA.inp
transport     = CEA
reactions     = troyes
inerts-mixing = true
```

### Key Points

| Key | Meaning |
|-----|---------|
| `CEA-file = CEA.inp` | Path to the CEA input/output file |
| `transport = CEA` | CEA transport polynomial fits from `$ATLASDIR/database/transport/CEApolynomials.yaml` |
| `reactions = troyes` | Cantera mechanism to resolve species thermodynamics |
| `inerts-mixing = true` | Apply mixture rules when combining inert and reactive species |

### CEA File

The `CEA.inp` file must be located in the same directory as `input.ini` (or an absolute path must be given). GPB reads the equilibrium composition from the section matching `CEA-section` (if specified; otherwise the first section is used).

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-cea && cd ~/atlas-tutorials/gpb-cea
cp $ATLASDIR/test/GPB/IG-ceafile-reactive-OG/{input.ini,CEA.inp} .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/phase.txt
fromATLAStoSolver/thermo.dat
fromATLAStoSolver/transport.dat
fromATLAStoSolver/composition.txt
fromATLAStoSolver/chemistry-info.txt
fromATLAStoSolver/chemistry-Arrhenius.dat
```
