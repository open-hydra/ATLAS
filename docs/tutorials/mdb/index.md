# MDB Tutorials

All test cases referenced here are available in `test/MDB/`.

| Case | Test objective |
|------|----------------|
| `split-longest` | Validate that a block is cut along its longest admissible axis, the cut with the smallest new interface. |
| `block-directions` | Validate the per-block `split-directions` override: two identical blocks, one protected from wall-normal cuts, are cut along different axes and joined by a T-junction. |
| `mg3-granularity` | Validate multigrid cut alignment at three levels: cuts on the `2^(MG-levels-1)` lattice, remainder granules spread one per piece, and every BC level rewritten. |
| `halo-trade` | Validate the balance/ghost-cell objective: the search reverts to the decomposition with the best `balance / (1 + halo-weight * ghost)` rather than the last one it visited. |
| `balance-only` | Validate that `halo-weight = 0` restores the historical balance-only objective; the reference is the over-split answer, kept as the counterpart of `halo-trade`. |
| `split-solution` | Validate the full BCB - ICB - MDB chain: a grid carrying a solution field is partitioned without interpolation, and the phase-prefixed BC files are split. |

Every case verifies three things:

- **`scripts/check-split.py`** — the split grid against the grid it came from:
  block dimensions match the map, cells are conserved and claimed exactly once,
  and every nodal and cell-centred value equals its parent's.
- **`scripts/check-bc.py`** — the split BC file on its own terms: every boundary
  cell present exactly once, every connection record reciprocal.
- **`diff` against `reference/`** — the decomposition map and the BC files, which
  pin the cut placement, the block numbering and the canonical record order.

The meshes are small uniform boxes: what is under test is the decomposition, not
the geometry. The binary (`.szplt`) grid path is not covered — it shares all of
its splitting code with the ASCII path and differs only in the ORION reader and
writer.
