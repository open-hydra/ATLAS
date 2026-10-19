# STB — Source Terms Builder

STB writes source-term fields and auxiliary area-variation data for Hydra blocks. The selected setup controls whether STB builds a uniform field, a mapped 1-D profile, or optional geometry area tables.

!!! tip "STB in the ATLAS workflow"
       STB is optional in many cases, but required when source terms (for example `qvol`) or area-variation maps are needed by the target Hydra setup.

---

## STB Strategies

<div class="grid cards" markdown>

-   :material-fire: **Source Terms**

       ---

       Assign source values in each block: a uniform value, a 1-D profile, or a 3-D field on another mesh
       remapped conservatively. At present, it supports volumetric heat sources.

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
| 3-D source field (conservative remap) | Any STB block | `qvol-file` (a Tecplot field), no `direction` |
| Area variation map | Optional per block | `<dir>-areavariation` in `STB-BlockN` |

---

## Workflow

0. Provide mesh and STB input file(s). The mesh is searched in the working directory as `mesh.tec`, `mesh.p3d`, `mesh.szplt`, in that order (the first existing file is read, the others are ignored with a warning; MDB, run in the solver directory, uses `INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`).
1. Open a file and save it with an `.ini` extension (for example `input.ini`).
2. For each mesh block that carries a heat source, define an `STB-BlockN` section with either `qvol`, `qvol-file` + `direction` (a 1-D profile) or `qvol-file` alone (a 3-D field, see below) (blocks without a source are written with `qvol = 0` and reported as `no volumetric source`; if no block has one, no source file is written). A specific `STB-BlockN` section replaces the wildcard `STB-Block*` section for that block: its keys are not inherited, so a block that only overrides an area key has no `qvol` unless the key is repeated there.
3. Optionally add area-profile keys (`x-areavariation`, `y-areavariation`, `r-areavariation`, `theta-areavariation`) in the same `STB-BlockN` sections (area files only, without any `qvol`, is the normal Q2D workflow). Nodes of the block that lie outside the coordinate interval of the profile take the end values of the profile (clamped): STB prints `[WARNING] area law block <b>: <n> nodes lie outside the profile interval [x1, x2]` with the node coordinate range, so that a profile shorter than the block is noticed; a `qvol-file` profile that does not cover the block is refused instead. The rows of an area profile may come in any order (STB sorts them); a `qvol-file` profile, like every table that is interpolated as read, must give its coordinates in order, increasing or decreasing (a coordinate that turns back is refused). Conflicting source keys are refused: `qvol` together with `qvol-file` (the uniform value used to win silently), `direction` without `qvol-file`, a two-column table as `qvol-file` without `direction`, a Tecplot field as `qvol-file` with `direction`.
4. Run STB with the STB INI file as input.

### 3-D source field: conservative remap

A `qvol-file` without `direction` is a Tecplot structured field (ASCII, or `.szplt` with a TecIO build) on its own
mesh, the donor, in one or more ordered zones with three coordinates and one cell-centred variable: `power`, the
power of every donor cell in W (what a neutronics mesh tally gives), or `qvol`, the power density in W/m3 (multiplied
by the donor cell volume). STB remaps it onto every block that names the file, by cell overlap volumes (the exact
clipping of the two cells split into tetrahedra, as the chimera search uses), with a bucket grid over the donor cells:

- every receiver cell receives, from each donor cell it overlaps, a share of the donor power proportional to the
  overlap volume, over a donor volume that `qvol-remap` selects: `covered` (the default) is the donor volume that
  the receiver blocks of the same file cover, so a donor cell that the receivers cover only in part gives its whole
  power to the covered part and the power of every donor cell touched by a receiver is conserved (right when the
  field holds no power outside the blocks: the power a neutronics mesh cell tallies at a fuel boundary was deposited
  in its fuel part); `fraction` is the whole donor volume, so the blocks take their volume fraction of the power
  (right when the blocks are a part of the field, e.g. a symmetry sector of a fuel element tallied in full: the power
  of a donor cell cut by the symmetry plane belongs half to the mirror sector). Neither is exact where the two cases
  meet (a fuel boundary on a symmetry plane): STB prints the power mapped under both rules, so the difference is known
  (4 % on the 30-degree sector of a HALEU fuel element, 0.13 mm donor cells);
- the value written is the received power over the cell volume, in W/m3, for a 3-D mesh with three coordinates (a
  2-D `(x, y)` mesh has no cell volumes: refused);
- the blocks that name the same file are remapped together, so a donor cell shared by two blocks is split between
  them, not counted twice; the result does not depend on the number of threads;
- STB prints the donor power and the mapped power, how many donor cells are covered in part, and warns when donor
  cells that no receiver block overlaps hold power (not mapped) or when part of the receiver volume lies outside the
  field (no source there); the blocks of one file use one rule (two rules are refused).

```ini
[STB-Block12]
qvol-file = power.tec
qvol-remap = fraction
[STB-Block13]
qvol-file = power.tec
qvol-remap = fraction
```

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
