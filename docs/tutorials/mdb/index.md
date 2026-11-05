# A Case for MPI

**Tools:** GPB, BCB, ICB, MDB · **Case:** the mesh of `test/MDB/split-solution` · **Run time:** a few seconds

A whole case in one command: the gas, the boundary conditions and the initial field of a duct, then the same case cut
into four blocks of equal size for a run of MOSE on four MPI ranks.

## What You'll Learn

- How one INI file drives four tools, and how they hand their files to each other in `fromATLAStoSolver/`
- How MDB cuts the blocks and rewrites the boundary conditions of the cut faces
- What MDB predicts of the balance between the ranks

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | A duct: one block of 32 × 12 × 8 cells |
| `input.ini` | Every tool's sections, in `test/tutorials/mdb-split/` |

```ini
--8<-- "test/tutorials/mdb-split/input.ini"
```

| Section | Tool | What it builds |
|---|---|---|
| `[GPB-Phase1]` | GPB | the phase `gas`: air as one species of constant γ ([Fixed-Gas Mixture](../gpb/fixed-gas.md)) |
| `[BCB-Block1]` and the BC sections | BCB | an inlet from a reservoir, an outlet, an adiabatic wall ([Inlets, Outlets and Walls](../bcb/walls-and-inlets.md)) |
| `[ICB-Block1]` | ICB | a uniform state moving at 100 m/s ([A Uniform State](../icb/uniform.md)) |
| `[MDB-Parameters]` | MDB | the decomposition for 4 ranks of the files of the phase `gas-` |

`grid` names the file MDB cuts: the initial field ICB writes, which carries the mesh and the state, so that the split
case starts from the same field. Without it MDB cuts `mesh.tec`. The other keys keep MDB's files in
`fromATLAStoSolver/` with those of the other tools: by default MDB reads and writes where a solver run keeps its input
(`INPUT/`, `INPUT-split/`), for a run of MDB in the solver directory ([MDB](../../user-guide/mdb/index.md)).

## Run It

```bash
mkdir -p ~/atlas-tutorials/mdb && cd ~/atlas-tutorials/mdb
cp $ATLASDIR/test/MDB/split-solution/mesh.tec .
cp $ATLASDIR/test/tutorials/mdb-split/input.ini .
ATLAS GPB BCB ICB MDB
```

The tools run in turn; each reads in `fromATLAStoSolver/` what the previous ones wrote there. MDB ends with its
prediction:

```text
   Ideal load per rank            768.0
   Heaviest rank                  768
   Predicted MOSE balance         100.0% of ideal
   Ghost-cell overhead             37.5%
   ...
 Boundary conditions
   level 1: 2048 records (1472 inherited, 576 new cut-plane connections)
```

## What It Writes

| File | Tool | Content |
|---|---|---|
| `fromATLAStoSolver/gas-phase.txt`, `gas-thermo.dat`, `gas-composition.txt` | GPB | the phase |
| `fromATLAStoSolver/gas-bc.txt` | BCB | the boundary conditions of the whole block |
| `fromATLAStoSolver/gas-ic.tec` | ICB | the initial field of the whole block |
| `fromATLAStoSolver/gas-ic-split.tec` | MDB | the same field, on four blocks of 8 × 12 × 8 cells |
| `fromATLAStoSolver/INPUT-split/gas-bc.txt` | MDB | the boundary conditions of the four blocks: the cuts are new connections |
| `fromATLAStoSolver/decomposition.map` | MDB | which new block comes from which part of the old one, and its rank |

The map, in short:

```text
# new  parent   i0   i1    j0   j1    k0   k1      ni   nj   nk        cells  rank
     1     1     1     8       1    12       1     8         8   12    8          768     0
     2     1     9    16       1    12       1     8         8   12    8          768     1
     3     1    17    24       1    12       1     8         8   12    8          768     2
     4     1    25    32       1    12       1     8         8   12    8          768     3
```

MDB cut the block along i, its longest direction, into four pieces of 768 cells: one per rank, a perfect balance. The
cuts add 576 connection records, and the ghost cells of the new faces cost the 37.5 % that MDB reports as ghost-cell
overhead.

!!! note "Running MOSE on the split case"
    MOSE reads `INPUT/gas-ic.<ext>` and `INPUT/gas-bc.txt` in its run directory. To run it on the four blocks, give
    it the split files under these names, with the map (`<run>` is the run directory):

    ```bash
    cp fromATLAStoSolver/gas-ic-split.tec       <run>/INPUT/gas-ic.tec
    cp fromATLAStoSolver/INPUT-split/gas-bc.txt <run>/INPUT/gas-bc.txt
    cp fromATLAStoSolver/decomposition.map      <run>/INPUT/gas-decomposition.map   # [MOSE-IO] decomposition-map = decomposition.map
    ```

    Without `decomposition-map`, MOSE spreads the blocks over the ranks itself.

## Try Next

- `objective = halo` in `[MDB-Parameters]`: MDB searches the cut with the best balance for the fewest ghost cells
  ([MDB](../../user-guide/mdb/index.md)).
- `ATLAS MDB -- --sweep 4,7,12`: the prediction for several rank counts, nothing written.

---

Next: [Checking a Mechanism](../kant/index.md)
