# MDB Output Files

MDB writes its outputs to the paths configured in `[MDB-Parameters]`. No output directory is hard-coded; all paths default to sensible values but can be overridden. `--sweep` writes nothing: its table goes to standard output.

---

## Decomposed Grid

| `grid-out` setting | Default file name |
|--------------------|-------------------|
| Not set | `<input-grid>-split.<ext>` |
| Explicit path | As specified |

The output file is written in the same format as the input (Tecplot ASCII `.tec`, Tecplot binary `.szplt` or PLOT3D `.p3d`). If the input grid file also carries a solution field (restart data), the solution is partitioned block-by-block into the output file — no interpolation is performed and the field values are unchanged.

---

## Decomposed BC Files

MDB rewrites every multigrid BC level found in `bc-path` and places the results in `bc-out-path` (created if absent). The fine level must be there; a coarse level that is missing is reported and skipped, which is what a solver that builds its coarse grids without boundary conditions needs, and what a dispersed phase always looks like.

| Multigrid level | File name (no prefix) | File name (with prefix `<p>`) |
|---|---|---|
| 1 | `bc.txt` | `<p>bc.txt` |
| 2 | `bc2.txt` | `<p>bc2.txt` |
| *n* | `bc<n>.txt` | `<p>bc<n>.txt` |

New faces at cut planes are written as standard connection records (type `101`, the opposite face as donor, orientation `1 0 0 1`). Every other record keeps its type and property line, with the block and the local indices renumbered; the donors of connection and chimera records (`101`, `102`, `201`) are renumbered too, and those of the inter-phase records (`103`, `104`) against the other phase's decomposition. A manifold (`501`) names a whole block face: its payload is renumbered to the new block that inherited the source face entire. T-junctions between cut pieces require no special records.

!!! tip "Checking the result"
    `scripts/check-bc.py` verifies that every boundary cell appears exactly once, connection records are reciprocal, and chimera donors point inside a real block:

    ```bash
    python3 scripts/check-bc.py INPUT-split/bc.txt INPUT-split/bc2.txt
    ```

    Add `--dispersed` for a dispersed-phase file, whose property lines and
    repeated boundary table follow a different convention:

    ```bash
    python3 scripts/check-bc.py --dispersed INPUT-split/drop-bc.txt
    ```

    `scripts/check-split.py` verifies the split grid against the grid it came from: one zone per map record with the recorded dimensions, cells conserved and claimed exactly once, and every nodal and cell-centred value equal to its parent's:

    ```bash
    python3 scripts/check-split.py ic.tec ic-split.tec decomposition.map
    ```

    `scripts/check-coupling.py` checks the type-`103`/`104` records of the two files of a coupled case against each other, and `scripts/check-manifold.py` the manifold records of a split file against the original file and the map (source face whole, renumbered, same rank):

    ```bash
    python3 scripts/check-manifold.py INPUT/bc.txt INPUT-split/bc.txt decomposition.map
    ```

---

## Decomposition Map

`decomposition.map` (path controlled by `map-file`) is a plain-text file with two tables, one record per new block in each.

The index table:

| Column | Description |
|--------|-------------|
| `new` | 1-based index of the block in the decomposed mesh |
| `parent` | 1-based index of the original block this piece came from |
| `i0 i1 j0 j1 k0 k1` | Inclusive cell range of the piece inside its parent, in the parent's fine-level indices |
| `ni nj nk` | Cell dimensions of the piece |
| `cells` | Its cell count |
| `rank` | The rank MOSE and ICE will assign it to: MDB's copy of their partitioner (largest block first to the least loaded rank, ties in block order). No solver reads this column; it is what the solver will compute itself from the block sizes, recorded so that the map can be scored and checked. |

The face-origin table, `# face origin of every new block`:

| Column | Description |
|--------|-------------|
| `new`, `parent` | As above |
| `face1` … `face6` | For each of the six faces, the parent face number the piece inherited (`1` … `6`), or `cut` for a face created by the split. This is what tells you how the `[BCB-Block#]` face assignments carry over. |

`scripts/analyse_decomp.py` reads maps and reports the balance the solvers will see, the ghost overhead, MDB's score, the cut faces per axis and the cut faces whose neighbour sits on another rank; with `--assert-better` it compares maps, which is how the test suite gates the searched objectives against the greedy walk:

```bash
python3 scripts/analyse_decomp.py decomp/R12/decomposition.map decomp/R24/decomposition.map
```

---

## The decomposition report

Besides the block and rank counts, the report on standard output gives the `Predicted MOSE balance` (ideal load over the heaviest rank's, as the solvers will see it), the `Ghost-cell overhead` (two ghost layers per cut side, as a percentage of the cells), the `Score` under `objective = halo` or `cost`, and, whenever the fine-level BC file was found, the [cost model](index.md#the-cost-model)'s `Predicted rank time (max)`, `Predicted cost balance` and `Predicted rank-time spread`; the per-rank table then carries the predicted time of every rank. A coupled case decomposed phase by phase also prints how many type-`103`/`104` cells face a partner on another rank (`Interface over MPI`).
