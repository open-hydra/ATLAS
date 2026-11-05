# Overset Blocks (Chimera)

**Tool:** BCB · **Case:** `test/BCB/IG-chimera` · **Run time:** a few seconds

Two blocks that overlap instead of sharing a face. On a `chimera` face the solver takes the values of the ghost cells
from the cells of the other block that cover them; BCB finds those cells and the share of each.

## What You'll Learn

- How to turn the chimera search on (`BC-chimera`) and mark the overset faces
- How to read a chimera record: the donor cells of each ghost layer and their weights
- Where BCB reports what it could not cover

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | Two blocks of an axisymmetric mesh, 50 × 30 and 25 × 70 cells, that overlap |
| `phase.txt` | An ideal gas (written by hand for the test) |
| `input.ini` | The boundary conditions |

```ini
[ATLAS-Parameters]
BC-chimera = true

[BCB-Block1]
face1 = symmetry
face2 = symmetry
face3 = symmetry
face4 = chimera

[BCB-Block2]
face1 = symmetry
face2 = symmetry
face3 = chimera
face4 = symmetry
```

`BC-chimera = true` in `[ATLAS-Parameters]` runs the overset search. Without it the `chimera` faces would keep `100`,
the code of a face before its search, which no solver reads, so BCB stops:
`[ERROR] block 1 face 4 ([chimera]) is declared chimera, but BC-chimera = false: 50 of its cells match no cell of
another block and would be written 100, a code no solver reads`. Set it whenever a face is `chimera`.

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-chimera && cd ~/atlas-tutorials/bcb-chimera
cp $ATLASDIR/test/BCB/IG-chimera/{input.ini,mesh.tec,phase.txt} .
ATLAS BCB
```

## What It Writes

`fromATLAStoSolver/bc.txt`, with 50 `102` records on face 4 of block 1 and 25 on face 3 of block 2. A record covers the two layers
of ghost cells behind the face:

```text
       1       1      30       1       4     102
       1       2
       2       1       1       1  1.0000000000000000E+00
       2       1       1       1  4.5143331002613452E-01
       2       1       2       1  5.4856668997386537E-01
```

The second line counts the donors of each layer: one for the first ghost cell, two for the second. Then one line per
donor: its block, its cell `i j k`, and its weight. The weights of a layer sum to 1. Faces 5 and 6 of this
axisymmetric mesh are written `200` by BCB itself.

BCB also writes `chimera.log` in the case directory, the trace of the search: a receiver it could not close shows
there. A layer with no donor at all (a count of `0`) makes the BC file unusable: the other block must cover both
layers of ghost cells.

## Try Next

- [Block Connectivity](../../user-guide/bcb/connectivity.md#chimera) explains the search and its limits (the weights
  are normalised over the donors found, so a partly covered ghost cell looks fully covered).
- `BC-force-chimera = true` turns into chimera only the cells of a face that see the other block: the case
  `test/BCB/IG-force-chimera`.

---

Next: [Particles at the Boundaries](particles.md)
