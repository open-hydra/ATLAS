# Required Files

BCB requires the following files to run:

| File | Required | Description |
|------|----------|-------------|
| Mesh file | **Yes** | Structured multiblock mesh. BCB looks for `mesh.tec` (ASCII Tecplot), `mesh.p3d` (PLOT3D) or `mesh.szplt` (binary Tecplot, needs a TecIO build) in the working directory, in that order: the first file that exists is read, the others are ignored with a warning (delete a stale one). A `mesh.tec` that exists but cannot be read stops the run; a `mesh.p3d` that cannot be read is followed by `mesh.szplt` when it exists, with a warning naming both files. (MDB, which runs in the solver directory, uses a different list: `INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`.) PLOT3D input (`mesh.p3d`) is read by the pinned ORION with both compiler suites. A mesh with three coordinates on one node plane (a PLOT3D file written `Ni Nj 1`, or a Tecplot zone with `K = 1` whose first three variables are x, y and z with z nodal, e.g. a slice of a 3-D mesh) is read as the pure-2D mesh of its x-y plane, like a Tecplot file with the coordinates x y only: if z is not constant on that plane the mesh is its projection on x-y (WARNING naming the block); a plane perpendicular to x-y (no area on x-y) is refused, and so are blocks with one node plane next to blocks with several. |
| BCB INI file | **Yes** | INI file containing `[BCB-BlockN]` sections and BC definitions. Defaults to `input.ini`; override with `--input <file>`, or with `BCB-file` in `[ATLAS-Parameters]`. |
| Phase file(s) | **Yes** | One or more `*phase.txt` files describing the fluid/material phases, in the working directory: GPB writes them into `fromATLAStoSolver/`, copy them from there. BCB lists them through `filelist.txt`. With none, BCB looks for the `phase.txt` of a single unnamed ideal gas and stops without it. |
| `filelist.txt` | No | Plain-text list of phase file names (one per line), used to discover phase files in the working directory. `ATLAS BCB` writes it from the `*phase.txt` of the directory and removes it at the end; a `filelist.txt` you wrote is kept and used. |
| `thermo.dat` | Depends | Tabulated thermodynamic properties (cp, h, s), `<name>thermo.dat` next to `<name>phase.txt`. Required by the inlets that expand a total state (`405` given by `p0` and `T0`, `420` given by `Ae_At`) and read by the temperature-range checks of an ideal-gas or real-fluid phase. Built by GPB. |
| `properties.dat` | Depends | Tabulated material properties (cp, ρ, h), `<name>properties.dat`, of a condensed-dispersed or solid phase. Built by GPB. |
| Spatially-varying BC files | No | ASCII data files referenced by `<key>-file` options inside BC sections (e.g. `q-file`, `T-file`, `g-file`). Can be 1-D (coordinate + value) or 2-D (header row of column coords + data rows). |
| Time-series files | No | ASCII files referenced by `time-file`, `p0-time-file`, `q-time-file`, `T-time-file` inside BC sections for time-varying boundary conditions. |
| Line file | No | Tecplot ASCII structured file (unwrapped 2D time record) referenced by `line-file` inside an inlet section, together with `center`: BCB maps it onto the block face and *writes* the section's `time-file` from it (see [BC Types](bc-types.md#inlet)). |
| CEA input file | No | Referenced by `eq-CEA-file` when oxidizer-fuel equilibrium inflow is used. |

## Directory Layout

A typical BCB working directory looks like:

```
./
├── mesh.tec          # mesh file (or mesh.p3d / mesh.szplt)
├── input.ini         # BCB INI file
├── phase.txt         # ideal-gas phase (or <name>-phase.txt), copied from fromATLAStoSolver/
└── thermo.dat        # thermodynamic table (or <name>-thermo.dat)
```

Output files are written to `fromATLAStoSolver/`.

!!! note
    BCB auto-detects the mesh format by file extension. The search order is `.tec` → `.p3d` → `.szplt`.
    Write the coordinates with full double precision (15–16 significant digits): block connections match face
    centres within `1e-7`, and the axisymmetric test compares node angles to `1e-5` rad.

---

See also [BC Setup](bc-setup.md) for how boundary conditions are defined inside `input.ini`, and
[Input Reference](input-reference.md) for a full list of supported INI keys.
