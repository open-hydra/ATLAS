# MDB — Mesh Decomposition Builder

MDB splits a multi-block structured grid — and its solution field if one is present — into more, smaller blocks so that MOSE and ICE can spread the work across a given number of MPI ranks. It also rewrites the boundary condition files for every multigrid level to match the new layout.

!!! tip "MDB in the ATLAS workflow"
    MOSE and ICE parallelise over **whole blocks**: a block is never divided between ranks, and each solver assigns the blocks to ranks at start-up with the same rule (largest block first to the least loaded rank). When there are fewer blocks than ranks, or when one block dominates the load, MDB is the tool that reshapes the mesh so the solvers can scale. Run MDB after BCB and ICB, and before starting a simulation.

---

## Capabilities

<div class="grid cards" markdown>

-   :material-scissors-cutting: **Block Splitting**

    ---

    Subdivide heavy blocks along any combination of i, j, k directions. Cuts are placed at indices compatible with all multigrid coarse levels, and each piece is at least `min-cells` cells long.

    **When to use:** too few blocks for the target rank count, or load imbalance dominated by a single large block.

-   :material-target: **Three Objectives**

    ---

    `objective = balance` is the historical greedy walk: cut the heaviest block along its longest axis until the balance target is met. `halo` searches every factorisation `Px x Py x Pz` of every admissible part count for the best value of MDB's score, `balance / (1 + halo-weight x ghost)`. `cost` runs the same search for the smallest predicted rank time of the [cost model](#the-cost-model).

    **When to use:** `halo` or `cost` whenever the mesh has to be cut; `balance` reproduces earlier decompositions exactly.

-   :material-file-swap-outline: **BC Propagation**

    ---

    Rewrites every multigrid BC file to reflect the decomposed topology. New faces at cut planes are written as standard connections; T-junctions require no special treatment. A manifold (BC 501) is renumbered to the block that inherited its source face, and refused when a cut would split either of its faces or put the pair on two ranks.

-   :material-map-outline: **Decomposition Map**

    ---

    Writes `decomposition.map` recording each new block's parent, index range, the rank the solvers' partitioner will give it, and the origin of all six faces. Use it to post-process per-block diagnostics or reconstruct the original layout; `scripts/analyse_decomp.py` scores maps from it.

-   :material-tune: **Per-Block Direction Control**

    ---

    Override `split-directions` for individual blocks via `MDB-BlockN` sections. The typical use is to prevent wall-normal cuts in boundary-layer blocks, or to keep a manifold face whole.

-   :material-layers-triple-outline: **Coupled (Multi-Phase) Cases**

    ---

    Declare `MDB-Phase1` and `MDB-Phase2` to split a coupled case. Two phases sharing one mesh (a gas and its Eulerian condensed phase) take one decomposition with `same-cut = true`; a fluid over a solid is decomposed phase by phase, the type-`103`/`104` interface records are remapped against the *other* phase's decomposition, and MDB reports how many interface cells face a partner on another rank.

    **When to use:** any case with two phase files, i.e. anything run with `hydra-MF`, `hydra-AF` or `hydra-MI2`.

-   :material-chart-bar: **Sweep**

    ---

    `ATLAS MDB -- --sweep 8,12,16` tabulates, for every rank count of the list, what the greedy walk and the configured objective settle on — blocks, balance, ghost, score, predicted rank time — without writing anything.

    **When to use:** choosing the rank count of a campaign.

</div>

---

## Summary

| Output | Contents |
|--------|----------|
| `<grid>-split.<ext>` | Decomposed grid (and solution field if the input carried one) |
| `<bc-out-path>/bc.txt`, `bc2.txt`, … | Decomposed BC files, one per multigrid level |
| `decomposition.map` | New block → parent block, index range, rank, and face origins |

For a coupled case each phase produces its own set: `<prefix>bc.txt` in the shared `bc-out-path`, its own split grid, and its own `<prefix>decomposition.map`.

The split is **exact**: node planes on a cut are duplicated in both neighbours and cell data is partitioned without duplication, so a decomposed restart carries the original solution unchanged — no interpolation is involved.

---

## Workflow

0. Confirm that BCB and ICB have produced their output files.
1. Set `ranks` to the number of MPI ranks you will launch the solver with
   (`grid` may be left unset: see *Which mesh file is read* below).
2. Choose the objective: `halo` for a mesh that has to be cut, `cost` once the [cost model](#the-cost-model) is calibrated, `balance` to reproduce an earlier decomposition.
3. For a coupled case, add one `MDB-Phase*` section per phase (see [Input Reference](input-reference.md)); set `same-cut = true` when the two phases share the mesh. MDB refuses to split a mesh containing type-`103` records without the two sections, because the interface cannot be remapped from one phase alone.
4. Optionally add `MDB-BlockN` sections to restrict cut directions on specific blocks.
5. Run MDB.

```ini
[ATLAS-Parameters]
MG-levels = 3

[MDB-Parameters]
ranks       = 48
objective   = halo
grid        = INPUT/ic.tec
bc-path     = INPUT
bc-out-path = INPUT-split
```

```bash
ATLAS MDB
```

### Which mesh file is read

Without `grid` (or per-phase `grid`), MDB takes the first file that exists among

`INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`

in that order. The list differs from the one of BCB, ICB and STB (`mesh.tec`,
`mesh.p3d`, `mesh.szplt` in the working directory) because MDB is run in the
**solver** directory, where the mesh to split is the grid inside the initial
condition written by ICB (`INPUT/ic.tec`, grid plus solution field), while the
builders run in the case directory next to the bare mesh. The first existing
file is the only one read: a stale file earlier in the list shadows the intended
one, so set `grid` explicitly when in doubt.

MDB prints a decomposition summary on completion:

```
 Decomposition
   Original blocks                1
   New blocks                     12
   MPI ranks                      12
   Total cells                    110592
   Smallest block                 9216
   Largest block                  9216
   Ideal load per rank            9216.0
   Heaviest rank                  9216
   Lightest rank                  9216
   Predicted MOSE balance         100.0% of ideal
   Ghost-cell overhead             33.3%
   Objective                      halo
   Score balance/(1+w*ghost)       75.0
   Predicted rank time (max)      21124.0
   Predicted cost balance          96.4% of ideal
   Predicted rank-time spread       3.8%
```

`Predicted MOSE balance` is computed with a faithful copy of the solvers' own partitioner, so it matches the number MOSE or ICE prints at run time. `Ghost-cell overhead` counts the two ghost layers on every cut side as a percentage of the cells: the price of splitting, paid at every stage in fill and exchange. The three `Predicted` lines are the [cost model](#the-cost-model), printed whenever the fine-level BC file was found.

### The objectives

The greedy walk (`balance`) cuts the heaviest block along its longest axis into as many parts as the ideal load asks for, so it never sees a `3 x 2 x 2` cut of a cube: a `48^3` block on 12 ranks becomes twelve `4 x 48 x 48` slabs at 91.7 % ghost, where `16 x 24 x 24` pieces balance the same at 33.3 %. `halo` enumerates every admissible number of parts (from `ranks x blocks-per-rank` to `max-blocks`), apportions the parts to the blocks by weight, enumerates every factorisation of each block's share on the granule lattice, and keeps the candidate with the best score. Every candidate is judged as the solver will see it: pieces in their final numbering, assigned by the solvers' own rule.

`cost` runs the same search for the smallest predicted rank time. Its worth over `halo` is the face mix: a wall priced above a symmetry makes the search cut so that every piece carries its share of the wall — equal cells, equal work — which is the only lever MDB has on the spread of ranks the solvers form on cell counts alone.

### The cost model

The predicted time of a rank is

```
T(rank) = sum over the rank's blocks of   c-cell x cells
                                        + c-face-<class> x boundary cells
                                        + c-ghost x ghost cells
        + c-msg x messages + c-byte x bytes exchanged with other ranks
```

evaluated **after** the solvers' LPT assignment on cell counts, with the ranks it forms. The face classes are `connection` (101, 201), `coupled` (103), `chimera` (102, 104), `symmetry` (300), `wall` (301-309), `inout` (400-series) and `special` (500-series); a cut face is a connection. The coefficients are the `[MDB-Cost]` keys, all 1 until calibrated, or a `cost-file` table over them; the measured values come from the solver's timers, per BC class. Data-dependent cost (a shock detector, a stiff cell) is not modelled.

!!! warning "Requirements"
    - 3-D meshes only: the BC header must carry `b i j k f type`.
    - Every block dimension must be a multiple of `2^(MG-levels-1)`, which the solvers require for coarsening.
    - BC ids must be the current ATLAS set; files written with legacy numeric ids are rejected with the offending line quoted.
    - A dispersed phase is read with its own conventions, taken from the first line of `<prefix>phase.txt` (override with `phase-type`): no property line under the 300-series, and the whole boundary table repeated once per (material, population) pair. Every copy is split the same way and they are written back in the same order.
    - A manifold (BC 501) names a whole source face: MDB refuses a cut tangential to either face of the pair, and a pair the solvers' partitioner would put on two ranks (MOSE aborts on such a pair at start-up). Restrict the cuts with `[MDB-Block#] split-directions` or change `ranks`.
    - `objective = cost` needs the fine-level BC file before the decomposition, to price the faces.

---

## References

- [Input Reference](./input-reference.md)
- [Output Files](./output.md)
