# Tutorial: Condensed-Dispersed Phase

**Source case:** `test/GPB/CP-Tvar-dispersed`

This tutorial shows how to define a condensed-dispersed (liquid droplets / particles) phase with temperature-variable properties from the Burcat database.

## What You'll Learn

- `type = condensed-dispersed` configuration
- Using the Burcat thermodynamic database
- Specifying particle density

## The Input File

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

## Running

Run the case on a copy: GPB writes `fromATLAStoSolver/` in the directory it runs in, which would change the test
deck of the repository.

```bash
cp -r $ATLASDIR/test/GPB/CP-Tvar-dispersed .
cd CP-Tvar-dispersed
ATLAS GPB
```

## Expected Output

```
fromATLAStoSolver/phase.txt
fromATLAStoSolver/properties.dat
```

`phase.txt` starts with `condensed-dispersed`; `properties.dat` holds cp, density and the absolute enthalpy
(`Enthalpy_abs`) of `AL2O3(L)` from the Burcat database.
