# Tutorial: Solid Phase

**Source case:** `test/GPB/SP-Tvar`

This tutorial shows how to define a solid material phase using the ATLAS internal solid-phase database.

## What You'll Learn

- `type = solid` configuration
- Reading properties from the `SP-database`

## The Input File

```ini
[GPB-Phase1]
type     = solid
name     = solido
material = UC
thermo   = SP-database
```

### Key Points

| Key | Meaning |
|-----|---------|
| `type = solid` | Solid material phase |
| `name = solido` | Output file base name |
| `material = UC` | Uranium carbide from the ATLAS solid-phase database |
| `thermo = SP-database` | Read $c_p(T)$, $\rho(T)$, $k(T)$ from the SP database |

### SP Database

The ATLAS solid-phase database is located in `database/thermo/` and includes a curated set of solid propellant and structural materials (ceramics, metals, carbides).

## Running

```bash
export ATLASDIR=/path/to/ATLAS
cd test/GPB/SP-Tvar
python -m GPB --input-file input.ini
```

## Expected Output

```
fromATLAStoSolver/solido.bin
```
