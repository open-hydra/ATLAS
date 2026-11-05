# Nozzle Flow

**Tool:** ICB · **Case:** the mesh and phase of `test/ICB/IG-nozzle2D` · **Run time:** under a second

A start for a nozzle run: the isentropic quasi-1-D flow of a De Laval nozzle, cell row by cell row, from the reservoir
state. A solver started from it reaches the steady flow in far fewer steps than from rest.

## What You'll Learn

- How `type = nozzle` builds the flow from the area of the block's cross-sections
- What the block must be for the law to apply
- How to keep a plenum at rest upstream (`nozzle-threshold`)

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | A 2-D nozzle: one block of 120 × 40 cells along x, with a throat |
| `phase.txt`, `thermo.dat` | N2 and its table |
| `input.ini` | The initial state, in `test/tutorials/icb-nozzle/` |

```ini
--8<-- "test/tutorials/icb-nozzle/input.ini"
```

`p0` and `T0` are the reservoir state (Pa, K). Every row of cells `i` is a cross-section: ICB measures its area A from
the distances of its two walls to the x axis, takes the row of smallest area as the throat A*, and gives every row the
quasi-1-D isentropic state of its ratio A/A*: subsonic up to the throat, sonic there, supersonic after it. The state
follows from `p0`, `T0` and the γ of the gas at `T0`, read from `thermo.dat`; the velocity runs along the `i` lines of
the mesh.

The block must be a nozzle: a duct about the x axis, meshed along it (`i` from the inlet to the exit, `j` from the axis
or the inner wall to the outer wall), whose section has a throat. On any other block ICB stops before writing anything
([Nozzle Initialization](../../user-guide/icb/ic-setup.md#nozzle-initialization-ig)).

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-nozzle && cd ~/atlas-tutorials/icb-nozzle
cp $ATLASDIR/test/ICB/IG-nozzle2D/{mesh.tec,phase.txt,thermo.dat} .
cp $ATLASDIR/test/tutorials/icb-nozzle/input.ini .
ATLAS ICB
```

## What It Writes

`fromATLAStoSolver/ic.tec`. Along the nozzle the Mach number rises from 0.14 at the inlet to 4.35 at the exit, the pressure falls
from 10.2 bar to 0.04 bar and the temperature from 554 K to 118 K. The GUI draws the law with its A/A* plot and the
field ICB wrote: the image of the [GUI page](../../user-guide/gui.md) is this kind of case, in 3-D.

## Try Next

- `nozzle-threshold = 0.0` with `nozzle-direction = dx`: the rows whose centre is below x = 0 are a plenum at rest at
  `p0` and `T0` ([IC Strategies](../../user-guide/icb/ic-strategies.md)).
- The same law in 3-D: the [Quick Start](../../getting-started/quick-start.md).

---

Next: [Profiles From Tables](profiles.md)
