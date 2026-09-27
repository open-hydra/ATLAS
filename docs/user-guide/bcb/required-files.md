# Required Files

BCB requires the following files to run:

| File | Required | Description |
|------|----------|-------------|
| Mesh file | **Yes** | Structured multiblock mesh. BCB looks for `mesh.tec` (ASCII Tecplot), `mesh.p3d` (PLOT3D) or `mesh.szplt` (binary Tecplot, needs a TecIO build) in the working directory, in that order: the first file that exists is read, the others are ignored with a warning (delete a stale one). A `mesh.tec` that exists but cannot be read stops the run; a `mesh.p3d` that cannot be read is followed by `mesh.szplt` when it exists, with a warning naming both files. (MDB, which runs in the solver directory, uses a different list: `INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`.) PLOT3D input (`mesh.p3d`) is read by the pinned ORION with both compiler suites. A mesh with three coordinates on one node plane (a PLOT3D file written `Ni Nj 1`, or a Tecplot zone with `K = 1` whose first three variables are x, y and z with z nodal, e.g. a slice of a 3-D mesh) is read as the pure-2D mesh of its x-y plane, like a Tecplot file with the coordinates x y only: if z is not constant on that plane the mesh is its projection on x-y (WARNING naming the block); a plane perpendicular to x-y (no area on x-y) is refused, and so are blocks with one node plane next to blocks with several. |
| BCB INI file | **Yes** | INI file containing `[BCB-BlockN]` sections and BC definitions. Defaults to `input.ini`; override with `--bcb-file`. |
| Phase file(s) | **Yes** | One or more `*phase.txt` files describing the fluid/material phases. BCB auto-discovers them via `filelist.txt`. If none is found, a single ideal-gas phase is assumed. Built by ATLAS GPB.|
| `filelist.txt` | No | Plain-text list of phase file names (one per line), used to discover phase files in the working directory. |
| `thermo.dat` | No | Tabulated thermodynamic properties (cp, h, s). Required when temperature-dependent properties are needed for an ideal-gas or real-fluid phase. Built by ATLAS GPB. |
| `properties.dat` | No | Tabulated material properties (cp, ρ, h). Required only for condensed-dispersed (`condensed-dispersed`) phases. Built by ATLAS GPB. |
| Spatially-varying BC files | No | ASCII data files referenced by `<key>-file` options inside BC sections (e.g. `q-file`, `T-file`, `g-file`). Can be 1-D (coordinate + value) or 2-D (header row of column coords + data rows). |
| Time-series files | No | ASCII files referenced by `time-file`, `p0-time-file`, `p-time-file`, `q-time-file`, `T-time-file` inside BC sections for time-varying boundary conditions. |
| Line file | No | Tecplot ASCII structured file (unwrapped 2D time record) referenced by `line-file` inside an inlet section, together with `center`: BCB maps it onto the block face and *writes* the section's `time-file` from it (see [BC Types](bc-types.md#inlet)). |
| CEA input file | No | Referenced by `eq-CEA-file` when oxidizer-fuel equilibrium inflow is used. |

## Directory Layout

A typical BCB working directory looks like:

```
./
├── mesh.tec          # mesh file (or mesh.szplt / mesh.p3d); write the coordinates with full double precision (15-16 significant digits): the axisymmetric test compares node angles to 1e-5 rad and the block connections match face centres exactly
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
