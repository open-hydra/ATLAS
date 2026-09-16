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

## MDB-Phase*

Coupled (multi-phase) cases. `*` is replaced by the 1-based phase index
(`MDB-Phase1`, `MDB-Phase2`). Declaring these sections puts MDB in coupled mode
and supersedes the flat `grid` / `grid-out` / `prefix` / `map-file` keys of
`MDB-Parameters`; with none declared those flat keys describe a single phase, so
existing single-phase inputs are unaffected.

Coupled mode is **required** whenever the BC files contain type-`103` records.
A `103` record is the fluid–solid interface, and its donor is numbered in the
*other* phase — ATLAS block ids restart at 1 for each phase — so the donor can
only be resolved against that other phase's decomposition. Splitting a coupled
case one phase at a time cannot do that, and MDB now stops with an error rather
than rewriting the interface against the wrong block numbering.

Exactly two phases may be declared: a `103` record names only `(block,i,j,k)` in
"the other phase", so the interface is ambiguous with three or more.

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| grid | *(none)* | | yes | Path to this phase's grid (or grid+solution) file. This is the key that makes the section exist; phases are read consecutively from `MDB-Phase1` until one is missing. |
| grid-out | `<grid>-split.<ext>` | | no | Output path for this phase's decomposed grid. |
| bc-path | *(from MDB-Parameters)* | | no | Directory containing this phase's BC files. |
| bc-out-path | *(from MDB-Parameters)* | | no | Directory for this phase's decomposed BC files. Both phases may share one directory: the files are distinguished by `prefix`. |
| prefix | *(empty)* | | no | This phase's BC file prefix (`<prefix>bc.txt`), e.g. `gas-` and `plate-`. |
| map-file | `<prefix>decomposition.map` | | no | Decomposition record for this phase. Must differ between phases. |
| ranks | *(from MDB-Parameters)* | >=1 | no | Ranks to balance this phase for. Both solvers run on every rank in a coupled run, so leaving this unset is almost always right; setting it differently per phase is mainly useful for testing. |

### Example

```ini
[MDB-Parameters]
ranks       = 24
bc-path     = INPUT
bc-out-path = INPUT-split

[MDB-Phase1]
grid     = INPUT/gas-ic.tec
grid-out = INPUT-split/gas-ic.tec
prefix   = gas-

[MDB-Phase2]
grid     = INPUT/plate-ic.tec
grid-out = INPUT-split/plate-ic.tec
prefix   = plate-
```
