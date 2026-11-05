# Several Conditions on One Face

**Tool:** BCB · **Case:** `test/BCB/IG-multipatch-2D` · **Run time:** about a second

An injection plate: one block face carries two injection rings and the wall around them. A **multipatch** splits the
face into ranges of coordinates and gives each range its own BC.

## What You'll Learn

- How a face is split into patches by coordinate ranges
- How to choose the coordinates of the ranges (`direction`)
- How to check which cells each patch took

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | Two 3-D blocks, the plate at face 1 of block 1 |
| `phase.txt` | An ideal gas (written by hand for the test) |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = plate
face2 = connection
face3 = symmetry
face4 = symmetry
face5 = symmetry
face6 = symmetry

[BCB-Block2]
face1 = connection
face2 = extrapolation
face3 = symmetry
face4 = symmetry
face5 = symmetry
face6 = symmetry

[plate]
direction = rt
range1 = 0.0 1.5d-3 -30.0 30.0
patch1 = inj1
range2 = 1.5d-3 9.5d-3 -30.0 30.0
patch2 = adiabatic
range3 = 9.5d-3 12.5d-3 -30.0 -6.0
patch3 = adiabatic
range4 = 9.5d-3 12.5d-3 -6.0 6.0
patch4 = inj2
range5 = 9.5d-3 12.5d-3 6.0 30.0
patch5 = adiabatic
range6 = 12.5d-3 50.0d-3 -30.0 30.0
patch6 = adiabatic

[adiabatic]
type = wall
q = 0.0

[inj1]
type = inlet
g = 4000.
T = 300.
nuTilde = 1d-6

[inj2]
type = inlet
g = 800.
T = 300.
beta = 0.1745
nuTilde = 1d-6
```

### Key Points

| Key | Meaning |
|-----|---------|
| `face1 = plate` | The face takes the section `[plate]`, which has no `type`: its keys are patches |
| `direction = rt` | The ranges are given in `r` (distance from the x axis, m) and `t` (angle about it, degrees) |
| `range<n> = r1 r2 t1 t2` | The cells whose centre lies in the range… |
| `patch<n>` | …take the BC of this name |
| `nuTilde` | The Spalart–Allmaras variable of the gas that enters |
| `beta` | A flow direction angle, in radians: `inj2` injects at 10° (0.1745 rad) from the normal |

Here the plate holds a central jet (`inj1`, r < 1.5 mm), a wall, and a second injector `inj2` on 12° of the ring
between 9.5 and 12.5 mm. A cell takes the first patch whose range holds its centre.

!!! warning "Cover the whole face"
    A cell that no range holds would be written `0`, the code of a face with no BC, so BCB stops. Remove `range6` and
    `patch6` and run again:
    `[ERROR] block 1 face 1 ([plate]): 300 of its 960 cells lie in none of the ranges of its patches and would be
    written 0 (no BC)`, followed by the first of them. Nothing is written.

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-multipatch && cd ~/atlas-tutorials/bcb-multipatch
cp $ATLASDIR/test/BCB/IG-multipatch-2D/{input.ini,mesh.tec,phase.txt} .
ATLAS BCB
```

## What It Writes

`fromATLAStoSolver/bc.txt`: on face 1 of block 1, 216 inlet cells (`404`: 180 of `inj1`, 36 of `inj2`) and 744 wall cells
(`301`); the other faces as declared (`101` between the blocks, `400` extrapolation at the exit, `300` symmetry). The
values of an `inj1` cell and of an `inj2` cell:

```text
  3.0000000000000000E+02,  4.0000000000000000E+03,         normal,         normal,  1.0000000000000000E+00,  1.0000000000000000E+00,  9.9999999999999995E-07,
  3.0000000000000000E+02,  8.0000000000000000E+02,         normal,  1.7449999999999999E-01,  1.0000000000000000E+00,  1.0000000000000000E+00,  9.9999999999999995E-07,
```

`T`, `g`, then the two angles: `inj2` has `beta` = 0.1745 where `inj1` has `normal`. The record ends with the mass
fraction of the one species and `nuTilde`.

To see the patches, open the case in the [GUI](../../user-guide/bcb/gui.md) (`ATLAS GUI`): the Boundaries stage colours
every cell of the face by the BC it took.

## Try Next

- Split a face by cell index instead of coordinates: the case `test/BCB/IG-multipatch-index`.
- Read the patches from a file: `test/BCB/IG-multipatch-file`.
- [BC Setup](../../user-guide/bcb/bc-setup.md) lists the `direction` letters: `x`, `y`, `z`, `r`, `t`, the cell indices
  `i`, `j`, `k`, and their pairs.

---

Next: [Inlets From Reservoir Conditions](reservoir-inlets.md)
