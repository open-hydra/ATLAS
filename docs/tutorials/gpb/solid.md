# Solid Phase

**Tool:** GPB · **Case:** `test/GPB/SP-Tvar` · **Run time:** a few seconds

This tutorial shows how to define a solid material phase with the properties of a material coded in `custom.py`.

## What You'll Learn

- `type = solid` configuration
- Reading properties from `custom.py` with `thermo = custom`

## The Case

```ini
[GPB-Phase1]
type     = solid
name     = solido
material = UC
thermo   = custom
```

### Key Points

| Key | Meaning |
|-----|---------|
| `type = solid` | Solid material phase |
| `name = solido` | Output file base name |
| `material = UC` | Uranium carbide, a material of `database/thermo/custom.py` |
| `thermo = custom` | Read $c_p(T)$, $\rho(T)$, $k(T)$ from the `CondensedMaterial` named `UC` |

### Custom Materials

`database/thermo/custom.py` holds a set of solid materials (ceramics, metals, carbides). Each one is a `CondensedMaterial`
given its properties as numbers or functions of the temperature; you add your own the same way, in that file or in a `custom.py`
next to your `input.ini`. See [Custom Substances](../../databases/thermodynamics/custom.md).

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-solid && cd ~/atlas-tutorials/gpb-solid
cp $ATLASDIR/test/GPB/SP-Tvar/input.ini .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/solido-phase.txt
fromATLAStoSolver/solido-properties.dat
```
