# GPB — General Phase Builder

GPB builds property tables for one or more phases. Each phase is an independent block in the INI file; a single run can produce tables for multiple phases of different types.

!!! tip "GPB in the ATLAS workflow"
    All Hydra solvers are supported, with property table formats designed to be flexible and extensible across different physics and solver requirements.

---

## Phase Types

<div class="grid cards" markdown>

-   :material-weather-windy: **Ideal Gas**

    ---

    The most flexible type. Supports Cantera and CEA data sources, finite-rate chemistry, and equilibrium calculations. Tables are built assuming thermally-perfect gas mixture.

    [Ideal Gas](./ideal-gas.md)

-   :material-water: **Real Fluid**

    ---

    High-pressure, non-ideal, and supercritical fluids via CoolProp, Redlich–Kwong, or Peng–Robinson. Tables are built on a (p, h) grid.

    [Real Fluid](./real-fluid.md)

-   :material-liquid-spot: **Condensed-Dispersed Phase**

    ---

    Liquid droplets or solid particles with temperature-dependent or fixed properties. Relevant for sprays, particle-laden flows, and multi-phase systems.

    [Condensed](./condensed-solid.md)

-   :material-wall: **Solid Phase**

    ---

    Wall and structural materials with database-driven or fixed thermal properties (cp, k, ρ). Used for conjugate heat transfer and thermal protection.

    [Solid](./condensed-solid.md)

</div>

---

## Backends

GPB supports multiple backends for thermodynamic and transport properties, as well as chemical kinetics. The user can select the backend on a per-phase basis.

See the [Database Reference](../../databases/index.md) for a complete list of supported backends and their features.

---

## Usage

Run GPB from the command line in the simulation root folder:

```bash
ATLAS GPB
```

## Input

The INI file can contain an arbitrary number of phase sections named `[GPB-Phase1]`, `[GPB-Phase2]`, etc. GPB reads them in order until a section is not found.

```ini
[GPB-Phase1]
name = gas
type = ideal-gas
...

[GPB-Phase2]
name = particles
type = condensed-dispersed
...
```

See [Input Reference](./input-reference) for full per-type information.

## Output

Property files are written to `fromATLAStoSolver/`.

See [Output Files](./output) for full per-type information.

---
