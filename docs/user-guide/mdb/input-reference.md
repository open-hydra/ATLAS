# ATLAS MDB Input Parameters


## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| MG-levels | 1 | >=1 | no | Number of multigrid levels. Controls the cut-index alignment: every cut is placed at a multiple of `2^(MG-levels-1)`. Must match the value used by MOSE. |

## MDB-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| ranks | — | >=1 | **yes** | Number of MPI ranks to balance for. |
| target-balance | 95.0 | >0, <=100 | no | Stop cutting once the predicted load balance reaches this percentage of the ideal (perfectly equal) load. |
| halo-weight | 1.0 | >=0 | no | Cost of a ghost cell relative to a real one when scoring a decomposition. Candidates are ranked by `balance / (1 + halo-weight × ghost-overhead)`, so a larger value buys fewer cuts and a smaller one more balance; `0` restores the balance-only behaviour. |
| max-blocks | 8 × ranks | >=1 | no | Hard cap on the total number of blocks produced. Cutting stops when this limit is reached even if `target-balance` has not been met. |
| min-cells | 4 × 2^(MG-levels-1) | >=1 | no | Minimum admissible block extent (in cells) along a cut direction. Prevents producing blocks too small for the multigrid coarsening chain. |
| split-directions | ijk | any subset of `i`, `j`, `k` | no | Global set of directions along which blocks may be cut. Can be overridden per block via `MDB-Block*` sections. |
| grid | autodetect | | no | Path to the grid file (Tecplot ASCII or binary). If the file also carries a solution field, it is split alongside the grid. Autodetected from the working directory when not set. |
| grid-out | `<grid>-split.<ext>` | | no | Output path for the decomposed grid file. Defaults to the input name with `-split` appended before the extension. |
| bc-path | INPUT | | no | Directory containing the BC files to split (`bc.txt`, `bc2.txt`, …). |
| bc-out-path | INPUT-split | | no | Directory where the decomposed BC files are written. Created if it does not exist. |
| prefix | *(empty)* | | no | Phase name prefix used in BC file names. Set this when the BC files follow the `<prefix>bc.txt` naming convention (multi-phase setups). |
| map-file | decomposition.map | | no | Path where the decomposition record is written. |

## MDB-Block*

Per-block overrides. `*` is replaced by the 1-based block index (e.g. `MDB-Block7`).

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| split-directions | *(from MDB-Parameters)* | any subset of `i`, `j`, `k` | no | Restrict the cut directions for this block. Typical use: set to `ik` on a boundary-layer block to prevent wall-normal (`j`) cuts. |
