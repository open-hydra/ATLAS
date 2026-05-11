# ATLAS Tools — User Guide

Each page opens with **what the tool can do**, then covers how to configure it.

<div class="grid cards" markdown>

-   :material-atom-variant: **GPB**

	---

	Build thermodynamic and transport property tables for gas, real-fluid, condensed, and solid phases. Supports finite-rate chemistry, equilibrium calculations, and multiple thermodynamic backends.

	[Open GPB Guide](./gpb/index.md)

-   :material-dock-left: **BCB**

	---

	Apply boundary conditions to mesh face groups: inflow, outflow, walls (adiabatic or isothermal), symmetry, chimera, and periodic connections.

	[Open BCB Guide](./bcb/index.md)

-   :material-cube-outline: **ICB**

	---

	Initialize solution fields with uniform states, 1-D profiles, grid interpolation, or import from a previous run.

	[Open ICB Guide](./icb/index.md)

-   :material-ruler-square-compass: **STB**

	---

	Generate area schedules and geometry data for variable-area duct and nozzle configurations.

	[Open STB Guide](./stb/index.md)

<!-- -   :material-chart-line: **KAnT**

	---

	Run zero-dimensional reactor simulations: counterflow flames, equilibrium, ignition delay, and time-evolution.

	[Open KAnT Guide](./kant/index.md) -->

</div>

## Common Workflow

Assumed that ATLAS is reachable in the shell

```bash

# 1 — build phase property tables (first step mandatory)
ATLAS GPB

# 2 — build boundary condition blocks
ATLAS BCB

# 3 — build initial condition fields
ATLAS ICB

# 4 — build source terms (optional)
ATLAS STB
```

!!! warning
	The order shown above is typical for a cold-start Hydra simulation case and may change except for GPB that must be the first: ICB and BCB uses the outoput files provided by GPB.

For worked examples, see the [Tutorials](../tutorials/index.md).
