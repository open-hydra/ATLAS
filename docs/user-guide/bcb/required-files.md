# Required Files

BCB requires the following files to run:

| File | Required | Description |
|------|----------|-------------|
| Mesh file | **Yes** | Structured multiblock mesh. BCB looks for `mesh.tec` (ASCII Tecplot), `mesh.szplt` (binary Tecplot), or `mesh.p3d` (PLOT3D) in the working directory, in that order. |
| BCB INI file | **Yes** | INI file containing `[BCB-BlockN]` sections and BC definitions. Defaults to `input.ini`; override with `--bcb-file`. |
| Phase file(s) | **Yes** | One or more `*phase.txt` files describing the fluid/material phases. BCB auto-discovers them via `filelist.txt`. If none is found, a single ideal-gas phase is assumed. Built by ATLAS GPB.|
| `filelist.txt` | No | Plain-text list of phase file names (one per line), used to discover phase files in the working directory. |
| `thermo.dat` | No | Tabulated thermodynamic properties (cp, h, s). Required when temperature-dependent properties are needed for an ideal-gas or real-fluid phase. Built by ATLAS GPB. |
| `properties.dat` | No | Tabulated material properties (cp, ρ, h). Required only for condensed-dispersed (`condensed-dispersed`) phases. Built by ATLAS GPB. |
| Spatially-varying BC files | No | ASCII data files referenced by `<key>-file` options inside BC sections (e.g. `q-file`, `T-file`, `g-file`). Can be 1-D (coordinate + value) or 2-D (header row of column coords + data rows). |
| Time-series files | No | ASCII files referenced by `p0-time-file`, `p-time-file`, `q-time-file`, `T-time-file` inside BC sections for time-varying boundary conditions. |
| CEA input file | No | Referenced by `eq-CEA-file` when oxidizer-fuel equilibrium inflow is used. |

## Directory Layout

A typical BCB working directory looks like:

```
./
├── mesh.tec          # mesh file (or mesh.szplt / mesh.p3d)
├── input.ini         # BCB INI file
├── filelist.txt      # phase file discovery list (optional)
├── phase.txt         # ideal-gas phase (or <name>-phase.txt)
└── thermo.dat        # thermodynamic table (optional)
```

Output files are written to `fromATLAStoSolver/`.

!!! note
    BCB auto-detects the mesh format by file extension. The search order is `.tec` → `.p3d` → `.szplt`.
    If no phase file is found, BCB assumes a single unlabelled ideal-gas phase.

---

See also [BC Setup](bc-setup.md) for how boundary conditions are defined inside `input.ini`, and
[Input Reference](input-reference.md) for a full list of supported INI keys.
