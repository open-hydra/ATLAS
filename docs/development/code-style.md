# Code Style

Coding standards and conventions for ATLAS.

## Language

ATLAS is written primarily in **Fortran 2008**.

## General Principles

- Readability first
- Self-documenting code
- Consistent style
- Clear variable names
- Proper commenting

## Fortran Style Guide

### File Organization

```fortran
! File header comment
! Purpose: Brief description
! Author: Your Name (optional)
! Date: YYYY-MM-DD (optional)

module my_module
  !
  ! Module description
  !
  use iso_fortran_env, only: wp => real64
  use other_module, only: func1, func2
  
  implicit none
  private
  
  ! Public interface
  public :: my_subroutine, my_function
  
  ! Type definitions
  type, public :: my_type
    integer :: id
    real(wp) :: value
  end type my_type
  
  ! Parameters
  integer, parameter :: MAX_SIZE = 1000
  
contains
  
  ! Implementations...

end module my_module
```

### Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| Modules | lowercase with underscores | `boundary_condition_mod.f90` |
| Types | lowercase with underscores | `type :: bc_node` |
| Variables | lowercase with underscores | `max_iterations` |
| Constants | UPPERCASE | `MAX_SIZE` |
| Subroutines | lowercase with underscores | `setup_domain()` |
| Functions | lowercase with underscores | `get_pressure()` |
| Interfaces | Descriptive names | `operator(+)`, `assignment(=)` |

### Variable Declaration

```fortran
implicit none

! Declare related variables together
integer :: i, j, k
real(wp) :: x, y, z

! Use intent for subroutine arguments
subroutine compute(input, output, status)
  type(my_type), intent(in) :: input
  type(my_type), intent(out) :: output
  integer, intent(out) :: status
end subroutine compute
```

### Indentation and Formatting

- Use **2 spaces** for indentation (not tabs)
- Maximum line length: **120 characters**
- One statement per line

```fortran
! Good
subroutine long_subroutine_name(argument1, argument2, &
                                argument3, argument4)
  integer, intent(in) :: argument1
  real(wp), intent(in) :: argument2
  real(wp), intent(out) :: argument3
  integer, intent(out) :: argument4
end subroutine long_subroutine_name

! Bad - too long
subroutine long_subroutine_name(argument1, argument2, argument3, argument4)
```

### Comments

```fortran
! Single line comment before code
i = 0  ! Inline comment

! Block comment for larger sections
! Describe what this code block does
! and why it's necessary.

! Use ! for comments (not c or *)
```

### Loops and Conditionals

```fortran
! Loop naming
do i = 1, n
  do j = 1, m
    if (condition) then
      ! Do something
    else if (other_condition) then
      ! Do something else
    else
      ! Default case
    end if
  end do
end do

! Named blocks for clarity
outer: do i = 1, n
  inner: do j = 1, m
    if (error_condition) exit outer
  end do inner
end do outer
```

### Functions and Subroutines

```fortran
! Function with result clause
pure function calculate_value(x) result(res)
  real(wp), intent(in) :: x
  real(wp) :: res
  
  res = x * x + 2.0_wp * x + 1.0_wp
end function calculate_value

! Subroutine with multiple arguments
subroutine process_array(input_array, output_array, n, status)
  real(wp), intent(in) :: input_array(:)
  real(wp), intent(out) :: output_array(:)
  integer, intent(in) :: n
  integer, intent(out) :: status
  
  integer :: i
  
  if (size(input_array) < n) then
    status = 1  ! Error
    return
  end if
  
  do i = 1, n
    output_array(i) = input_array(i) * 2.0_wp
  end do
  
  status = 0  ! Success
end subroutine process_array
```
end function calculate_value

! Subroutine with documentation
subroutine initialize(domain, status)
  !
  ! Initialize computational domain
  !
  ! Arguments:
  !   domain - [inout] domain structure to initialize
  !   status - [out] status code (0=success, non-zero=failure)
  !
  type(domain_type), intent(inout) :: domain
  integer, intent(out) :: status
  
  ! Implementation
  status = 0
end subroutine initialize
```

## Precision Control

Always use explicit precision:

```fortran
use iso_fortran_env, only: wp => real64

! Good
real(wp) :: value
real(wp) :: pi = acos(-1.0_wp)

! Bad
real :: value  ! Compiler-dependent precision
```

## Allocatable vs Fixed Arrays

```fortran
! Prefer allocatable for flexibility
real(wp), allocatable :: array(:,:)
allocate(array(nx, ny), stat=ierr)
if (ierr /= 0) stop "Memory allocation failed"
! ... use array ...
deallocate(array)

! Use fixed arrays only for fixed-size data
real(wp), parameter :: small_array(3) = [1.0_wp, 2.0_wp, 3.0_wp]
```

## Module Structure Best Practices

```fortran
module well_structured_module
  !
  ! Description of module
  !
  use iso_fortran_env, only: wp => real64
  use other_modules, only: needed_items
  
  implicit none
  private
  
  ! === Public Interface ===
  public :: public_function
  public :: public_subroutine
  public :: my_type
  
  ! === Type Definitions ===
  type, public :: my_type
    integer :: id
    real(wp) :: value
  end type my_type
  
  ! === Parameters ===
  integer, parameter :: DEFAULT_SIZE = 1000
  
  ! === Module Variables ===
  real(wp), save :: module_state = 0.0_wp
  
contains
  
  ! === Implementations ===
  function public_function() result(res)
    ! Implementation
  end function public_function
  
end module well_structured_module
```

## Common Pitfalls to Avoid

- ❌ Implicit types - always use `implicit none`
- ❌ Single character variable names (except loop counters)
- ❌ Magic numbers - use named constants
- ❌ Mixing implicit and explicit interfaces
- ❌ Not checking allocation/IO status
- ❌ Excessive module variables
- ✓ Use pure/elemental for side-effect free functions
- ✓ Use intent attributes
- ✓ Document complex algorithms

## Documentation

### Module Documentation

```fortran
module my_module
  !
  ! Module Purpose
  ! ==============
  ! Single line description
  !
  ! Description
  ! -----------
  ! More detailed explanation of module purpose,
  ! contents, and usage.
  !
  ! Author: Name (optional)
  ! Date: YYYY-MM-DD (optional)
  !
```

### Subroutine/Function Documentation

```fortran
subroutine compute_something(input_a, input_b, output_c, status)
  !
  ! Short description
  !
  ! Arguments:
  !   input_a  - [in] description of input_a
  !   input_b  - [in] description of input_b
  !   output_c - [out] description of output_c
  !   status   - [out] status code (0=success)
  !
  ! Notes:
  !   - Assumption 1
  !   - Assumption 2
  !
```

## Code Review Checklist

- ✓ Follows naming conventions
- ✓ Proper indentation (2 spaces)
- ✓ Has documentation comments
- ✓ Uses intent attributes
- ✓ Checks error conditions
- ✓ Has tests
- ✓ No compiler warnings

## Tools and Automation

ATLAS currently relies primarily on review-driven style enforcement rather than a mandatory formatter.

- **Formatter**: No repository-wide enforced formatter at this time
- **Linter**: No dedicated lint pipeline for Fortran/Python style in this repository
- **Editor Settings**: No top-level `.editorconfig` is provided

Recommended local checks before commit:

```bash
# Rebuild with warnings visible
cmake --build build

# Run regression tests
ctest --test-dir build --output-on-failure
```

If you use personal formatting tools locally, keep diffs focused and avoid large style-only rewrites.

---

See: [Testing](./testing), [Contributing](./contributing)
