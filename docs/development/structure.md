# Project Structure

Understanding the ATLAS codebase organization.

## Directory Layout

```
ATLAS/
├── CMakeLists.txt          # Main CMake configuration
├── install.sh              # Build driver; also generates CMakePresets.json
├── ATLAS.sh                # Tool launcher (ATLAS BCB, ATLAS GPB, ...)
├── ct-env.yaml             # Conda environment for the Python tools
│
├── src/                    # Source code
│   ├── BCB/                # Boundary Condition Builder (Fortran)
│   ├── ICB/                # Initial Condition Builder (Fortran)
│   ├── MDB/                # Mesh Decomposition Builder (Fortran)
│   ├── STB/                # Source Terms Builder (Fortran)
│   ├── GPB/                # General Phase Builder (Python)
│   └── common/             # Shared Fortran utilities
│
├── bin/                    # Compiled executables (BCB, ICB, MDB, STB)
│
├── lib/                    # Library code
│   ├── cea/                # CEA (Chemical Equilibrium & Applications)
│   ├── ORION/              # ORION multi-format I/O toolkit
│   ├── PiNeR/              # PiNeR Python INI parser
│   └── third_party/FiNeR/  # FiNeR Fortran INI reader
│
├── test/                   # Test cases, one folder per case
│   ├── CMakeLists.txt      # Registers every case with CTest
│   └── BCB/ ICB/ MDB/ STB/ GPB/ KAnT/
│
├── database/               # Runtime data
│   ├── chemistry/          # Reaction mechanisms (Cantera YAML)
│   ├── thermo/             # Thermodynamic property data
│   ├── transport/          # Transport coefficient data
│   ├── KAnT/               # KAnT resources
│   └── scripts/            # Database maintenance scripts
│
├── cmake/                  # CMake modules (compiler flags, OpenMP detection)
├── GUI/                    # BCB GUI (PyQt)
├── docs/                   # This documentation
├── scripts/                # Utility scripts
└── build/                  # Build output (created by CMake, git-ignored)
```

## Key Components

| Tool | Purpose | Location | Entry point | Input → Output |
|---|---|---|---|---|
| **BCB** | Builds multi-block boundary-condition data from input specifications | `src/BCB/` | `bin/BCB` | INI + mesh → solver BC files |
| **ICB** | Generates spatially varying initial-condition fields | `src/ICB/` | `bin/ICB` | INI + mesh → Tecplot/VTK fields |
| **MDB** | Splits mesh and BC data across parallel partitions | `src/MDB/` | `bin/MDB` | Mesh + BC files → per-partition files |
| **STB** | Computes spatially varying source terms | `src/STB/` | `bin/STB` | Mesh + INI → source-term data |
| **GPB** | Builds thermodynamic phase-property tables from CEA and Cantera | `src/GPB/` | `ATLAS GPB` | INI + databases → thermo/transport tables |

Each tool's internal file layout follows the same conventions — see
[Source Layout](./fortran-guide.md#source-layout) in the Fortran Development Guide.

### Supporting Libraries

| Library | Purpose | Location | Reference |
|---|---|---|---|
| **CEA** | NASA chemical-equilibrium and thermodynamic property solver (>2000 species) | `lib/cea/` | [nasa/cea](https://github.com/nasa/cea) |
| **ORION** | Multi-format structured multi-block I/O (Tecplot binary, VTK, PLOT3D) | `lib/ORION/` | [MarcoGrossi92/ORION](https://github.com/MarcoGrossi92/ORION) |
| **FiNeR** | Fortran INI parser, used by all four Fortran tools | `lib/third_party/FiNeR/` | [szaghi/FiNeR](https://github.com/szaghi/FiNeR) |
| **PiNeR** | Python INI parser, used by GPB | `lib/PiNeR/` | [MarcoGrossi92/PiNeR](https://github.com/MarcoGrossi92/PiNeR) |

Cantera and CoolProp are external Python dependencies used by GPB for kinetics
and real-fluid properties respectively.

## Build System

- **Build Tool**: CMake 3.23+
- **Languages**: Fortran (core), C++ (optional), Python (tools)
- **Supported Compilers**: GNU Fortran (≥9), Intel ifort (≥2021)
- **Presets**: `default` (all components, Intel/GNU)
- **Parallelization**: OpenMP (optional, off by default); MPI is not currently wired up

### CMake Preset Configuration

The `CMakePresets.json` defines the `default` preset with:
- Compiler paths (GFortran, C++)
- Library paths (ORION, FiNeR, CEA, etc.)
- Optional features: TecIO, OpenMP

### Key CMake Modules

- `FindOpenMP_Fortran.cmake` — OpenMP detection for Fortran
- `SetFortranFlags.cmake` — Compiler-specific optimization flags
- `SetParallelizationLibrary.cmake` — Parallel backend setup

## Testing Structure

Tests are **case folders**, not test source files: each holds an `input.ini`,
its input data, and a `reference/` directory of expected outputs. A test runs
the tool in that folder and diffs the produced files against `reference/`.

```
test/
├── CMakeLists.txt     # every registered case, one add_test() each
├── BCB/  ICB/  MDB/  STB/  GPB/  KAnT/
└── <case>/            # e.g. BCB/IG-basic
    ├── input.ini      # the case definition
    ├── mesh.tec       # input data (varies by tool)
    └── reference/     # expected output, diffed by the test
```

**Running tests**:
```bash
cd build
ctest --output-on-failure
ctest -L BCB                  # run one tool's cases (labels: BCB, ICB, MDB, STB, GPB)
ctest -j 4                    # run in parallel
```

See [Testing](./testing.md) for the registered cases and what each one proves.

## Database

The `database/` tree stores runtime data and scripts used by GPB/KAnT workflows.

```
database/
├── chemistry/           # Reaction mechanisms and chemistry-related datasets
├── thermo/              # Thermodynamic property inputs/tables
├── transport/           # Transport-coefficient inputs/tables
├── KAnT/                # KAnT package data/resources
└── scripts/             # Data preparation or helper scripts
```

Notes:

- Keep generated artifacts out of `database/`; commit only source data and scripts.
- When updating database content, document provenance and units in the same PR.

## Documentation

- **Source**: `docs/` (You are here!)
- **Build**: MkDocs + Material for MkDocs
- **Output**: Static HTML

Local commands:

```bash
mkdocs serve
mkdocs build
```

## Adding New Components

For new tool features or modules, use this checklist:

1. Create source files in appropriate `src/` subdirectory
2. Update relevant `CMakeLists.txt`
3. Add tests in `test/` directory
4. Update documentation
5. Rebuild and run focused regression tests (`ctest -R <pattern> --output-on-failure`)
6. If adding new runtime inputs, add a reference case under `test/` and expected output files

---

See: [Build Instructions](./build.md), [Testing](./testing.md)
