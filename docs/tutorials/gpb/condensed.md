# Condensed-Dispersed Phase

**Tool:** GPB · **Case:** `test/GPB/CP-Tvar-dispersed` · **Run time:** a few seconds

This tutorial shows how to define a condensed-dispersed (liquid droplets / particles) phase with temperature-variable properties from the Burcat database.

## What You'll Learn

- `type = condensed-dispersed` configuration
- Using the Burcat thermodynamic database
- Specifying particle density

## The Case

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
```

### Key Points

| Key | Meaning |
|-----|---------|
| `type = condensed-dispersed` | Dispersed liquid/solid particles in a carrier gas |
| `material = AL2O3(L)` | Material name; `(L)` = liquid aluminium oxide |
| `thermo = Burcat` | Temperature-dependent $c_p(T)$ from the Burcat database |
| `rho = 2500` | Particle density (kg m⁻³) |

### Burcat Database

GPB looks up the Burcat polynomial coefficients for the given `material` name. The database is shipped with ATLAS under `database/thermo/`.

## Run It

In a folder of your own (the run writes `fromATLAStoSolver/` where it runs, so not in the test folder):

```bash
mkdir -p ~/atlas-tutorials/gpb-condensed && cd ~/atlas-tutorials/gpb-condensed
cp $ATLASDIR/test/GPB/CP-Tvar-dispersed/input.ini .
ATLAS GPB
```

## What It Writes

```
fromATLAStoSolver/phase.txt
fromATLAStoSolver/properties.dat
```

`phase.txt` starts with `condensed-dispersed`; `properties.dat` holds cp, density and the absolute enthalpy
(`Enthalpy_abs`) of `AL2O3(L)` from the Burcat database.
