# ATLAS case-setup GUI

One window over one `input.ini`: the GPB phases, the BCB boundary conditions
and the `[ATLAS-Parameters]` the tools share — the same file `ATLAS GPB BCB`
reads.

## Stages

| Stage | Panel | What it edits |
|-------|-------|---------------|
| Case | `mainwindow.py` | case directory, mesh, `[ATLAS-Parameters]`, overview |
| Phases | `gpbpanel.py` | `[GPB-PhaseN]`: gas, condensed/solid, real fluid |
| Boundaries | `bcbpanel.py` | `[BCB-BlockN]` + the named BC sections, on the 3-D mesh |
| Review | `mainwindow.py` | the INI as it will be written, and the checks on it |

Sections of tools not edited here (`[ICB-*]`, `[STB-*]`, `[MDB-*]`, `[KAnT-*]`)
are preserved verbatim through a save, as is `[BCB-Block*]` until a mesh says
how many blocks it applies to.

## What the GPB panel knows

The schema — defaults, allowed values, one-line descriptions used as tooltips —
is read at runtime from GPB's own `src/GPB/input_registry.py`, so the forms
cannot drift from the tool. The pickers read the repository: mechanisms and
phase files from `database/chemistry/`, species and materials from
`database/thermo/nasa9.yaml` and `burcat.yaml` (scanned lazily), fluids from
CoolProp when it is importable.

A gas phase is described by its **composition sources** (mechanism, phase file,
CEA equilibrium, Cantera equilibrium, prescribed mixture, explicit species),
which GPB combines, so they are independent switches rather than one choice.
Condensed and solid phases are a table of materials; their per-material solver
models, the constant properties of a calorically-perfect gas, a mixture
composition and the raw key list each open in their own dialog
(`gpbdialogs.py`).

## Running

```bash
ATLAS GUI                       # or: ATLAS BCB-GUI, which opens on Boundaries
python GUI/ATLAS_GUI.py [mesh] [--ini input.ini] [--stage case|gpb|bcb|review]
python -m atlasgui ...
```

## Dependencies

`numpy`, `PyQt6`, `pyvista`, `pyvistaqt` — in `ct-env.yaml` (`pyqt`, `pyvista`,
`pyvistaqt`). Refresh with `conda env update -f ct-env.yaml`.

## Layout

| File | Responsibility |
|------|----------------|
| `document.py` | `AtlasDocument`: routes the INI sections to the tool that owns them |
| `gpbmodel.py` | GPB phases, the schema from `input_registry.py`, validation |
| `bcmodel.py` | `BCBDocument`: blocks, faces, named BC sections, INI I/O |
| `database.py` | what `database/` holds, for the pickers |
| `mesh_io.py` | multiblock Tecplot / Plot3D reader (numpy only) |
| `faces.py` | BCB face numbering + node extraction (numpy only) |
| `viewport.py` | PyVista `QtInteractor` viewport, picking, block toggling |
| `widgets.py` | `UIKit`: themed widget factory shared by the panels |
| `theme.py` | seed palettes, derived tokens, the Qt stylesheet |
| `icons.py` | vector icons drawn with QPainter (no image assets) |
| `gpbpanel.py`, `gpbdialogs.py`, `bcbpanel.py` | the stage panels |
| `mainwindow.py` | the shell: stages, file actions, status, Case and Review |
| `__main__.py` | CLI entry point / dependency guards |

`mesh_io.py`, `faces.py`, `bcmodel.py`, `gpbmodel.py` and `document.py` carry no
GUI dependency and can be imported and tested headlessly.

## Face numbering (fixed by BCB)

| Face | Location  | Face | Location   |
|------|-----------|------|------------|
| 1    | `i = 1`   | 2    | `i = imax` |
| 3    | `j = 1`   | 4    | `j = jmax` |
| 5    | `k = 1`   | 6    | `k = kmax` |

For 2-D / single-cell-thick blocks only faces 1-4 are user-assignable; BCB
assigns faces 5/6 automatically, so they are drawn faintly for context.
