# BCB Boundary-Condition Setup GUI

Interactive tool to assign BCB boundary conditions to a multiblock structured
mesh and export a BCB `input.ini`.

## What it does

1. **Load a mesh** — Tecplot ASCII (`.tec`/`.dat`, single or multi-zone,
   `BLOCK`/`POINT` packing) or Plot3D formatted multiblock (`.p3d`/`.xyz`/`.g`).
   Only nodal coordinates are read; field variables are ignored.
2. **Visualise** — every block face is drawn as its own pickable actor. Rotate,
   pan and zoom with the mouse; toggle blocks on/off; switch to preset
   Iso / XY / XZ / YZ views; show/hide per-face labels.
3. **Assign BCs** — left-click a face (in the 3-D view or the tree), then pick a
   BC. Two kinds:
   - **keyword BCs** that need no section (`symmetry`, `connection`, `chimera`,
     `extrapolation`, `outlet`, `null`, `axisymmetric`);
   - **named sections** you define with a `type` (`wall`, `inlet`, `outlet`,
     `manifold`, `srm`, `periodic`) plus arbitrary key/value parameters.
4. **Export** — writes `[ATLAS-Parameters]`, one `[BCB-BlockN]` per block, and
   the referenced named sections, in the format documented in
   `docs/user-guide/bcb/bc-setup.md`.

The toolbar also offers **Auto-reveal** (ghost occluding geometry so a selected
face stays visible), per-block **Ghost** transparency, a **Colour** mode
(by BC or by block index), and a **Theme** selector (Dark Blue, Graphite, Nord,
Light) whose choice is remembered between sessions.

## Face numbering (fixed by BCB)

| Face | Location  | Face | Location   |
|------|-----------|------|------------|
| 1    | `i = 1`   | 2    | `i = imax` |
| 3    | `j = 1`   | 4    | `j = jmax` |
| 5    | `k = 1`   | 6    | `k = kmax` |

For 2-D / single-cell-thick blocks only faces 1-4 are user-assignable; BCB
assigns faces 5/6 automatically, so they are drawn faintly for context.

## Running

Through the ATLAS launcher (activates the `ct-env` conda environment):

```bash
ATLAS BCB-GUI
```

Or directly:

```bash
python GUI/BCB_GUI.py [mesh] [--ini input.ini]
# or
python -m bcbgui [mesh] [--ini input.ini]
```

## Dependencies

`numpy`, `PyQt6`, `pyvista`, `pyvistaqt` — added to `ct-env.yaml`
(`pyqt`, `pyvista`, `pyvistaqt`). Refresh the environment with:

```bash
conda env update -f ct-env.yaml
```

## Layout

| File            | Responsibility                                             |
|-----------------|------------------------------------------------------------|
| `mesh_io.py`    | Multiblock Tecplot / Plot3D reader (numpy only)            |
| `faces.py`      | Face numbering + node extraction (numpy only)              |
| `bcmodel.py`    | `BCBDocument`: data model + INI read/write (no GUI deps)   |
| `viewport.py`   | PyVista `QtInteractor` viewport, picking, block toggling   |
| `mainwindow.py` | PyQt6 main window tying everything together                |
| `__main__.py`   | CLI entry point / dependency guards                        |

`mesh_io.py`, `faces.py` and `bcmodel.py` carry no GUI dependency and can be
imported and tested headlessly.
