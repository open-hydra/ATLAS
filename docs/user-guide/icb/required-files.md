# Required Files

ICB requires the following files to run:

| File | Required | Description |
|------|----------|-------------|
| Mesh file | **Yes** | Structured multiblock mesh. ICB looks for `mesh.tec` (ASCII Tecplot), `mesh.p3d` (PLOT3D) or `mesh.szplt` (binary Tecplot, needs a TecIO build) in the working directory, in that order: the first file that exists is read, the others are ignored with a warning (delete a stale one). A `mesh.tec` that exists but cannot be read stops the run; a `mesh.p3d` that cannot be read is followed by `mesh.szplt` when it exists, with a warning naming both files. (MDB, which runs in the solver directory, uses a different list: `INPUT/ic.tec`, `INPUT/ic.szplt`, `mesh.tec`, `mesh.szplt`, `mesh.p3d`, `MESH/mesh.tec`.) PLOT3D input (`mesh.p3d`) is read by the pinned ORION with both compiler suites. A mesh with three coordinates on one node plane (a PLOT3D file written `Ni Nj 1`, or a Tecplot zone with `K = 1` whose first three variables are x, y and z with z nodal, e.g. a slice of a 3-D mesh) is read as the pure-2D mesh of its x-y plane, like a Tecplot file with the coordinates x y only: if z is not constant on that plane the mesh is its projection on x-y (WARNING naming the block); a plane perpendicular to x-y (no area on x-y) is refused, and so are blocks with one node plane next to blocks with several. |
| ICB INI file | **Yes** | INI file containing `[ICB-BlockN]` sections and IC definitions. Defaults to `input.ini`; override with `--input`/`-i`. |
| Phase file(s) | **Yes** | One or more `*phase.txt` files describing phase type and composition/materials. Built by ATLAS GPB. |
| `filelist.txt` | No | Plain-text list of phase file names (one per line), used by ICB to discover phase files. When running through `ATLAS ICB`, this file is created automatically and removed at the end. |
| `thermo.dat` | Depends | Tabulated thermodynamic data required by ideal-gas (`IG`) and real-fluid (`RF`) phases. Built by ATLAS GPB. |
| `properties.dat` | Depends | Tabulated material data required by condensed-dispersed (`DP`) and solid (`SP`) phases. Built by ATLAS GPB. |
| Previous solution file | No | Required only by interpolation initialization (`old-solution`, e.g. `field.tec` / `field.szplt`). |

## Directory Layout

A typical ICB working directory looks like:

```
./
|-- mesh.tec          # mesh file (or mesh.p3d / mesh.szplt)
|-- input.ini         # ICB INI file
|-- filelist.txt      # phase discovery list (optional if using ATLAS wrapper)
|-- gas-phase.txt     # phase description (or phase.txt)
`-- gas-thermo.dat    # thermodynamic table (phase-dependent)
```

Output files are written to `fromATLAStoSolver/`.

!!! note
    If no phase file is found, ICB assumes a single unnamed ideal-gas phase.

---

See also [IC Setup](./ic-setup.md) for how initial conditions are defined in `input.ini`, and
[Input Reference](./input-reference.md) for a complete key list.
