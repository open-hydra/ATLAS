# Plan: ICB-BCB Full Refactor

## TL;DR
Refactor the ATLAS/src/ICB-BCB preprocessor codebase in 3 incremental phases: (1) reorganize files into a clean, meaningful directory layout with updated CMake, (2) decompose the `ATLAS_block` god-object and global state into composed types, (3) refactor the BC/IC builder monsters into extensible strategy/dispatch patterns. Each phase is independently mergeable and verified by existing regression tests.

---

## Phase 1: Directory Reorganization + CMake

**Goal**: Clean folder structure reflecting logical domains; no code changes, only file moves and CMake updates.

### Current layout (flat lib/ with ad-hoc subfolders)
```
lib/
  ATLAS_high_level.f90, Mod_Grid.f90, variables.f90, phase.f90   (core)
  area_law.f90                                                    (math util)
  BC_lib.f90, BC_builder.f90, BC_connection.f90, BC_chimera.f90,
    BC_chimera_intersection.f90, BC_area_variation.f90,
    BC_injection_plate3D.f90, BC_q2d_map.f90                     (BC - mixed with core)
  ic/   IC_builder, IC_lib_IG, IC_lib_CD, IC_lib_SP, IC_lib_POWER,
        IC_interpolation_IG, IC_interpolation_SP                  (IC - good)
  IO/   IO_fields, Read_INI, Read_phase, Write_bc, IO_multigrid  (IO - good)
```

### Proposed layout
```
lib/
  core/
    types.f90              ← renamed from ATLAS_high_level.f90
    grid.f90               ← renamed from Mod_Grid.f90
    variables.f90          ← kept as-is
    phase.f90              ← kept (but split into species.f90 + material.f90 in Phase 2)
    area_law.f90           ← math utility used by both IC and BC
  bc/
    bc_types.f90           ← renamed from BC_lib.f90
    builder.f90            ← renamed from BC_builder.f90
    connection.f90         ← renamed from BC_connection.f90
    chimera.f90            ← renamed from BC_chimera.f90
    chimera_intersection.f90 ← renamed from BC_chimera_intersection.f90
    area_variation.f90     ← renamed from BC_area_variation.f90
    injection_plate.f90    ← renamed from BC_injection_plate3D.f90
    q2d_map.f90            ← renamed from BC_q2d_map.f90
  ic/
    builder.f90            ← renamed from IC_builder.f90
    ig.f90                 ← renamed from IC_lib_IG.f90
    cd.f90                 ← renamed from IC_lib_CD.f90
    sp.f90                 ← renamed from IC_lib_SP.f90
    power.f90              ← renamed from IC_lib_POWER.f90
    interpolation_ig.f90   ← renamed from IC_interpolation_IG.f90
    interpolation_sp.f90   ← renamed from IC_interpolation_SP.f90
  io/
    fields.f90             ← renamed from IO_fields.f90
    read_ini.f90           ← renamed from Read_INI.f90
    read_phase.f90         ← renamed from Read_phase.f90
    write_bc.f90           ← renamed from Write_bc.f90
    multigrid.f90          ← renamed from IO_multigrid.f90
app/
  icb.f90                  ← renamed from ICB.f90 (lowercase convention)
  bcb.f90                  ← renamed from BCB.f90
  bcb_q2d.f90              ← renamed from BCB-Q2D.f90
```

### Steps
1. Create `core/`, `bc/` subdirectories under `lib/`; rename `IO/` → `io/` (lowercase)
2. Move files per the mapping above (rename for consistency — lowercase, drop redundant prefixes since folder gives context)
3. Update `lib/CMakeLists.txt` glob patterns: `file(GLOB SOURCES "core/*.f90" "bc/*.f90" "ic/*.f90" "io/*.f90")`
4. Update `app/CMakeLists.txt` if file names changed
5. Remove `convexHull.py` from lib/ if it's unused, or move to `scripts/`

### Verification
1. Run `cmake --build build` — must compile identically
2. Run all tests in `test/BCB/` and `test/ICB/` — must pass unchanged
3. Confirm `bin/ICB`, `bin/BCB`, `bin/BCB-Q2D` executables are produced

---

## Phase 2: Type Decomposition & Global State Cleanup

**Goal**: Break the `ATLAS_block` god-object into composed types; encapsulate global state; split the multi-module `phase.f90` into single-responsibility files.

### Steps

#### 2a. Split `ATLAS_block` into composed types
Currently `ATLAS_block` contains IC-IG fields, IC-CD fields, IC-SP fields, BC face data, and metadata all in one type.

- Extract `type :: block_ic_ig` (density, temperature, pressure, velocity, turbprop, mil, kl)
- Extract `type :: block_ic_cd` (densityP, velocityP, temperatureP, nP, PP)
- Extract `type :: block_ic_sp` (mID, qvol, temperature)
- Extract `type :: block_bc_data` (nfaces, face(:), properties)
- Keep `ATLAS_block` as a **composed** type:
  ```fortran
  type, extends(block_type) :: ATLAS_block
    type(block_ic_ig) :: ic_ig
    type(block_ic_cd) :: ic_cd
    type(block_ic_sp) :: ic_sp
    type(block_bc_data) :: bc
    integer, allocatable :: associated_phase(:)
    integer :: id
  end type
  ```
- **File**: `core/types.f90` — define sub-types, then compose in `ATLAS_block`
- **Impact**: All references like `block%density` become `block%ic_ig%density`; mechanical find-replace across IC/BC builders

#### 2b. Encapsulate global state in `variables.f90`
- Wrap `nrans`, `neuler`, `verbose`, `meshType`, `gc` into a `type :: config_type`
- Pass `config` explicitly to subroutines that currently `use variables`
- Move `gc`, `meshType`, `delthe` from `Mod_Grid.f90` into the config or a `mesh_config` type

#### 2c. Split `phase.f90` into single-module files
- `core/species.f90` — module `species` (obj_species, define_composition)
- `core/material.f90` — module `material_module` (obj_material)
- `core/phase.f90` — module `phase_module` (phase_type, uses species + material)

#### 2d. Fix `nIG` mismatch
- IC_builder defines `nIG=5`, BC_lib defines `nIG=7` — consolidate into a single source of truth (core/constants.f90 or inside the config type)

### Verification
1. Build must compile
2. All regression tests must pass with identical output
3. Diff test outputs against Phase 1 baseline to confirm bitwise identical results

---

## Phase 3: Builder Refactoring (BC_lib + BC_builder + IC_builder)

**Goal**: Refactor the ~1350-line `build()` in BC_lib and the ~2000-line `build_cell()` in BC_builder into extensible, dispatch-based patterns. Same for IC_builder.

### Steps

#### 3a. BC type registry + strategy pattern for `bc_types.f90` (was BC_lib.f90)
- Define an abstract `bc_type_builder` interface:
  ```fortran
  abstract interface
    subroutine bc_build_iface(self, nrans, sourceini, section, phase)
  end interface
  ```
- Create concrete builder modules per BC family in `bc/types/`:
  ```
  bc/types/
    periodic.f90        ← cases 1,2,3 (half periodic info)
    inlet.f90           ← cases 4,22 (the "monster" — inlet with species, condensed phase)
    wall.f90            ← case 5 (wall: q, T, roughness)
    symmetry.f90        ← case 6
    outflow.f90         ← cases 7,8,9 (various outflow types)
    farfield.f90        ← case 10
    piston.f90          ← case 11
    axis.f90            ← case 12
    freestream.f90      ← case 13
    srm_grain.f90       ← case 14 (SRM grain + inlet logic)
    time_varying.f90    ← case 667
    moska.f90           ← case 999
    manifold.f90        ← case 1001
  ```
- Replace the massive `select case` in `build()` with a dispatch table or `select type` on polymorphic builders
- Extract `assemble_the_monster()` into `inlet.f90` as a proper standalone subroutine
- Extract hardcoded physics constants (Qal, csAl) into named parameters in a `bc/constants.f90`

#### 3b. Refactor `bc/builder.f90` (was BC_builder.f90)
- Extract `build_cell()` into its own module `bc/cell_builder.f90`
- Factor out duplicated interpolation (1D linear, 2D bilinear) into `core/interpolation.f90`
- Extract injection plate logic (plate_file_type hierarchy) into `bc/injection_plate.f90` (already exists, consolidate)
- Extract file-parsing routines (Tecplot header skip, column detect) into `io/parse_utils.f90`

#### 3c. Refactor IC builders
- Apply same strategy pattern to `ic/builder.f90`
- Factor out shared interpolation utilities to `core/interpolation.f90`
- Consolidate `nIG` parameter

### Verification
1. Build must compile
2. All regression tests must pass bitwise-identical
3. Manually verify each BC type (1,2,3,4,5,...,1001) is covered by the new dispatch
4. Confirm OpenMP behavior unchanged (critical sections preserved where needed)

---

## Final Directory Structure

```
src/ICB-BCB/
├── app/
│   ├── CMakeLists.txt
│   ├── icb.f90
│   ├── bcb.f90
│   └── bcb_q2d.f90
└── lib/
    ├── CMakeLists.txt
    ├── core/
    │   ├── types.f90              (ATLAS_block + composed sub-types)
    │   ├── grid.f90               (block_type, vector types, metrics)
    │   ├── variables.f90          (config_type)
    │   ├── constants.f90          (nIG, nCP, shared parameters)
    │   ├── species.f90            (obj_species, thermochemistry)
    │   ├── material.f90           (obj_material)
    │   ├── phase.f90              (phase_type)
    │   ├── area_law.f90           (Mach-area solver)
    │   └── interpolation.f90      (shared 1D/2D interpolation)
    ├── bc/
    │   ├── bc_types.f90           (obj_bc_cellface_properties, dispatch)
    │   ├── builder.f90            (build_BC - orchestrator)
    │   ├── cell_builder.f90       (build_cell - extracted)
    │   ├── connection.f90         (find_periodic, find_connect)
    │   ├── chimera.f90            (chimera_wrapper)
    │   ├── chimera_intersection.f90
    │   ├── area_variation.f90
    │   ├── injection_plate.f90
    │   ├── q2d_map.f90
    │   ├── constants.f90          (BC physics constants)
    │   └── types/
    │       ├── periodic.f90
    │       ├── inlet.f90
    │       ├── wall.f90
    │       ├── symmetry.f90
    │       ├── outflow.f90
    │       ├── farfield.f90
    │       ├── piston.f90
    │       ├── axis.f90
    │       ├── freestream.f90
    │       ├── srm_grain.f90
    │       ├── time_varying.f90
    │       ├── moska.f90
    │       └── manifold.f90
    ├── ic/
    │   ├── builder.f90
    │   ├── ig.f90
    │   ├── cd.f90
    │   ├── sp.f90
    │   ├── power.f90
    │   ├── interpolation_ig.f90
    │   └── interpolation_sp.f90
    └── io/
        ├── fields.f90
        ├── read_ini.f90
        ├── read_phase.f90
        ├── write_bc.f90
        ├── multigrid.f90
        └── parse_utils.f90
```

---

## Decisions
- **Library target stays `ATLAS`** — preserves backward compatibility with external references
- **Incremental PRs** — each phase is independently verifiable and mergeable
- **Existing tests are the regression baseline** — bitwise identical output required at each phase
- **No algorithmic changes** — refactoring is structural only; preserve all numerical behavior
- **Module names preserved initially** — in Phase 1 only files move, module names don't change (avoids cascading use-statement updates); module renames happen in Phase 2/3 when content changes anyway

## Open Questions
1. **`convexHull.py`** in lib/ — is this used? Should it move to `scripts/` or be removed?
Answer: It is an important utility called by `bc/builder.f90` to compute convex hulls for chimera interpolation. It should be moved to `external-scripts/` and the Fortran code updated to call it from the new location.
2. **GPB and KAnT** (sibling src/ folders) — do they depend on the ATLAS library? If so, their `use` statements may need updating in Phase 2 when module names change.
Answer: GPB and KAnT do NOT depend on the ATLAS library, a Fortran code, while GPB and KAnT are python. We can think of remove the ATLAS lib entirely: three preprocessors (GPB, ICB, BCB) and a further utility KAnT.
3. **Cantera/KAnT integration** in `species.f90` — the `execute_command_line()` call is fragile (no error handling, hardcoded env vars). Should Phase 2 or 3 address this, or defer to a separate task?
Answer: we can remove the call to KAnT, we are going to think about it in a future refactor. In the test section, a test uses this feature, so it must be deleted.
