# MDB Output Files

MDB writes its outputs to the paths configured in `[MDB-Parameters]`. No output directory is hard-coded; all paths default to sensible values but can be overridden.

---

## Decomposed Grid

| `grid-out` setting | Default file name |
|--------------------|-------------------|
| Not set | `<input-grid>-split.<ext>` |
| Explicit path | As specified |

The output file is written in the same format as the input (Tecplot ASCII `.tec` or Tecplot binary `.szplt`). If the input grid file also carries a solution field (restart data), the solution is partitioned block-by-block into the output file — no interpolation is performed and the field values are unchanged.

---

## Decomposed BC Files

MDB rewrites every multigrid BC level found in `bc-path` and places the results in `bc-out-path` (created if absent).

| Multigrid level | File name (no prefix) | File name (with prefix `<p>`) |
|---|---|---|
| 1 | `bc.txt` | `<p>bc.txt` |
| 2 | `bc2.txt` | `<p>bc2.txt` |
| *n* | `bc<n>.txt` | `<p>bc<n>.txt` |

New interior faces generated at cut planes are written as standard connection records. All other BC records are copied verbatim, with block and face indices updated to reflect the new numbering. T-junctions between cut pieces require no special records.

!!! tip "Checking the result"
    `scripts/check-bc.py` verifies that every boundary cell appears exactly once, connection records are reciprocal, and chimera donors point inside a real block:

    ```bash
    python3 scripts/check-bc.py INPUT-split/bc.txt INPUT-split/bc2.txt
    ```

    `scripts/check-split.py` verifies the split grid against the grid it came from: one zone per map record with the recorded dimensions, cells conserved and claimed exactly once, and every nodal and cell-centred value equal to its parent's:

    ```bash
    python3 scripts/check-split.py ic.tec ic-split.tec decomposition.map
    ```

---

## Decomposition Map

`decomposition.map` (path controlled by `map-file`) is a plain-text file with one record per new block. Each record contains:

| Field | Description |
|-------|-------------|
| New block index | 1-based index in the decomposed mesh |
| Parent block index | 1-based index of the original block this piece came from |
| Index range | Start and end cell indices `[i0:i1, j0:j1, k0:k1]` within the parent block |
| Owning rank | MPI rank assigned by the MOSE partitioner |
| Face origins | For each of the six faces: whether it is an original boundary face, a new connection face created by a cut, or an interior face |

Use the map file to post-process per-block diagnostics, reconstruct the original block layout, or verify that a decomposition covers the expected range.
