# Fortran Development Guide

ATLAS Fortran tools (BCB, ICB, STB) target the **Fortran 2008** standard and are built with CMake.

## Prerequisites

- GFortran ≥ 9 or Intel `ifort` ≥ 2021
- CMake ≥ 3.23
- OpenMP (optional, off by default)

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

The tree is laid out in [Project Structure](./structure.md#directory-layout).
Each tool lives in `src/<TOOL>/` and follows the same shape:

| File pattern | Role |
|---|---|
| `<TOOL>.f90` | Entry point (`program`) |
| `config.f90` | Input registry and config loaders |
| `types_*.f90` | Derived types |
| `builder_*.f90` | Construction logic, usually submodules of the types module |
| `io_*.f90` | Readers and writers |

`src/common/` holds what the tools share: grid and phase handling, the INI,
mesh and ASCII-table readers, geometry and math helpers, and the input registry
that generates the input-reference pages.

To find the module a file defines, grep it — the names follow the convention below:

```bash
grep -rn "^\s*module " src/BCB/
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

See [Code Style](./code-style.md) for the full conventions.
