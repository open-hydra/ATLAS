# ATLAS Documentation

ATLAS is a pre-processing toolchain for **Hydra**, an in-house multi-physics CFD solver. It provides a set of specialised tools — each independently runnable — that prepare the boundary conditions, initial conditions, phase data, and solver setup consumed by Hydra.

## Tools at a Glance

| Tool | Language | Role |
|------|----------|------|
| [GPB](/user-guide/gpb/) | Python | General Phase Builder — generates thermodynamic / transport property tables for all phase types |
| [BCB](/user-guide/bcb/) | Fortran | Boundary Condition Builder — writes BC data blocks for Hydra |
| [ICB](/user-guide/icb/) | Fortran | Initial Condition Builder — writes IC data blocks, supports interpolation and restart |
| [STB](/user-guide/stb/) | Fortran | Setup Tool Builder — area schedule and geometry preprocessing |
| [KAnT](/user-guide/kant/) | Python | Kinetics and Thermodynamics post-processor |

## Quick Navigation

| I want to… | Go to… |
|------------|--------|
| Install ATLAS | [Getting Started](/getting-started/) |
| Run my first case | [Quick Start](/getting-started/quick-start) |
| Understand a tool | [User Guide](/user-guide/) |
| Follow a step-by-step example | [Tutorials](/tutorials/) |
| Understand the physics | [Theory Guide](/theory/) |
| Contribute code | [Development](/development/) |
| Look up an API | [API Reference](/api-reference/) |

## Project Organisation

ATLAS hosts two language stacks that coexist in the same CMake build tree:

- **Fortran 2008** — BCB, ICB, STB and all shared Fortran libraries (ORION, NewCEA, …)
- **Python 3** — GPB and KAnT, invoked as `python -m GPB` / `python -m KAnT`

See [Development → Overview](/development/) for the full picture.

