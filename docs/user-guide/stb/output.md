# STB Output Files

STB writes source-term fields into `fromATLAStoSolver/` and may also write area-variation tables for blocks configured with `*-areavariation` keys.

---

## File Naming

### Source-term field output (`qvol`)

Source output naming depends on the selected output format:

| Output selection | Main file(s) |
|------------------|--------------|
| Tecplot ASCII (`tec`, `tec-ascii`) | `st.tec` |
| Tecplot binary (`tec-binary`) | `st.szplt` |
| VTK (`vtk`, `vtk-ascii`, `vtk-binary`) | `qvol.vtm` + block files in `vtk/` |
| Combined (`all`) | Tecplot + VTK outputs |

VTK block files are written under `fromATLAStoSolver/vtk/`.

### Area-variation output (optional)

When an area profile key is found for a block, STB writes:

- `fromATLAStoSolver/block<N>_area.dat`

where `<N>` is the 1-based block index.

## File Content

### `st.tec` / `st.szplt` / VTK files

- Cell-centered field named `qvol`.
- One dataset spanning all configured mesh blocks.

### `block<N>_area.dat`

- Plain-text matrix of interpolated area values mapped to block face nodes.
- Built from input coordinate-area pairs with linear interpolation and clamped end extrapolation.

## Notes

- STB always creates `fromATLAStoSolver/` if it does not exist.
- Area-variation files are optional and independent from `qvol` source-field output.
- If no block defines `qvol` or `qvol-file`, no `st.*`/`qvol.vtm` is written (`- No volumetric source terms configured`): the solver treats a missing source file as zero source. Any `st.tec`, `st.szplt` or `qvol.vtm` left in `fromATLAStoSolver/` by a previous run is reported with a `[WARNING]` and must be removed by hand if it is no longer wanted.
- In a multi-block mesh, blocks without `qvol`/`qvol-file` are written with `qvol = 0` (the solver requires every block of the mesh in the source file).
- `qvol-file` requires `direction`; STB stops with an error otherwise. `direction` is a letter of x, y, z, r, t; a combination of letters (e.g. `xy`) is accepted and read along its first letter by priority x > y > z > r > t, with a `[WARNING]` naming it. A `direction` without `qvol-file` is not used and is reported with a `[WARNING]`. The profile must cover every cell centre of the block along `direction` (values are never extrapolated): STB stops with `[ERROR] ... qvol-file profile does not cover the block` if it does not.
- For `theta-areavariation`, input theta is interpreted in degrees and converted internally.
