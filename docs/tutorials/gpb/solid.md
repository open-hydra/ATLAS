# Solid Phase

**Tool:** GPB · **Case:** `test/GPB/SP-Tvar` · **Run time:** a few seconds

This tutorial shows how to define a solid material phase using the ATLAS internal solid-phase database.

## What You'll Learn

- `type = solid` configuration
- Reading properties from the `SP-database`

## The Case

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
