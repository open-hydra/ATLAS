# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

ATLAS is a hydra pre-processing toolbox. It is also a git submodule of the parent hydra repo (`utils/ATLAS`); a separate `CLAUDE.md` at hydra root covers the parent-level `figaro` workflow. Within this directory, builds and tests are self-contained — `figaro` is not required.

## Common commands

```bash
# Full build (wipes build/, inits the submodules FiNeR, cea and PiNeR, configures — checking out the release
# of ORION in lib/ —, compiles, writes CMakePresets.json,
# appends ATLAS shell function to ~/.bashrc, creates ct-env conda env)
./install.sh build --compilers=gnu --use-openmp                   # default = gnu+openmp
./install.sh build --compilers=intel --use-openmp --use-tecio
./install.sh build --no-conda                                     # skip ct-env (needed for GPB/KAnT)
./install.sh build --include-cea=<path> --include-orion=<path> --include-finer=<path>   # external clones
./install.sh build --update-deps                                  # newest ORION 2.x again (deps.lock)

# Incremental rebuild (no wipe) — use whenever editing source
cmake --preset default && cmake --build build
# or
scripts/compile.sh

# Tests (CTest)
ctest --test-dir build --output-on-failure
ctest --test-dir build -R IG-inflow-nozzle --output-on-failure    # single test by regex
ctest --test-dir build -L BCB                                     # by label: GPB|BCB|ICB|STB|regression

# Enable pre-push hook (runs full CTest before any push)
git config core.hooksPath .githooks
```

After `install.sh build`, the `ATLAS` bash function is exported via `scripts/setvars.sh`. From a case directory containing the mesh and the setup of the tools, `input.ini` (which `ATLAS GUI` writes):

```bash
ATLAS GPB BCB ICB           # chained run, one shared input.ini
ATLAS STB
ATLAS KAnT                  # 0-D/1-D chemistry
ATLAS CEA <input>           # direct CEA call: build/lib/cea/source/cea
ATLAS DOCS                  # dump per-tool config schema via --write-config-doc
```

Every tool writes into `fromATLAStoSolver/` of the case (`outpath` in `src/common/global.f90`, `OUTPATH` in `src/GPB/config.py`); `figaro` moves the files into the `INPUT/` of a solver run. The tools do not write a solver's `INPUT/`, where they would replace a run's input without notice; only MDB, meant to run in the solver directory, reads `INPUT/` by default and adds files next to it (`<grid>-split.<ext>`, `INPUT-split/`). BCB/ICB/STB/MDB read each phase file from the case directory when it is there (written by hand), else from `fromATLAStoSolver/` (`phase_dir`), with its `thermo.dat`/`properties.dat` from the same directory, so `ATLAS GPB BCB ICB` needs no copy. Before each Fortran tool `ATLAS.sh` writes `filelist.txt` from the `*phase.txt` of both directories (warning when a case-directory copy differs from GPB's) and removes it at the end. GPB and KAnT auto-activate the `ct-env` conda env; the Fortran tools (BCB/ICB/STB) run from `bin/` directly.

## Architecture

**Five tools, two languages.** BCB, ICB, STB are Fortran 2008 executables built by this CMake project. GPB and KAnT are Python packages run from source via `python3 -B <path>`. `ATLAS.sh` is the single dispatcher that hides which is which.

**Shared Fortran scaffolding.** Every Fortran exe is linked against the same `src/common/` sources (FiNeR INI parser, CEA chemistry, ORION I/O, mesh/phase readers, geometry helpers). `src/CMakeLists.txt` uses `file(GLOB)` per tool then `list(PREPEND)` to force `config.f90`/`types_*.f90`/`bc_names.f90` to compile first (Fortran module-dependency ordering — be aware when adding new files that other modules `use`).

**Typed parameter registry.** `src/common/registry.f90` (`registry_t`) is the type-erased container that all Fortran configs build on: each tool's `config.f90` declares typed pointers, registers them with descriptions/defaults/allowed-values, and FiNeR populates the values. `Validate_Registry` enforces required/allowed-values post-parse. Touch this when adding new INI options to any Fortran tool.

**CEA integration is mandatory.** `lib/cea` (NASA Chemical Equilibrium and Applications) is *not* optional — all three Fortran exes link `cea_core`. The CMake config force-disables CEA's C++/Python/Matlab/Excel bindings but keeps `CEA_ENABLE_BIND_C=ON` for required C abort symbols. A symlink `<ATLAS>/data -> lib/cea/data` is created during configure; CTest sets `CEA_DATA_DIR=<ATLAS>/build` via the setvars logic so CEA finds its tables at runtime.

**Libraries: releases and submodules.** ORION, required by a range of releases, uses `semver_dependency` of `cmake/SemVerDeps.cmake` (FLINT's copy, kept unmodified — update it from FLINT, never locally) in the top-level `CMakeLists.txt`: `VERSION 2` (newest 2.x, recorded in the gitignored `deps.lock`); the configure clones/moves it in `lib/ORION` (gitignored, not a submodule). Libraries pinned at one release are git submodules: `lib/FiNeR` (v2.3.0, `ATLAS_FINER_TAG` checked against its `VERSION`), `lib/cea`, `lib/PiNeR`. External clones come from `-DFETCHCONTENT_SOURCE_DIR_ORION/_FINER` and are checked against those requirements in `cmake/AddLibraries.cmake` (`ATLAS_PIN_CHECK`, fatal by default). FiNeR's own deps (PENF, StringiFor, FACE, FLAP, BeFoR64) come from `cmake/FiNeRDependencies.cmake`: default branches as `fobis fetch` (`ATLAS_FINER_DEPS=FREE`) or the backup releases (`BACKUP`). The submodules are checked against their gitlinks (`cmake/SubmodulePins.cmake`); `install.sh build` initializes them and `ensure_submodule_initialized` re-inits a missing one at configure time. `lib/PiNeR` is a Python package installed editable into `ct-env`; `lib/cea` is also pip-installed editable into the same env (see `ct-env.yaml`; ORION's Python is not installed, nothing in ATLAS imports it). Versioning policy and release steps: `docs/development/versioning.md`, entries under `[Unreleased]` in `CHANGELOG.md`.

**Build artifacts.**
- `bin/{BCB,ICB,STB}` — Fortran executables, output of `CMAKE_RUNTIME_OUTPUT_DIRECTORY`.
- `build/modules/` — Fortran `.mod` files, included as `target_include_directories` on every target.
- `build/lib/cea/` — CEA build tree.

## Important gotchas

- `install.sh build` **wipes `build/`** — never use it for incremental work. Use `cmake --build build` or `scripts/compile.sh`.
- `CMakePresets.json` is regenerated by `install.sh build` (`write_presets`) from `build/CMakeCache.txt`. Do not hand-edit; regenerate by rebuilding.
- The `ATLAS` bash function is rewritten into `~/.bashrc` on every `install.sh build` — any prior line containing the string `ATLAS` in the rc file is *grep-deleted* (`grep -v "ATLAS"`). Other personalisations matching that substring will be lost.
- Conda is required for GPB/KAnT (they live behind `conda activate ct-env` in `ATLAS.sh`). Build with `--no-conda` only if you are running Fortran tools only.
- `ATLAS.sh` finds no `*phase.txt` outside a case directory; the `filelist.txt` it writes is consumed by the Fortran tools (`read_phase.f90`) and removed at end. A `filelist.txt` the user already has is kept and used as it is.
- Regression tests do *byte-diff* against `reference/` outputs — formatter/ordering changes in any output writer will break them. Diff target: `fromATLAStoSolver/*` (gitignored). Large tables and fields are compared on a sample (`test/sample_rows.awk`), the tutorial cases carry the label `tutorial` (`ctest -L tutorial`), and the INI files the tutorial pages write live in `test/tutorials/<page>/`, included by the pages as snippets.
- For host-specific quirks shared with the parent hydra build (MOSE pin, OSlo, MF_IO_Wall ifdef gaps, figaro shell issues) see auto-memory entry `project_hydra_workarounds.md` — those are hydra-level, not ATLAS-level, but propagate when building ATLAS via `figaro build ATLAS`.

## Changelog entries

`CHANGELOG.md` is read by people, so keep it short: one change per entry, at most two short lines, saying what changed
and, for a **Breaking** entry, what to do. Group related changes in one entry. Mechanisms, numbers, error messages,
test names and file lists belong in the docs or the commit message: link the page instead of explaining. Before adding
an entry, look at the ones around it and match their length.
