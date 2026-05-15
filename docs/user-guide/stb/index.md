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
| Area variation map | Optional per block | `<dir>-areavariation` in `BCB-BlockN` |

---

## Workflow

0. Provide mesh and STB input file(s).
1. Open a file and save it with an `.ini` extension (for example `input.ini`).
2. For each mesh block, define an `STB-BlockN` section with either `qvol` or `qvol-file` + `direction`.
3. Optionally add area-profile keys (`x-areavariation`, `y-areavariation`, `r-areavariation`, `theta-areavariation`) in `BCB-BlockN` sections.
4. Run STB with the STB INI file as input.

```bash
ATLAS STB --input input.ini
```

Generated files are written to `fromATLAStoSolver/`.

## References

- [Input Reference](./input-reference) — INI keys and supported parameters
- [Output Files](./output) — Files written for Hydra

See the [tutorials](/tutorials/stb/) for worked examples.

## Next

- [Input Reference](./input-reference.md)
