# Area Tables for Q2D

**Tool:** STB · **Case:** `test/STB/area-any-order` · **Run time:** under a second

Q2D solves a 2-D (x, y) flow in a channel whose depth varies along it: it reads the cross-section area of every node
from a table that STB writes from a profile of the area.

## What You'll Learn

- How `<dir>-areavariation` gives the area profile of a block
- What the area table holds

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | A 2-D block of 5 × 4 nodes, x from 0 to 0.4 |
| `area.txt` | The area against x |
| `input.ini` | The area profile |

```ini
[STB-Block1]
x-areavariation = area.txt
```

`area.txt` gives the area at a few values of x, in any order (STB sorts them):

```text
0.4 4.0
0.0 1.0
0.3 2.5
0.1 2.0
```

`x-areavariation` reads the profile along x; `y-`, `r-` and `theta-areavariation` along the other directions. A block
with an area profile and no `qvol` is the usual Q2D case: STB then writes no source file.

## Run It

```bash
mkdir -p ~/atlas-tutorials/stb-area && cd ~/atlas-tutorials/stb-area
cp $ATLASDIR/test/STB/area-any-order/{input.ini,mesh.tec,area.txt} .
ATLAS STB
```

STB prints `- No volumetric source terms configured: skipping qvol output files`: this case has no source.

## What It Writes

`fromATLAStoSolver/block1_area.dat`, the area at every node of block 1, row after row of the mesh: at x = 0, 0.1, 0.2, 0.3 and
0.4 the values 1.0, 2.0, 2.25, 2.5 and 4.0, linear between the points of the profile (2.25 halfway between 0.1 and 0.3).
A node outside the range of the profile takes the value at its end, and STB warns:
`[WARNING] area law block <b>: <n> nodes lie outside the profile interval [x1, x2]`.

---

Next: [A Case for MPI](../mdb/index.md)
