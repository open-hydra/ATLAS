# Condensed-Dispersed Phase

**Tool:** GPB · **Case:** `test/GPB/CP-Tvar-dispersed` · **Run time:** a few seconds

This tutorial shows how to define a condensed-dispersed (liquid droplets / particles) phase with temperature-variable properties from the NASA9 database.

## What You'll Learn

- `type = condensed-dispersed` configuration
- Using the NASA9 thermodynamic database
- Specifying particle density

## The Case

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L)
thermo   = NASA9
rho      = 2500
```

### Key Points

| Key | Meaning |
|-----|---------|
| `type = condensed-dispersed` | Dispersed liquid/solid particles in a carrier gas |
| `material = AL2O3(L)` | Material name; `(L)` = liquid aluminium oxide |
| `thermo = NASA9` | Temperature-dependent $c_p(T)$ from the NASA9 database |
| `rho = 2500` | Particle density (kg m⁻³) |

### NASA9 Database

GPB looks up the NASA9 polynomial coefficients for the given `material` name. The database, `nasa9.yaml`, is shipped with ATLAS under `database/thermo/`. `thermo = NASA7` and `thermo = Burcat` work the same way with their own files (see [Thermodynamics Databases](../../databases/thermodynamics/index.md)).

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
(`Enthalpy_abs`) of `AL2O3(L)` from the NASA9 database.
