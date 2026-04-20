# Project Structure

Understanding the ATLAS codebase organization.

## Directory Layout

```
ATLAS/
├── CMakeLists.txt          # Main CMake configuration
├── CMakePresets.json       # CMake presets
├── bin/                    # Compiled executables
│   ├── BCB                 # Boundary Condition Block
│   ├── ICB                 # Initial Condition Block
│   └── STB                 # [Description needed]
│
├── src/                    # Source code
│   ├── hydra-tools/        # TODO: Document
│   └── KAnT/               # TODO: Document
│
├── lib/                    # Library code
│   ├── NewCEA/             # CEA (Chemical Equilibrium & Applications)
│   ├── ORION/              # ORION library
│   ├── PiNeR/              # TODO: Document
│   └── third_party/        # Third-party dependencies
│
├── build/                  # Build output directory
│   ├── lib/                # Compiled libraries
│   ├── modules/            # Fortran module files (.mod)
│   └── src/                # Intermediate build files
│
├── test/                   # Test suite
│   ├── BCB/                # BCB tests
│   ├── ICB/                # ICB tests
│   ├── KAnT/               # KAnT tests
│   └── GPB/                # GPB tests
│
├── cmake/                  # CMake modules and helpers
│   ├── FindOpenMP_Fortran.cmake
│   ├── SetCompileFlag.cmake
│   ├── SetFortranFlags.cmake
│   └── SetParallelizationLibrary.cmake
│
├── database/               # Data files
│   ├── chemistry/          # Chemical database
│   ├── thermo/             # Thermodynamic data
│   └── transport/          # Transport data
│
├── docs/                   # Documentation (this project)
├── scripts/                # Utility scripts
└── GUI/                    # GUI components if applicable
    └── GUI.py
```

## Key Components

TODO: Add detailed descriptions for each component

### BCB - Boundary Condition Block
**Purpose**: [Description needed]
**Location**: `src/`, `lib/`
**Entry Point**: `bin/BCB`
**Key Files**:
- TODO: List key source files

### ICB - Initial Condition Block
**Purpose**: [Description needed]
**Location**: `src/`, `lib/`
**Entry Point**: `bin/ICB`
**Key Files**:
- TODO: List key source files

### STB - [Name]
**Purpose**: [Description needed]
**Location**: `src/`, `lib/`
**Entry Point**: `bin/STB`
**Key Files**:
- TODO: List key source files

### Supporting Libraries

#### ORION
**Purpose**: [Description needed]
**Location**: `lib/ORION/`

#### NewCEA
**Purpose**: [Description needed]
**Location**: `lib/NewCEA/`

#### PiNeR
**Purpose**: [Description needed]
**Location**: `lib/PiNeR/`

## Source File Organization

TODO: Describe Fortran module organization

```
src/
├── bcb/                 # BCB component
│   ├── bc_mod.f90
│   ├── bc_builder_mod.f90
│   └── ...
├── icb/                 # ICB component
│   ├── ic_mod.f90
│   ├── ic_builder_mod.f90
│   └── ...
├── common/              # Shared utilities
│   ├── config_mod.f90
│   ├── io_mod.f90
│   └── ...
└── ...
```

## Build System

- **Build Tool**: CMake 3.15+
- **Compilation**: Fortran 2008+
- **Parallelization**: OpenMP / MPI (optional)

### Key CMake Modules

- `FindOpenMP_Fortran.cmake`: OpenMP detection
- `SetFortranFlags.cmake`: Compiler flags
- `SetParallelizationLibrary.cmake`: Parallel setup

## Dependencies

### External Libraries
TODO: Document external dependencies

- TODO: Library 1
- TODO: Library 2

### Third-Party Code
- Location: `lib/third_party/`
- TODO: List and document third-party code

## Testing Structure

```
test/
├── CMakeLists.txt       # Test configuration
├── test.sh              # Test runner script
├── BCB/                 # BCB tests
├── ICB/                 # ICB tests
├── KAnT/                # KAnT tests
├── 1D/, 2D/, 3D/       # Dimensional test cases
└── common/              # Shared test utilities
```

## Database

TODO: Document database files

```
database/
├── chemistry/           # Chemical species data
├── thermo/              # Thermodynamic properties
└── transport/           # Transport coefficients
```

## Documentation

- **Source**: `docs/` (You are here!)
- **Build**: VitePress
- **Output**: Static HTML

## Adding New Components

TODO: Document process for adding new functionality

1. Create source files in appropriate `src/` subdirectory
2. Update relevant `CMakeLists.txt`
3. Add tests in `test/` directory
4. Update documentation

---

See: [Build Instructions](./build), [Testing](./testing)
