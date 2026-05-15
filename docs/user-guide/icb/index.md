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

-   :material-arrow-decision: **Interpolate** (`interpolate`)

    ---

    Map an existing solution (`old-solution`) onto the current mesh with selectable interpolation laws.

    **When to use:** mesh refinement studies, transferring results between grid generations.

-   :material-nozzle: **Physics informed**

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

---

Use the full reference in [IC Strategies](./ic-strategies) for summary tables and INI syntax examples for each type.

## Workflow

0. Provide the required files (mesh, ICB INI, phase files).
1. Open a file and save it with an `.ini` extension (for example `input.ini`).
2. For each grid block, define an `ICB-BlockN` section.
3. Choose block type (`homogeneous`, `variable`, `interpolation`, `nozzle`) and add required keys.
4. Run ICB with the ICB INI file as input (if none is specified, it uses `input.ini`).
```bash
ATLAS ICB --input input.ini
```

Generated files are in `fromATLAStoSolver/`.

## References

- [Required files](./required-files)
- [IC Setup](./ic-setup)
- [IC Strategies](./ic-strategies)
- [Output Files](./output)
- [Input Reference](./input-reference) — INI keys and their meaning

See the [tutorials](/tutorials/icb/) for worked examples.

## Next

- [IC Setup](./ic-setup.md)
