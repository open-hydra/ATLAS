# STB — Setup Tool Builder

STB computes geometric data required by Hydra for variable-area configurations such as nozzles and ducts.

---

## What STB Can Produce

<div class="grid cards" markdown>

-   :material-ruler-square: **Area Schedule**

    ---

    Compute the cross-sectional area distribution $A(x)$ from a contour or point set. Output is used by Hydra's quasi-1-D variable-area option.

    **Inputs:** axial station coordinates and corresponding cross-sectional areas or contour points.

    **Output:** area variation file read by Hydra at runtime.

    **When to use:** any converging–diverging nozzle, duct with varying cross-section, or thrust chamber geometry.

-   :material-chart-areaspline: **Cross-Section Profile**

    ---

    Tabulate the area at each axial station from a geometric description of the contour.

    **When to use:** nozzle design validation, checking that the area ratio matches design intent before a run.

</div>

---

## Typical Workflow

```
STB reads: axial stations + area or contour points
       ↓
Produces: area schedule file (read by Hydra)
       ↓
ICB uses: area schedule as input for De Laval nozzle initialization
       ↓
Hydra uses: area variation at runtime for 3-D body-force term
```

STB output is required whenever the ICB `nozzle` strategy is used.

---

## Usage

```bash
./STB -input stb.ini
```

## Configuration

- [Input Reference](./input-reference) — INI keys and supported parameters
- [Output Files](./output) — Files written for Hydra

See the [tutorials](/tutorials/stb/) for worked examples.
