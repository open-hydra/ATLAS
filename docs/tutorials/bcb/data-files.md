# Boundary Data From Tables

**Tool:** BCB · **Cases:** `test/BCB/IG-xtheta-variable-T`, `test/BCB/IG-inflow-p0time` · **Run time:** about a second

Boundary values that change from cell to cell or in time. A wall temperature that varies along the axis and around it
is read by BCB from a table and written cell by cell; a total pressure that rises in time is left to the solver, which
reads its table during the run.

## What You'll Learn

- How a `<key>-file` table with a `direction` gives a value to every cell of a face
- The layout of a 2-D table (`xt`: rows in x, columns in θ)
- How a time table (`p0-time-file`) is passed to the solver

## Part 1: A Wall Temperature in x and θ

| File | What it is |
|---|---|
| `mesh.tec` | A 3-D nozzle of one block (the mesh of the [Quick Start](../../getting-started/quick-start.md)) |
| `phase.txt` | One species, `dummy` (written by hand for the test) |
| `Twall.dat` | The wall temperature against x (rows) and θ (columns) |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = inflow
face2 = extrapolation
face3 = symmetry
face4 = isoth
face5 = symmetry
face6 = symmetry

[inflow]
type = inlet
p0 = 3.0e+5
T0 = 500.0

[isoth]
type = wall
direction = xt
T-file = Twall.dat
```

`Twall.dat`, a 2-D table: the first row gives the θ of the columns (degrees), the first column the x of the rows (m):

```text
        -10   0.0   0.01   10
-1.0   300.0  300.0 2000.0 2000.0
0.0    250.0  250.0 2000.0 2000.0
1.0    500.0  500.0 5000.0  5000.0
10.0   700.0  700.0 5000.0  5000.0
```

`direction = xt` says which coordinates of the cell centre are looked up, and the value between the points of the
table is interpolated (bilinear in x and θ).

```bash
mkdir -p ~/atlas-tutorials/bcb-tables && cd ~/atlas-tutorials/bcb-tables
cp $ATLASDIR/test/BCB/IG-xtheta-variable-T/{input.ini,mesh.tec,phase.txt,Twall.dat} .
ATLAS BCB
```

In `fromATLAStoSolver/bc.txt` the 2000 cells of face 4 are isothermal walls (`302`), each with its own temperature, from 250 K to
5000 K: the first one reads

```text
  2.5531476281079051E+02,  0.0000000000000000E+00,  0.0000000000000000E+00,
```

`T`, then the roughness and the emissivity, 0 when not given. The same `direction` and `<key>-file` pair works for the
other values of a face (`q-file`, `g-file`, `ks-file`, ... listed in [BC Setup](../../user-guide/bcb/bc-setup.md)).

## Part 2: A Total Pressure in Time

```ini
[BCB-Block1]
face1 = inflow
face2 = extrapolation
face3 = symmetry
face4 = symmetry

[inflow]
type = inlet
p0-time-file = p0time.txt
T0 = 300.0
```

`p0time.txt` gives the total pressure (Pa) against the time (s): 3 bar at the start, 6 bar at 1 s, 9 bar at 5 s.

```text
0.0 3.0e+5
1.0 6.0e+5
5.0 9.0e+5
```

```bash
mkdir -p ~/atlas-tutorials/bcb-time && cd ~/atlas-tutorials/bcb-time
cp $ATLASDIR/test/BCB/IG-inflow-p0time/{input.ini,mesh.tec,phase.txt,p0time.txt} .
ATLAS BCB
```

The inlet becomes a `402`, and its record names the file instead of a pressure:

```text
  3.0000000000000000E+02, p0time.txt,         normal,         normal,  1.0000000000000000E+00,  1.0000000000000000E+00,
```

The solver opens `p0time.txt` itself, from the directory it runs in: keep the table in the case directory, next to
`input.ini`. This mesh is 2-D: faces 5 and 6 are not named, and BCB writes them as `200` (axisymmetric) itself.

## Try Next

- Change `direction = xt` into `direction = x` with a 1-D table (two columns, x and T): the temperature then varies
  along x only.
- A time table for the whole inlet state: `time-file`, the `410` inlet of [BC Types](../../user-guide/bcb/bc-types.md#inlet).

---

Next: [Connections and Periodic Faces](connections.md)
