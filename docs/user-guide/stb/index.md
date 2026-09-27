# STB — Source Terms Builder

STB writes source-term fields and auxiliary area-variation data for Hydra blocks. The selected setup controls whether STB builds a uniform field, a mapped 1-D profile, or optional geometry area tables.

!!! tip "STB in the ATLAS workflow"
       STB is optional in many cases, but required when source terms (for example `qvol`) or area-variation maps are needed by the target Hydra setup.

---

## STB Strategies

<div class="grid cards" markdown>

-   :material-fire: **Source Terms**

       ---

       Assign source values in each block. At present, it supports volumetric heat sources.

-   :material-ruler-square-compass: **Area Variation Map**

       ---

       Build area tables for the Q2D solver.

</div>

---

## Summary

| Strategy | Scope | Key input |
|----------|-------|-----------|
| Uniform source | Any STB block | `qvol` |
| 1-D source profile | Any STB block | `qvol-file`, `direction` |
| Area variation map | Optional per block | `<dir>-areavariation` in `STB-BlockN` |

---

## Workflow

0. Provide mesh and STB input file(s). The mesh is searched in the working directory as `mesh.tec`, `mesh.p3d`, `mesh.szplt`, in that order (the first existing file is read, the others are ignored with a warning; MDB, run in the solver directory, uses `INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`).
1. Open a file and save it with an `.ini` extension (for example `input.ini`).
2. For each mesh block that carries a heat source, define an `STB-BlockN` section with either `qvol` or `qvol-file` + `direction` (blocks without a source are written with `qvol = 0` and reported as `no volumetric source`; if no block has one, no source file is written). A specific `STB-BlockN` section replaces the wildcard `STB-Block*` section for that block: its keys are not inherited, so a block that only overrides an area key has no `qvol` unless the key is repeated there.
3. Optionally add area-profile keys (`x-areavariation`, `y-areavariation`, `r-areavariation`, `theta-areavariation`) in the same `STB-BlockN` sections (area files only, without any `qvol`, is the normal Q2D workflow). Nodes of the block that lie outside the coordinate interval of the profile take the end values of the profile (clamped): STB prints `[WARNING] area law block <b>: <n> nodes lie outside the profile interval [x1, x2]` with the node coordinate range, so that a profile shorter than the block is noticed; a `qvol-file` profile that does not cover the block is refused instead. The rows of an area profile may come in any order (STB sorts them); a `qvol-file` profile, like every table that is interpolated as read, must give its coordinates in order, increasing or decreasing (a coordinate that turns back is refused). Conflicting source keys are refused: `qvol` together with `qvol-file` (the uniform value used to win silently), `direction` without `qvol-file`.
4. Run STB with the STB INI file as input.

```bash
ATLAS STB --input input.ini
```

Generated files are written to `fromATLAStoSolver/`.

## References

- [Input Reference](./input-reference.md) — INI keys and supported parameters
- [Output Files](./output.md) — Files written for Hydra

See the [tutorials](/tutorials/stb/) for worked examples.

## Next

- [Input Reference](./input-reference.md)
