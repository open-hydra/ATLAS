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

### The Solver Of Each Phase

Each phase GPB builds is the input of one Hydra solver; [Hydra](https://github.com/open-hydra) couples them.

| Phase (`[GPB-Phase*] type`) | Solver | |
|---|---|---|
| `ideal-gas`, `heavy-gas` | [MOSE](https://github.com/open-hydra/MOSE) | compressible Euler and Navier–Stokes on multi-block structured grids |
| `ideal-gas` on a 2-D mesh | [Q2D](https://github.com/open-hydra/Q2D) | the 2-D (x, y) cases, planar or axisymmetric |
| `real-fluid` | [ARES](https://github.com/open-hydra/ARES) | real-fluid flow |
| `solid` | [FUSS](https://github.com/open-hydra/FUSS) | heat conduction in solids |
| dispersed, `modeling = lagrangian` | [IGLOO](https://github.com/open-hydra/IGLOO) | Lagrangian particles |
| dispersed, `modeling = eulerian` | [ICE](https://github.com/open-hydra/ICE) | Eulerian condensed phase |

[GROOT](https://github.com/open-hydra/GROOT), the radiative-transfer solver of the suite, takes no ATLAS phase.
ATLAS is not required by the solvers: their input files can be written by hand or by another pre-processor.

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

The phases can also be set up interactively, with pickers over the chemistry
and thermo databases and a table per material, in the
[case-setup GUI](../gui.md):

```bash
ATLAS GUI
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

See [Input Reference](./input-reference.md) for full per-type information.

The pyrolysis-gas tables of a charring ablator (BC `506`) are given by `[GPB-Pyrolysis1]`, `[GPB-Pyrolysis2]`, ...
beside the phases: see [Pyrolysis-Gas Tables](./pyrolysis.md).

## Output

Property files are written to `fromATLAStoSolver/`.

See [Output Files](./output.md) for full per-type information.

---
