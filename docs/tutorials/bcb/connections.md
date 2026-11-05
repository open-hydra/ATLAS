# Connections and Periodic Faces

**Tool:** BCB · **Case:** `test/BCB/IG-periodic` · **Run time:** under a second

Two kinds of faces whose values come from other cells of the mesh: the faces where two blocks meet, which BCB finds by
itself, and a pair of periodic faces, which you declare.

## What You'll Learn

- What `connection` does, and how BCB connects a face that is only partly in front of another block
- How to declare a periodic pair (`type = periodic`, `faces`)
- How to read a connection record: the cell on the other side and the orientation

## Connections

A face named `connection` is in front of another block: BCB looks for the cells facing each of its cells and writes a
`101` record for each. You saw them in [Inlets, Outlets and Walls](walls-and-inlets.md); a record from that case:

```text
       1      25       1       2     101
       3       1       1       1       1       0       0       1
```

Cell (25, 1) of face 2 of block 1 faces cell (1, 1) of face 1 of block 3; the last four integers are the orientation of
the two faces. A face declared as another BC (a wall, an inlet) is connected too where it meets another block, cell by
cell: there, face 1 of block 3 is the wall `adia` on 80 cells and a connection on the 50 that face blocks 1 and 2
(`BC-force-connect`, on by default; [Block Connectivity](../../user-guide/bcb/connectivity.md)).

## A Periodic Pair

| File | What it is |
|---|---|
| `mesh.tec` | One block of 50 × 20 cells, one cell thick: a 2-D planar mesh |
| `phase.txt` | An ideal gas (written by hand for the test) |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = periodic
face2 = periodic
face3 = symmetry
face4 = symmetry

[periodic]
type = periodic
faces = 1 2
```

`faces = 1 2` pairs face 1 with face 2 of the same block (add `blocks = 1 4` for a pair across two blocks). Faces 5 and
6, the planes of the 2-D mesh, are not named: BCB writes them as `0` (null) itself.

```bash
mkdir -p ~/atlas-tutorials/bcb-periodic && cd ~/atlas-tutorials/bcb-periodic
cp $ATLASDIR/test/BCB/IG-periodic/{input.ini,mesh.tec,phase.txt} .
ATLAS BCB
```

`fromATLAStoSolver/bc.txt` holds 20 `201` records on face 1 and 20 on face 2, each pointing to the cell on the other side:

```text
       1       1       1       1       1     201
       1      50       1       1       2       1       0       0       1
```

Cell (1, 1, 1) of face 1 takes its neighbour from cell (50, 1, 1) of face 2 of the same block.

!!! warning "`faces` is required"
    A `periodic` section without `faces` builds no pair, and BCB says nothing: the two faces keep whatever BC they would
    have otherwise ([BC Types](../../user-guide/bcb/bc-types.md#periodic)).

## Try Next

- Turn `BC-force-connect` off in `[ATLAS-Parameters]` (`BC-force-connect = false`) and run the case of
  [Inlets, Outlets and Walls](walls-and-inlets.md) again: face 1 of block 3 becomes a wall on all of its 130 cells.

---

Next: [Overset Blocks (Chimera)](chimera.md)
