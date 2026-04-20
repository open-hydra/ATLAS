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

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/CP-Tvar-dispersed
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/AL2O3(L).bin     # (or the name key value if set)
```
