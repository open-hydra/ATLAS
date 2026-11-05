# Zones in a Block

**Tool:** ICB · **Case:** the mesh and phase of `test/ICB/IG-multizone` · **Run time:** under a second

A shock tube: one block, a driver section at 10 bar and 600 K and a driven section at 1 bar and 300 K. **Zones** split
a block by coordinate ranges and give each range its own state.

## What You'll Learn

- How `direction`, `zone<n>` and `range<n>` split a block
- How a zone's state is written in a section of its own

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | One block of 100 cells along x, from 0 to 0.01 m |
| `gas-phase.txt`, `gas-thermo.dat` | The phase `gas`: N2 and its table |
| `input.ini` | The initial state, in `test/tutorials/icb-zones/` |

```ini
--8<-- "test/tutorials/icb-zones/input.ini"
```

A cell takes the zone whose range holds its centre, along `direction`: `x`, `y`, `z`, `r`, `t`, the cell indices `i`,
`j`, `k`, or several letters, each with its own pair of values in the range (`direction = xy`, `range1 = x1 x2 y1 y2`).
Every cell of the block must be in a zone: ICB stops on a cell that no zone writes, and names the block, the phase and
the count.

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-zones && cd ~/atlas-tutorials/icb-zones
cp $ATLASDIR/test/ICB/IG-multizone/{mesh.tec,gas-phase.txt,gas-thermo.dat} .
cp $ATLASDIR/test/tutorials/icb-zones/input.ini .
ATLAS ICB
```

## What It Writes

`fromATLAStoSolver/gas-ic.tec`, named after the phase. The first 50 cells hold the driver, ρ = 5.6155 kg/m³; the other 50 the
driven gas, ρ = 1.1231 kg/m³. All are at rest.

## Try Next

- Give a zone a speed (`u = 200.0`) or another kind of state: a zone may be `type = variable` (a profile, see
  [Profiles From Tables](profiles.md)) or `type = interpolation` (see [Restart From Another Solution](restart.md)).
- Separate the two values of a range with a TAB: ICB stops and names the separator (the test
  `IG-range-separator-refused`).

---

Next: [Nozzle Flow](nozzle.md)
