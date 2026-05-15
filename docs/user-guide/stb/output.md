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
- For `theta-areavariation`, input theta is interpreted in degrees and converted internally.
