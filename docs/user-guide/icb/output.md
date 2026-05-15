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

Variable payload depends on phase type:

| Phase | Typical variables |
|-------|-------------------|
| IG | species densities, velocity components, pressure, optional turbulence fields |
| RF | pressure, velocity components, enthalpy, optional turbulence fields |
| SP | temperature, material ID |
| DP/CD | per-population density, velocity, pseudo-pressure (if enabled), temperature, number density |

The writer exports exactly what ICB built at initialization time, after any multizone logic and interpolation.

## Notes

- ICB does not write `IC_block_<n>.bin` files.
- VTK/Tecplot selection is entirely controlled through `IC-format`.
- Output file names are phase-aware and include `<phase>-` only for named phases.

