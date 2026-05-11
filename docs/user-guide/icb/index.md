# ICB — Initial Condition Builder

ICB writes the initial solution field for one or more Hydra blocks. The strategy controls what physical state is imposed and how it is computed.

!!! tip "ICB in the ATLAS workflow"
    All Hydra solvers are supported, with initialisation procedures working seamlessly for both general and particular solver requirements. 

---

## IC Strategies

<div class="grid cards" markdown>

-   :material-weather-windy: **Uniform**

    ---

    Assign uniform primitive variables to the whole phase block.

    **When to use:** cold-start from a simple reference condition (freestream, chamber, stagnation state).

-   :material-chart-bell-curve: **1-D Profile**

    ---

    Map a one-dimensional distribution onto the three-dimensional block.

    **When to use:** non-uniform conditions.

-   :material-arrow-decision: **Interpolate** (`interpolate`)

    ---

    Map a solution from a coarser, finer, or differently-shaped mesh onto the current block using nearest-neighbour or bilinear interpolation.

    **When to use:** mesh refinement studies, transferring results between grid generations.

-   :material-nozzle: **Physics informed**

    ---

    Initialize the block using physical laws.

    **Supported:** choked converging-diverging nozzle.

</div>

---

## Summary

| Strategy | Phase | Key input |
|----------|-------|-----------|
| Uniform  | Any | State variables |
| 1-D profile | Ideal gas | Profile file |
| Nozzle (De Laval) | Ideal gas | p₀, T₀ |
| Interpolate | Any | Source solution |

---

Use the full reference in [IC Strategies](./ic-strategies) for summary tables and INI syntax examples for each type.

## Typical Workflow

0. Open the `input.ini` file
1. Define for each grid block a ICB-BlockN section, the desired strategy and required input.
2. Run ICB.
```bash
ATLAS ICB
```
3. Generated files are in `fromATLAStoSolver/`.

## References

- [Input Reference](./input-reference) — INI keys and their meaning
- [IC Strategies](./ic-strategies) — Full strategy reference
- [Output Files](./output) — Binary format written for Hydra

See the [tutorials](/tutorials/icb/) for worked examples.
