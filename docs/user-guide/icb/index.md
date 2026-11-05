# ICB — Initial Condition Builder

ICB writes the initial solution field for one or more Hydra blocks. The strategy controls what physical state is imposed and how it is computed.

!!! tip "ICB in the ATLAS workflow"
    All Hydra solvers are supported, with initialisation procedures working seamlessly for both general and particular solver requirements. 

---

## IC Strategies

<div class="grid cards" markdown>

-   :material-weather-windy: **Uniform**

    ---

    Assign homogeneous state values to the whole block (or to selected zones).

    **When to use:** cold-start from a reference chamber/freestream condition.

-   :material-chart-bell-curve: **1-D Profile**

    ---

    Map file-based 1-D profiles with `<key>-file` and `<key>-direction`.

    **When to use:** prescribed non-uniform temperature, pressure, or velocity starts.

-   :material-arrow-decision: **Interpolation** (`interpolation`)

    ---

    Map an existing solution (`old-solution`) onto the current mesh with selectable interpolation laws.

    **When to use:** mesh refinement studies, transferring results between grid generations.

-   :material-cone: **Physics informed**

    ---

    Initialize ideal-gas blocks from nozzle assumptions.

    **Supported:** de Laval-style nozzle initialization (`type = nozzle`).

</div>

---

## Summary

| Strategy | Phase | Key input |
|----------|-------|-----------|
| Homogeneous | Any | Phase state variables |
| Variable (file-backed) | IG / RF / SP | `<key>-file`, `<key>-direction` |
| Nozzle | Ideal gas | `p0`, `T0`, `nozzle-direction` |
| Interpolation | Any | `old-solution`, `interpolation-law` |
| Zones | Any | `direction`, `zone<n>`, `range<n>` |

---

Use the full reference in [IC Strategies](./ic-strategies.md) for summary tables and INI syntax examples for each type.

## Workflow

1. Provide the [required files](required-files.md): the mesh, and the phase files GPB wrote, copied from
   `fromATLAStoSolver/` into the case directory.
2. In the INI file (`input.ini` by default), define an `[ICB-BlockN]` section for each block, or one
   `[ICB-Block*]` section for every block without a section of its own.
3. Choose the block type (`homogeneous`, `variable`, `interpolation`, `nozzle`, `multizone`) and add its keys.
4. Run ICB:

```bash
ATLAS ICB --input input.ini
```

Generated files are in `fromATLAStoSolver/`.

## References

- [Required files](./required-files.md)
- [IC Setup](./ic-setup.md)
- [IC Strategies](./ic-strategies.md)
- [Output Files](./output.md)
- [Input Reference](./input-reference.md) — INI keys and their meaning

See the [ICB reference cases](../../tutorials/icb/index.md) for worked examples.

## Next

- [IC Setup](./ic-setup.md)
