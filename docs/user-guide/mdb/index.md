# MDB — Mesh Decomposition Builder

MDB splits a multi-block structured grid — and its solution field if one is present — into more, smaller blocks so that MOSE can spread the work across a given number of MPI ranks. It also rewrites the boundary condition files for every multigrid level to match the new layout.

!!! tip "MDB in the ATLAS workflow"
    MOSE parallelises over **whole blocks**: a block is never divided between ranks. When there are fewer blocks than ranks, or when one block dominates the load, MDB is the tool that reshapes the mesh so the solver can scale. Run MDB after BCB and ICB, and before starting a MOSE simulation.

---

## Capabilities

<div class="grid cards" markdown>

-   :material-scissors-cutting: **Block Splitting**

    ---

    Subdivide heavy blocks along any combination of i, j, k directions. Cuts are placed at indices compatible with all multigrid coarse levels, and each piece is at least `min-cells` cells long.

    **When to use:** too few blocks for the target rank count, or load imbalance dominated by a single large block.

-   :material-file-swap-outline: **BC Propagation**

    ---

    Rewrites every multigrid BC file to reflect the decomposed topology. New interior faces at cut planes are automatically written as standard connections; T-junctions require no special treatment.

-   :material-map-outline: **Decomposition Map**

    ---

    Writes `decomposition.map` recording each new block's parent, index range, owning rank, and the origin of all six faces. Use it to post-process per-block diagnostics or reconstruct the original layout.

-   :material-tune: **Per-Block Direction Control**

    ---

    Override `split-directions` for individual blocks via `MDB-BlockN` sections. The typical use is to prevent wall-normal cuts in boundary-layer blocks.

</div>

---

## Summary

| Output | Contents |
|--------|----------|
| `<grid>-split.<ext>` | Decomposed grid (and solution field if the input carried one) |
| `<bc-out-path>/bc.txt`, `bc2.txt`, … | Decomposed BC files, one per multigrid level |
| `decomposition.map` | New block → parent block, index range, owning rank, and face origins |

The split is **exact**: node planes on a cut are duplicated in both neighbours and cell data is partitioned without duplication, so a decomposed restart carries the original solution unchanged — no interpolation is involved.

---

## Workflow

0. Confirm that BCB and ICB have produced their output files.
1. Set `ranks` to the number of MPI ranks you will launch MOSE with.
2. Optionally add `MDB-BlockN` sections to restrict cut directions on specific blocks.
3. Run MDB.

```ini
[ATLAS-Parameters]
MG-levels = 3

[MDB-Parameters]
ranks       = 48
grid        = INPUT/ic.tec
bc-path     = INPUT
bc-out-path = INPUT-split
```

```bash
ATLAS MDB
```

MDB prints a decomposition summary on completion:

```
 Decomposition
   Original blocks                11
   New blocks                     134
   MPI ranks                      48
   Total cells                    4563968
   Smallest block                 22400
   Largest block                  49280
   Ideal load per rank            95082.7
   Heaviest rank                  99840
   Predicted MOSE balance          95.2% of ideal
   Ghost-cell overhead             20.4%
```

`Predicted MOSE balance` is computed with a faithful copy of the solver's own partitioner, so it matches the number MOSE prints at run time.

!!! warning "Requirements"
    - 3-D meshes only: the BC header must carry `b i j k f type`.
    - Every block dimension must be a multiple of `2^(MG-levels-1)`, which MOSE requires for coarsening.
    - BC ids must be the current ATLAS set; files written with legacy numeric ids are rejected with the offending line quoted.

---

## References

- [Input Reference](./input-reference.md)
- [Output Files](./output.md)
