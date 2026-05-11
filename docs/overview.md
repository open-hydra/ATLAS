---
title: Overview
---

# Overview

ATLAS (**A**uxiliary **T**ools **L**ibrary for hydr**A** **S**olvers) is an open-source pre-processing toolchain for the Hydra CFD suite, written in modern Fortran and Python. It provides a set of specialised tools — each independently runnable — that prepare the boundary conditions, initial conditions, and phase data consumed by the Hydra solvers.

---

## Hydra CFD Suite

ATLAS is the **pre-processor** of **Hydra** — an integrated suite of tools for multi-physics simulation of complex systems.

| Component | Role | Status |
|-----------|------|--------|
| [**ATLAS**](https://github.com/open-hydra/ATLAS) | Pre-processor: initial & boundary conditions, thermodynamic/chemical data | This package |
| **MOSE** | Solver: compressible Euler/Navier–Stokes with finite-rate chemistry | Separate package |

!!! info "ATLAS within Hydra"
    ATLAS is a powerful tool. However, it is not indispensable: you can write your own input files if you prefer, or use a different pre-processor.

---

## ATLAS Capabilities

ATLAS groups its functionality into independent tools:

<div class="grid cards" markdown>

-   :material-table-cog:{ .lg .middle } __GPB — General Phase Builder__

    ---

    **Python** &nbsp;·&nbsp; GPB evaluates and tabulates thermodynamic and transport properties for every phase type: ideal gas, real fluids, and solids. Its output tables drive all Hydra solvers.

    [:octicons-arrow-right-24: GPB User Guide](./user-guide/gpb/index.md)

-   :material-vector-line:{ .lg .middle } __BCB — Boundary Condition Builder__

    ---

    **Fortran** &nbsp;·&nbsp; Writes boundary condition data blocks for all supported BC types (inflow, outflow, wall, symmetry, periodic).

    [:octicons-arrow-right-24: BCB User Guide](./user-guide/bcb/index.md)

-   :material-database-arrow-up:{ .lg .middle } __ICB — Initial Condition Builder__

    ---

    **Fortran** &nbsp;·&nbsp; Initialises the fields from user-defined states (uniform, interpolated, or restarted from a previous solution) and writes the IC data blocks consumed by the solver at startup.

    [:octicons-arrow-right-24: ICB User Guide](./user-guide/icb/index.md)

-   :material-lightning-bolt:{ .lg .middle } __STB — Source Terms Builder__

    ---

    **Fortran** &nbsp;·&nbsp; Builds volumetric source term data blocks (mass addition, energy deposition, momentum forcing).

    [:octicons-arrow-right-24: STB User Guide](./user-guide/stb/index.md)

<!-- -   :material-flask:{ .lg .middle } __KAnT — Kinetics and Thermodynamics Tester__

    ---

    **Python** &nbsp;·&nbsp; Runs 0D and 1D Cantera simulations (ignition delay, counterflow flame, chemical equilibrium) to validate chemical mechanisms and thermodynamic data before committing them to a full CFD run.

    [:octicons-arrow-right-24: KAnT User Guide](./user-guide/kant/index.md) -->

</div>

ATLAS hosts two language stacks that coexist in the same CMake build tree:

- **Fortran 2008** — BCB, ICB, STB, and all shared Fortran libraries (ORION, NewCEA, FiNeR)
- **Python 3** — GPB and all shared Python libraries (PiNeR, Cantera, CoolProp)

---

## Code Dependencies

### Required libraries

| Library | Role | Source |
|---------|------|--------|
| [Cantera](https://github.com/Cantera/cantera) | Thermodynamic & chemical kinetics evaluation (GPB, KAnT) | conda / pip |
| [CoolProp](http://www.coolprop.org) | Real-fluid equations of state (GPB real-fluid phase) | conda / pip |
| [NewCEA](https://github.com/MarcoGrossi92/NewCEA) | NASA CEA chemical equilibrium interface (GPB) | Bundled submodule |
| [ORION](https://github.com/MarcoGrossi92/ORION) | Multi-format I/O — Tecplot, VTK, Plot3D (BCB, ICB, STB) | Bundled submodule |
| [FiNeR](https://github.com/szaghi/FiNeR) | Fortran INI configuration file parser (BCB, ICB, STB) | Bundled submodule |
| [PiNeR](https://github.com/MarcoGrossi92/PiNeR) | Python INI configuration file parser (GPB, KAnT) | conda / pip |

### Optional libraries

| Library | Role |
|---------|------|
| OpenMP | Shared-memory thread parallelism in Fortran tools |
| TecIO | Binary Tecplot output |

### Build toolchain

| Tool | Minimum version |
|------|----------------|
| CMake | 3.23 |
| Fortran compiler | GNU gfortran 11+ or Intel ifx/ifort |
| Python | 3.9+ |
| Conda | Recommended for the Python environment (`ct-env.yaml`) |

---

## Documentation Guide

| Section | What you'll find |
|---------|-----------------|
| [**Getting Started**](getting-started/index.md) | Installation, prerequisites, and first run |
| [**User Guide**](user-guide/index.md) | Running each tool, configuring input files, output formats |
| [**Databases**](databases/index.md) | Thermodynamic, transport, and chemistry databases |
| [**Tutorials**](tutorials/index.md) | Step-by-step examples from setup to result |
| [**Developer Guide**](development/index.md) | Repository architecture, testing framework, contribution guidelines |
| [**About**](about/index.md) | License, acknowledgements, and contributors |

---

## License

ATLAS is free and open-source software released under the **[GNU General Public License v3.0](about/license.md)** (GPL-3.0).

| Permission | |
|------------|-|
| :white_check_mark: Use freely | For any purpose, including commercial |
| :white_check_mark: Modify | Change the source code as needed |
| :white_check_mark: Distribute | Share original or modified versions |
| :white_check_mark: Patent grant | Contributors grant patent rights |
| :warning: Share-alike | Derivative works must use GPL-3.0 |
| :warning: Disclose source | Source code must be provided when distributing |

Full license text: [`LICENSE`](about/license.md)

