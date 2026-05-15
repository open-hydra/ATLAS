# Development

ATLAS is a mixed-language project. Pre-processing tools are implemented in **Fortran 2008** (BCB, ICB, STB) and **Python 3** (GPB, KAnT). Both language tracks share the same CMake build system.

## Language Tracks

| Track | Tools | Entry point |
|-------|-------|-------------|
| [Fortran](./fortran-guide) | BCB, ICB, STB | CMake → `make` |
| [Python](./python-guide) | GPB, KAnT | `python -m <package>` |

## Quick Links

- **[Build Instructions](./build)** — Compile the Fortran tools from source
- **[Fortran Development Guide](./fortran-guide)** — Modules, types, coding conventions
- **[Python Development Guide](./python-guide)** — Package structure, conventions, testing
- **[Fortran Module Reference](./fortran-modules)** — All `.mod` files and their purpose
- **[Python Package Reference](./python-packages)** — All Python packages and public APIs
- **[Project Structure](./structure)** — Source tree overview
- **[Contributing Guide](./contributing)** — Branching, PRs, review process
- **[Versioning](./versioning)** — Semantic versioning rules for change classification
- **[Testing](./testing)** — Running the test suite
- **[Code Style](./code-style)** — Naming and style conventions

## Setting Up Development Environment

### Prerequisites

**Fortran Tools:**
- GFortran ≥ 9 or Intel `ifort` ≥ 2021
- CMake ≥ 3.23
- Git (for submodule management)
- OpenMP (optional, enabled by default on macOS/Linux)

**Python Tools:**
- Python ≥ 3.9
- Required packages: `cantera`, `coolprop`, `numpy<2`, `pyyaml`

### Quick Setup

```bash
# Clone repository
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS

# Initialize submodules (dependencies: ORION, FiNeR, CEA, etc.)
git submodule update --init --recursive

# Create development branch
git checkout -b feature/my-feature

# Build for development (Fortran)
mkdir build
cd build
cmake --preset default
cmake --build .
```

### Python Environment (Optional)

```bash
# Using the bundled conda environment
conda env create -f ct-env.yaml
conda activate ct-env

# Or install requirements manually
pip install cantera coolprop 'numpy<2' pyyaml

# Set ATLAS environment variable
export ATLASDIR=/path/to/ATLAS
```

## Development Workflow

1. **Create a feature branch**: `git checkout -b feature/my-feature`
2. **Make changes** following [Code Style Guide](./code-style)
3. **Build your changes**: `cd build && cmake --build .`
4. **Run tests**: `ctest --output-on-failure`
5. **Commit with clear messages**: `git commit -m "Add feature X"`
6. **Submit pull request** with description of changes
7. **Address review feedback** and push updates to same branch
8. **Merge once approved** by maintainers

## Key Components

- **BCB** — Boundary Condition Builder: Constructs structured multi-block boundary condition data
- **ICB** — Initial Condition Builder: Generates initial condition field data for simulations
- **STB** — Source Terms Builder: Computes source terms for governing equations
- **GPB** — General Phase Builder: Python tool for building thermodynamic phase properties
- **Core Libraries**:
  - **CEA** (Chemical Equilibrium & Applications): NASA thermodynamic property solver
  - **ORION** (I/O Repository): Multi-format data I/O toolkit (Tecplot, VTK, PLOT3D)
  - **FiNeR** (Fortran INI Reader): INI configuration file parser
  - **PiNeR** (Python INI Reader): Python INI parser for GPB configuration

## Documentation

- **[Fortran API & Module Documentation](./fortran-modules)** — All compiled Fortran modules
- **[Project Structure](./structure)** — Source tree and component overview
- **[Fortran Development](./fortran-guide)** — Fortran coding patterns and conventions
- **[Python Development](./python-guide)** — Python package layout and patterns

## Getting Help

- **GitHub Discussions** — Ask questions and discuss development
- **GitHub Issues** — Report bugs or request features
- **Code Review** — Ask questions in pull request reviews
- **[Contributing Guide](./contributing)** — Detailed contribution workflow
- **Existing Code** — Study relevant modules and tests for patterns

---

**Ready to start?** See [Build Instructions](./build).
