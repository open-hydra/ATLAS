# ATLAS MDB Input Parameters

The tables are written by `MDB --write-config-doc` (`ATLAS DOCS` regenerates every tool's page); the sections after them are maintained by hand. Command line: `-i <file>` selects the INI file, `-v` prints every candidate the search visits, `--sweep R1,R2,...` tabulates the best cut per rank count and writes nothing (through the wrapper: `ATLAS MDB -- --sweep 8,12,16`).

## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| MDB-file | input.ini |  |  no | INI file containing the MDB parameters. |
| MG-levels | 1 | >=1 |  no | Number of multigrid levels the solver will run. Every cut is placed at a multiple of 2^(MG-levels-1) so that each coarse level cuts at an integer index too, and one BC file per level is rewritten. |
| strict-keys | T |  |  no | F turns the error on a key the tool does not read (or not honoured by the resolved BC type, or y of an undeclared species) into a WARNING; wrong values are always errors (keys with the prefix ignore- are never read). |

## MDB-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| ranks | 0 |  | yes | Number of MPI ranks the mesh must be balanced for. |
| target-balance | 95.0 |  |  no | Stop splitting once the predicted MOSE balance reaches this percentage of ideal. |
| halo-weight | 1.0 | >= 0 |  no | Cost of a ghost cell relative to a real one when scoring a decomposition; 0 restores the old balance-only behaviour. |
| max-blocks | 0 |  |  no | Hard cap on the number of blocks produced (0 = 8 x ranks). |
| min-cells | 0 |  |  no | Smallest admissible sub-block extent along a cut direction (0 = 4 x 2^(MG-levels-1)). |
| split-directions | ijk | any subset of ijk |  no | Directions that may be cut; can be overridden per block in [MDB-Block#]. |
| objective | balance | balance, halo, cost |  no | What the decomposition is chosen for. balance: the greedy walk (cut the heaviest block along its longest axis until target-balance), scored by balance / (1 + halo-weight x ghost). halo: search every factorisation Px x Py x Pz of every admissible part count for the best value of that same score, judged after the solvers' own LPT assignment. cost: the same search for the smallest predicted rank time of the [MDB-Cost] model, judged the same way. |
| blocks-per-rank | 1 | >= 1 |  no | Under objective = halo or cost the search starts at ranks x blocks-per-rank parts and goes up to max-blocks. MOSE and ICE thread inside a block, so more blocks per rank buy no OpenMP; raise it only to reach balance at an awkward rank count. |
| balance-tolerance | 2.0 | >= 0 |  no | Under objective = halo or cost, a block whose cells exceed the ideal load per part by at most this percentage is left whole: a cut there buys no balance. Exact balance is impossible when the rank count does not divide the cells, so a 98.5% cut is accepted, not refused. |
| grid |  |  |  no | Grid or grid+solution file to split (empty = autodetect INPUT/ic.* then mesh.*). |
| grid-out |  |  |  no | Output grid file (empty = <grid>-split.<ext>). |
| bc-path | INPUT |  |  no | Directory holding the boundary condition files to split. |
| bc-out-path | INPUT-split |  |  no | Directory the decomposed boundary condition files are written to. |
| phase-type |  | gas | dispersed |  no | Phase kind of the BC files: gas or dispersed, which use different property-line conventions. Empty = read it from <prefix>phase.txt. |
| prefix |  |  |  no | MOSE phase prefix of the BC files (<prefix>bc.txt). |
| map-file | decomposition.map |  |  no | File recording the new-block to parent-block mapping. |
| same-cut | false | true, false |  no | Coupled mode only. true applies the decomposition of [MDB-Phase1] to every other phase, which must share its mesh block for block (a gas and its Eulerian condensed phase): every cell of one phase then sits on the rank of the same cell of the other by construction. false decomposes each phase on its own and reports how many type-103/104 interface cells face a partner on another rank after the solvers' LPT. |

## MDB-Phase*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| grid |  |  |  no | Grid or grid+solution file of this phase. Declaring [MDB-Phase1] and [MDB-Phase2] puts MDB in coupled mode, which is required whenever the BC files contain type-103 (inter-phase connection) or type-104 (inter-phase chimera) records. |
| grid-out |  |  |  no | Output grid file for this phase (empty = <grid>-split.<ext>). |
| bc-path | INPUT |  |  no | Directory holding this phase's boundary condition files. |
| bc-out-path | INPUT-split |  |  no | Directory this phase's decomposed boundary condition files go to. |
| prefix |  |  |  no | Phase prefix of this phase's BC files (<prefix>bc.txt). |
| map-file |  |  |  no | Decomposition record for this phase (empty = <prefix>decomposition.map). |
| ranks | 0 |  |  no | Ranks to balance this phase for (0 = the [MDB-Parameters] value). Both phases run on every rank, so leaving this at 0 is almost always right. |

## MDB-Cost

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| c-cell | 1.0 | >= 0 |  no | Time per interior cell (the flux and update work). The predicted time of a rank is the sum over its blocks of c-cell x cells + c-face-<class> x boundary cells + c-ghost x ghost cells, plus c-msg x messages and c-byte x bytes exchanged with other ranks, the ranks being the ones the solvers' own LPT on cell counts forms. All coefficients are 1 until calibrated from the solver's timers. |
| c-face-connection | 1.0 | >= 0 |  no | Time per boundary cell of a connection record (101, 201). |
| c-face-coupled | 1.0 | >= 0 |  no | Time per boundary cell of a coupled record (103). |
| c-face-chimera | 1.0 | >= 0 |  no | Time per boundary cell of a chimera record (102, 104). |
| c-face-symmetry | 1.0 | >= 0 |  no | Time per boundary cell of a symmetry record (300). |
| c-face-wall | 1.0 | >= 0 |  no | Time per boundary cell of a wall record (301-309 and unknown ids). |
| c-face-inout | 1.0 | >= 0 |  no | Time per boundary cell of a inout record (400-499). |
| c-face-special | 1.0 | >= 0 |  no | Time per boundary cell of a special record (500-599). |
| c-ghost | 1.0 | >= 0 |  no | Time per ghost cell filled (two layers on every face of every block). |
| c-msg | 1.0 | >= 0 |  no | Time per message: one per (block face, neighbouring block on another rank) pair. |
| c-byte | 1.0 | >= 0 |  no | Time per byte exchanged with other ranks: the ghost cells of every face whose neighbour sits on another rank, times bytes-per-cell. |
| bytes-per-cell | 1.0 | > 0 |  no | Bytes a ghost cell carries in the exchange. 1 makes the c-byte term count cells; the calibration sets it to the solver's variables x 8. |
| cost-file |  |  |  no | A measured table overriding the keys above: one `key value` per line, the same key names, comments after # or ;. |

## MDB-Block*

Per-block overrides. `*` is replaced by the 1-based block index (e.g. `MDB-Block7`).

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| split-directions | *(from MDB-Parameters)* | any subset of `i`, `j`, `k` | no | Restrict the cut directions for this block. Typical uses: `ik` on a boundary-layer block to prevent wall-normal (`j`) cuts; the normal direction of a manifold face, which MDB requires to stay whole. |

## Coupled mode

Declaring `MDB-Phase1` and `MDB-Phase2` puts MDB in coupled mode and supersedes the flat `grid` / `grid-out` / `prefix` / `map-file` keys of `MDB-Parameters`; with none declared those flat keys describe a single phase, so existing single-phase inputs are unaffected. Phases are read consecutively from `MDB-Phase1` until one without `grid` is met.

Coupled mode is **required** whenever the BC files contain type-`103` or `104` records. A `103` record is the fluid-solid interface, and its donor is numbered in the *other* phase — ATLAS block ids restart at 1 for each phase — so the donor can only be resolved against that other phase's decomposition. Splitting a coupled case one phase at a time cannot do that, and MDB stops with an error rather than rewriting the interface against the wrong block numbering. Exactly two phases may be declared: a `103` record names only `(block,i,j,k)` in "the other phase", so the interface is ambiguous with three or more.

Two phases that share one mesh block for block — a gas and its Eulerian condensed phase, coupled cell for cell — take one decomposition with `same-cut = true`: phase 2 gets phase 1's cut, the two maps are identical and every cell of one phase sits on the rank of its twin. The phases must then be balanced for the same `ranks`. Without `same-cut`, each phase is decomposed on its own and the report counts, per phase, how many `103`/`104` cells face a partner the solvers' partitioner puts on another rank.

### Example

```ini
[MDB-Parameters]
ranks       = 24
objective   = halo
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

## The cost model

`[MDB-Cost]` prices a decomposition as the solvers will pay for it, rank by rank after their own partitioner has formed the ranks (see the [overview](index.md#the-cost-model)). The unit defaults make the model structural; the measured coefficients arrive from the solver's timers, per BC class, and are best kept in one file named by `cost-file`:

```
# measured on the 192^3 case, ICE timers
c-cell          1.0
c-face-wall     2.8     ; per boundary cell of a viscous wall
c-face-symmetry 0.6
c-ghost         0.4
c-msg           120.0   ; latency, in cell units
c-byte          0.02
bytes-per-cell  40      # five 8-byte primitives
```

`objective = cost` needs the fine-level BC file to be found before the decomposition; the three `Predicted` lines of the report are printed under every objective once it is.
