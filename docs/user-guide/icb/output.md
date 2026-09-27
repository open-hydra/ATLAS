# ICB Output Files

ICB writes initial-condition fields into `fromATLAStoSolver/`.

The output format is controlled by `ATLAS-Parameters: IC-format`.

---

## File Naming

ICB writes one output file set per phase.

### Tecplot output (`IC-format = tec` or `tec-binary`)

| Phase name | Output file |
|-----------|-------------|
| unnamed phase | `ic.tec` or `ic.szplt` |
| named phase (example `gas`) | `gas-ic.tec` or `gas-ic.szplt` |

### VTK output (`IC-format` containing `vtk`)

ICB writes a VTK multiblock container and per-block VTS files:

- `<phase>-ic.vtm` in `fromATLAStoSolver/`
- block files in `fromATLAStoSolver/vtk/` (for example `B1-IG.vts`)

If the phase has no name, the prefix is omitted (`ic.vtm`).

## File Content

Each output contains cell-centered initialized variables for each associated block.

When ORION returns an error while writing the initial condition, ICB stops with `[ERROR] writing
fromATLAStoSolver/<phase>-ic.<ext> (ORION error <n>, see its message above): no initial condition was
written for this phase` and exit status 1 instead of ending as a success. With the pinned ORION the
binary Tecplot writer (`.szplt`, TecIO builds) reports such errors, for example a folder that cannot be
written or a full disk.

Variable payload depends on phase type:

| Phase | Typical variables |
|-------|-------------------|
| IG | species densities, velocity components, pressure, optional turbulence fields |
| RF | pressure, velocity components, enthalpy, optional turbulence fields |
| SP | temperature, material ID |
| DP/CD | per-population density, velocity, pseudo-pressure (if enabled), temperature, number density |

The writer exports exactly what ICB built at initialization time, after any multizone logic and interpolation.

Under the Reynolds-stress model a pure-2D target (two coordinates, or a single node plane) carries five turbulence
bands, `ruu rvv rww ruv omega`: the Reynolds-stress state of Q2D, which reads the initial condition by position.
Every other target (a single layer of cells included) carries seven, `ru'u' rv'v' rw'w' ru'v' ru'w' rv'w' omega`.
Main wrote the seven bands on a pure-2D target too, so Q2D read `ru'w'` as omega.

## Notes

- ICB does not write `IC_block_<n>.bin` files.
- VTK/Tecplot selection is entirely controlled through `IC-format`.
- Output file names are phase-aware and include `<phase>-` only for named phases.

ICB writes no passive-scalar band: a solver run with passive scalars (npass > 0) reads its `Pass` bands from an IC file that does not carry them, so passive scalars cannot be initialised by ICB today.
