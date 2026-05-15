<p align="center">
	<h1 align="center">ATLAS</h1>
	<p align="center"><b>Auxiliary Toolbox and Libraries for an hydrA Solvers</b></p>
</p>

<p align="center">
	<a href="https://github.com/open-hydra/ATLAS/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-blue.svg" alt="License: GPLv3"></a>
	<a href="https://open-hydra.github.io/ATLAS/"><img src="https://img.shields.io/badge/docs-online-brightgreen.svg" alt="Documentation"></a>
	<img src="https://img.shields.io/badge/language-Fortran-734f96.svg" alt="Language: Fortran">
	<img src="https://img.shields.io/badge/language-Python-3776ab.svg" alt="Language: Python">
</p>

---

ATLAS is an open-source pre-processing toolbox for Hydra simulation workflows. It combines modern Fortran executables and Python tools to prepare solver-ready input data, including phase-property tables, boundary conditions, initial conditions, source terms, and kinetics-validation datasets.

## Features

- **General Phase Builder (GPB)** - builds thermodynamic, transport, and chemistry-aware phase tables.
- **Boundary Condition Builder (BCB)** - maps block faces to BC models and writes solver-ready BC files.
- **Initial Condition Builder (ICB)** - generates initialized fields from uniform, profile-based, interpolation, or nozzle strategies.
- **Source Terms Builder (STB)** - builds volumetric source term datasets for coupled simulations.
- **KAnT (Kinetic Analyzer and Tester)** - runs 0-D and 1-D chemistry analyses (equilibrium, ignition delay, time evolution, counterflow flame).
- **Workflow chaining** - tools can be run independently or in sequence from a shared `input.ini`.

## Quick Start

### Prerequisites

| Requirement | Details |
|---|---|
| **CMake** | >= 3.23 |
| **Compilers** | GNU (`gfortran`, `g++`) or Intel (`ifx`, `icpx`) |
| **Shell tools** | `bash`, `git` |
| **Conda** | Recommended for Python tooling (GPB/KAnT), optional with `--no-conda` |

### Build

```bash
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS

# Default build (creates ct-env unless --no-conda is used)
./install.sh build

# Explicit compiler family
./install.sh build --compilers=gnu

# Optional features
./install.sh build --use-openmp --use-tecio
```

See the [Installation Guide](docs/getting-started/installation.md) for all options and troubleshooting.

### Run a Minimal Workflow

From a case directory:

```bash
ATLAS GPB
ATLAS BCB
ATLAS ICB
```

Combined execution with one shared input file:

```bash
ATLAS GPB BCB ICB
```

Chemistry validation:

```bash
ATLAS KAnT
```

See the [Quick Start](docs/getting-started/quick-start.md) for a full walkthrough.

## Dependencies

ATLAS uses companion libraries, typically managed as Git submodules:

| Library | Role |
|---|---|
| [ORION](https://github.com/MarcoGrossi92/ORION) | Multi-format I/O support |
| [FiNeR](https://github.com/szaghi/FiNeR) | INI parsing |
| [cea](https://github.com/nasa/cea)  | Chemical equilibrium and applications |
| [PiNeR](https://github.com/MarcoGrossi92/PiNeR) | Python configuration/utilities |

Optional ecosystem components: **OpenMP**, **TecIO**, and Python packages from `ct-env.yaml`.

## Project Structure

```text
ATLAS/
|- src/                  # Fortran core and tool sources
|- database/             # Databases and KAnT package
|- docs/                 # MkDocs documentation source
|- test/                 # Reference and regression cases
|- scripts/              # Build and workflow helpers
|- lib/                  # Dependencies/submodules
|- bin/                  # Built executables (after build)
|- install.sh            # Build helper script
|- CMakeLists.txt
`- CMakePresets.json
```

## Documentation

Online docs: **[open-hydra.github.io/ATLAS](https://open-hydra.github.io/ATLAS/)**

In-repo docs entry points:

- [Getting Started](docs/getting-started/index.md)
- [User Guide](docs/user-guide/index.md)
- [Databases](docs/databases/index.md)
- [Tutorials](docs/tutorials/index.md)
- [Development Guide](docs/development/index.md)

Tool-specific user guides:

- [GPB](docs/user-guide/gpb/index.md)
- [BCB](docs/user-guide/bcb/index.md)
- [ICB](docs/user-guide/icb/index.md)
- [STB](docs/user-guide/stb/index.md)
- [KAnT](docs/user-guide/kant/index.md)

## Testing

Reference cases are under `test/`:

- `test/GPB/`
- `test/BCB/`
- `test/ICB/`
- `test/KAnT/`

## License

ATLAS is released under the [GNU General Public License v3.0](LICENSE).

## Contributing

See [Contributing](docs/development/contributing.md) for development workflow and contribution guidelines.
