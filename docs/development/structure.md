# Project Structure

Understanding the ATLAS codebase organization.

## Directory Layout

```
ATLAS/
├── CMakeLists.txt          # Main CMake configuration
├── CMakePresets.json       # CMake presets
├── bin/                    # Compiled executables
│   ├── BCB                 # Boundary Condition Builder
│   ├── ICB                 # Initial Condition Builder
│   └── STB                 # Source Terms Builder
│
├── src/                    # Source code
│   ├── BCB/                # Boundary Condition Builder (Fortran)
│   ├── ICB/                # Initial Condition Builder (Fortran)
│   ├── STB/                # Source Terms Builder (Fortran)
│   ├── GPB/                # General Phase Builder (Python)
│   ├── common/             # Shared Fortran utilities
│   └── CMakeLists.txt
│
├── lib/                    # Library code
│   ├── cea/                # CEA (Chemical Equilibrium & Applications)
│   ├── ORION/              # ORION multi-format I/O toolkit
│   ├── PiNeR/              # PiNeR Python INI parser
│   └── third_party/        # Third-party dependencies
│       └── FiNeR/          # FiNeR Fortran INI reader
│
├── build/                  # Build output directory (created by CMake)
│   ├── lib/                # Compiled libraries
│   ├── modules/            # Fortran module files (.mod)
│   └── src/                # Intermediate build files
│
├── test/                   # Test suite
│   ├── CMakeLists.txt      # Test build configuration
│   ├── BCB/                # BCB tests
│   ├── ICB/                # ICB tests
│   ├── GPB/                # GPB Python tests
│   ├── common/             # Shared test utilities
│   └── samples/            # Reference test cases
│
├── cmake/                  # CMake modules and helpers
│   ├── FindOpenMP_Fortran.cmake
│   ├── SetCompileFlag.cmake
│   ├── SetFortranFlags.cmake
│   └── SetParallelizationLibrary.cmake
│
├── database/               # Data files and resources
│   ├── chemistry/          # Chemical species database
│   ├── thermo/             # Thermodynamic property data
│   └── transport/          # Transport coefficient data
│
├── docs/                   # Documentation (this project)
├── scripts/                # Utility and build scripts
└── ct-env.yaml             # Conda environment for Python tools
```

## Key Components

### BCB - Boundary Condition Builder
**Purpose**: Constructs multi-block boundary condition data structures from input specifications.
**Language**: Fortran 2008
**Location**: `src/BCB/`
**Entry Point**: `bin/BCB` executable
**Key Modules**:
- `bc_mod` — Boundary condition data types
- `bc_block_mod` — Block-level BC data structures
- `bc_builder_mod` — BC construction logic
- `bc_connection_mod` — Standard block connectivity
- `bc_chimera_mod` — Chimera overset connectivity
**Input/Output**: INI configuration → Tecplot/VTK binary files

### ICB - Initial Condition Builder
**Purpose**: Generates spatially-varying initial condition fields for simulations.
**Language**: Fortran 2008
**Location**: `src/ICB/`
**Entry Point**: `bin/ICB` executable
**Key Modules**:
- `ic_block_mod` — Initial condition block data type
- `ic_builder_mod` — Top-level IC dispatch
- `ic_builder_ig_mod` — Ideal-gas IC builder
- `ic_builder_rf_mod` — Real-fluid IC builder
- `ic_builder_sp_mod` — Solid-particle IC builder
**Input/Output**: INI + base mesh → Tecplot/VTK fields

### STB - Source Terms Builder
**Purpose**: Computes spatially-varying source terms for governing equations.
**Language**: Fortran 2008
**Location**: `src/STB/`
**Entry Point**: `bin/STB` executable
**Key Modules**:
- `area_variation_mod` — Area schedule computation
- `area_law` — Area law analytical forms
**Input/Output**: Mesh + configuration → Source term data

### GPB - General Phase Builder
**Purpose**: Python tool for building thermodynamic phase property tables from CEA and Cantera.
**Language**: Python 3.9+
**Location**: `src/GPB/`
**Entry Point**: `python -m GPB --input-file config.ini`
**Key Components**:
- INI parsers for phase configuration
- Builders for ideal-gas, real-fluid, and condensed phases
- Integration with CEA and Cantera libraries
**Input/Output**: INI configuration + databases → Thermo/transport tables

### Supporting Libraries

#### CEA (Chemical Equilibrium with Applications)
**Purpose**: NASA library for computing chemical equilibrium and thermodynamic properties.
**Location**: `lib/cea/`
**Language**: Fortran 2008 + C bindings
**Key Features**:
- Equilibrium solvers for complex mixtures
- Thermodynamic and transport property databases (>2000 species)
- Used by ICB and GPB for property lookups
**Reference**: https://github.com/nasa/cea

#### ORION (I/O Repository)
**Purpose**: Modular I/O toolkit for reading/writing structured multi-block scientific data.
**Location**: `lib/ORION/`
**Language**: Fortran 2008 + Python interface
**Supported Formats**: Tecplot binary, VTK, PLOT3D
**Used by**: BCB, ICB, STB for output data formatting
**Reference**: https://github.com/MarcoGrossi92/ORION

#### FiNeR (Fortran INI Reader)
**Purpose**: Fortran library for parsing INI configuration files.
**Location**: `lib/third_party/FiNeR/`
**Language**: Fortran 2008
**Used by**: STB, ICB for configuration file parsing
**Reference**: https://github.com/szaghi/FiNeR

#### PiNeR (Python INI Reader)
**Purpose**: Python library for parsing INI configuration files.
**Location**: `lib/PiNeR/`
**Language**: Python 3.6+
**Used by**: GPB for configuration file parsing
**Reference**: https://github.com/MarcoGrossi92/PiNeR

## Source File Organization

```
src/
├── BCB/                     # Boundary Condition Builder
│   ├── BCB.f90              # Entry point (program)
│   ├── types_bc.f90         # BC data types
│   ├── types_block.f90      # Block data structures
│   ├── builder_block.f90    # Block-level construction
│   ├── builder_face.f90     # Face-level construction
│   ├── builder_*.f90        # Type-specific builders
│   ├── connection_*.f90     # Standard/Chimera connectivity
│   ├── io_*.f90             # Input/output routines
│   └── bc_names.f90         # BC type constants
├── ICB/                     # Initial Condition Builder
│   ├── ICB.f90              # Entry point (program)
│   ├── types_block.f90      # IC block data type
│   ├── builder.f90          # Top-level dispatcher
│   ├── builder_*.f90        # Phase-specific builders
│   ├── interpolation_*.f90  # Interpolation kernels
│   └── io_*.f90             # I/O routines
├── STB/                     # Source Terms Builder
│   ├── STB.f90              # Entry point (program)
│   └── area_variation.f90   # Area schedule computation
├── GPB/                     # General Phase Builder (Python)
│   ├── __main__.py          # CLI entry point
│   ├── config.py            # Configuration constants
│   ├── input_registry.py    # INI section dispatcher
│   ├── ini/                 # INI parsing subpackage
│   ├── ideal_gas/           # Ideal-gas builders
│   ├── condensed/           # Condensed/solid builders
│   └── real_fluid/          # Real-fluid builders
└── common/                  # Shared utilities
    ├── config.f90           # Global configuration
    ├── global_mod.f90       # Global parameters
    ├── grid_mod.f90         # Grid handling
    ├── io_*.f90             # I/O utilities
    └── read_mesh_mod.f90    # Mesh reader
```

## Build System

- **Build Tool**: CMake 3.23+
- **Languages**: Fortran (core), C++ (optional), Python (tools)
- **Supported Compilers**: GNU Fortran (≥9), Intel ifort (≥2021)
- **Presets**: `default` (all components, Intel/GNU)
- **Parallelization**: OpenMP (enabled by default), MPI (optional)

### CMake Preset Configuration

The `CMakePresets.json` defines the `default` preset with:
- Compiler paths (GFortran, C++)
- Library paths (ORION, FiNeR, CEA, etc.)
- Optional features: TecIO, OpenMP

### Key CMake Modules

- `FindOpenMP_Fortran.cmake` — OpenMP detection for Fortran
- `SetFortranFlags.cmake` — Compiler-specific optimization flags
- `SetParallelizationLibrary.cmake` — Parallel backend setup

## Dependencies

### External Libraries

- **CEA** — Chemical Equilibrium with Applications (included in `lib/cea/`)
- **ORION** — Multi-format I/O toolkit (included in `lib/ORION/`)
- **FiNeR** — Fortran INI reader (in `lib/third_party/FiNeR/`)
- **PiNeR** — Python INI reader (included in `lib/PiNeR/`)
- **Cantera** — Chemical kinetics (Python, for GPB)
- **CoolProp** — Fluid properties (Python, for real-fluid calculations)

### Third-Party Code

Location: `lib/third_party/`
- **FiNeR** v2.0.6+ — Fortran INI configuration parser
- Other build-system utilities

## Testing Structure

```
test/
├── CMakeLists.txt            # Test build configuration
├── BCB/                      # BCB unit and integration tests
│   ├── test_*.f90            # Fortran test programs
│   └── CMakeLists.txt
├── ICB/                      # ICB unit and integration tests
│   ├── test_*.f90            # Fortran test programs
│   └── CMakeLists.txt
├── GPB/                      # GPB Python tests
│   ├── test_*.py             # Python pytest cases
│   └── conftest.py           # Test fixtures
├── common/                   # Shared test utilities
└── samples/                  # Reference test cases
```

**Running Tests**:
```bash
cd build
ctest --output-on-failure
ctest -R BCB                  # Run BCB tests only
ctest -j 4                    # Run in parallel
```

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

See: [Build Instructions](./build), [Testing](./testing)
