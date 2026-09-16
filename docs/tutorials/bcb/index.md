# BCB Tutorials

All test cases referenced here are available in `test/BCB/`.

!!! warning "Work in progress"
    Detailed tutorial pages are being written. The table below lists the available reference cases.

| Case | Test objective |
|------|----------------|
| `IG-basic` | Validate baseline ideal-gas BC assignment (inlet/outlet/wall) and output formatting. |
| `IG-2D` | Validate ideal-gas BC mapping on a 2D multi-face layout. |
| `IG+CD` | Validate combined ideal-gas and condensed-phase BC handling in one case. |
| `IG+SP` | Validate combined ideal-gas and solid-particle BC handling in one case. |
| `IG-melting` | Validate the `gsi` melting variant (`503`): `cp`/`T`/`Ti`/`dh`/`qrad` plus injected composition. |
| `IG-pyrolysis` | Validate the `gsi` pyrolysis variant (`504`) with `pyrolysis-model = HTPB`. |
| `IG-ablation` | Validate the `gsi` surface-reactions variant (`505`) with `surface-reactions = bradley`. |
| `IG-chimera` | Validate chimera/overset boundary metadata generation. |
| `IG-chimera+connection` | Validate chimera and standard connection coexisting on a distorted, refined 3-block layout. |
| `IG-force-chimera` | Validate `BC-force-chimera` on a partial interface: only the facelets that see the other block become chimera. |
| `IG-periodic` | Validate periodic face pairing and periodic BC consistency. |
| `IG-multipatch-1D` | Validate 1D multipatch face-index mapping and BC construction. |
| `IG-multipatch-2D` | Validate 2D multipatch face-index mapping and BC construction. |
| `IG-multipatch-file` | Validate file-driven multipatch definition and resulting BC output. |
| `IG-multipatch-index` | Validate index-based multipatch configuration parsing and mapping. |
| `IG-inflow-nozzle` | Validate nozzle-driven inflow BC generation. |
| `IG-inflow-ceafile-inertmix` | Validate CEA-based inert-mixture inflow BC generation. |
| `IG-inflow-p0time` | Validate a time-varying total-pressure inlet driven by `p0-time-file`. |
| `IG-extrapolated-time-file` | Validate time-dependent BC interpolation/extrapolation from external files. |
| `IG-xtheta-variable-T` | Validate inflow temperature assignment varying with x-theta coordinates. |
| `IG-y-variable-massflux` | Validate spanwise-varying mass-flux BC assignment. |
| `NO_IG-1D` | Validate no-ideal-gas configuration path for 1D boundary setup. |
| `DP-basic` | Validate dispersed-phase BC assignment and export. |
| `DP-z-variable-krho` | Validate z-dependent dispersed-property BC setup (e.g., k-rho variation). |
| `SP-basic` | Validate solid-phase/particle BC assignment and output. |
