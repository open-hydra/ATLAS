# Fortran Development Guide

ATLAS Fortran tools (BCB, ICB, STB) target the **Fortran 2008** standard and are built with CMake.

## Prerequisites

- GFortran ≥ 9 or Intel `ifort` ≥ 2021
- CMake ≥ 3.15
- OpenMP (optional, for parallelism)

## Building

```bash
cd /path/to/ATLAS
mkdir build
cd build
cmake --preset default        # configure with default preset
cmake --build .               # compile all Fortran targets
```

Built executables are placed in `bin/`:

```
bin/BCB    — Boundary Condition Builder
bin/ICB    — Initial Condition Builder
bin/STB    — Source Terms Builder
```

## Source Layout

```
src/hydra-tools/
├── BCB/          — Boundary Condition Builder
│   ├── BCB.f90              — entry point (program)
│   ├── config.f90           — runtime configuration
│   ├── types_bc.f90         — BC data types
│   ├── types_block.f90      — block data types
│   ├── builder_block.f90    — block-level construction
│   ├── builder_face.f90     — face-level construction
│   ├── builder_200/300/400*/500.f90  — per-BC-type builders
│   ├── connection_*.f90     — standard / chimera connections
│   ├── io_*.f90             — I/O routines
│   └── bc_names.f90         — BC type name constants
├── ICB/          — Initial Condition Builder
│   ├── ICB.f90
│   ├── config.f90
│   ├── types_block.f90
│   ├── builder.f90
│   ├── builder_ig/dp/rf/sp.f90  — per-phase builders
│   ├── interpolation_*.f90
│   └── io_fields.f90
└── STB/          — Setup Tool Builder
    ├── STB.f90
    └── area_variation.f90
```

## Module Conventions

- Each logical unit lives in its own `.f90` file as a **module** or **submodule**.
- Modules are named `<name>_mod` (e.g., `bc_mod`, `config_mod`).
- Submodules follow the pattern `parent_mod::<child_mod_name>` and are defined in separate files or the parent module file.
- All `USE` statements include `ONLY` to make dependencies explicit.
- Derived types are defined in dedicated `types_*.f90` files; builder modules operate on them.
- Interface blocks use `INTENT` for all dummy arguments.
- Error handling uses `error stop` with descriptive messages for fatal errors.

### Example Module Structure

```fortran
module bc_mod
  !> Boundary condition data types and operations
  use iso_fortran_env, only: wp => real64
  use finer, only: file_ini
  
  implicit none
  private
  
  ! Public interface
  public :: bc_type, bc_type_from_ini
  
  !> BC data type
  type, public :: bc_type
    integer :: id
    character(len=256) :: name
    real(wp), allocatable :: data(:,:,:)
  end type bc_type
  
contains
  
  subroutine bc_type_from_ini(ini, bc)
    type(file_ini), intent(in) :: ini
    type(bc_type), intent(out) :: bc
    ! Implementation...
  end subroutine bc_type_from_ini
  
end module bc_mod
```

## Code Style

- 2-space indentation
- `IMPLICIT NONE` in every module / program unit
- `INTENT(IN/OUT/INOUT)` on all dummy arguments
- Error handling via `error stop` with a descriptive message

See [Code Style](./code-style) for the full conventions.
