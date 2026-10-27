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

Sections of tools not edited here (`[STB-*]`, `[MDB-*]`, `[KAnT-*]`)
are preserved verbatim through a save, as is `[BCB-Block*]` until a mesh says
how many blocks it applies to.

The ICB sections are read by `icmodel.py`, which has no panel yet: the
`[ICB-BlockN]` and `[ICB-Block*]` sections, and the zone sections an ICB block
names in `zone<n>`. A zone section has no prefix, like a BC, so BCB takes
every named section except those; a new BC cannot take the name of any section
of the file (`AtlasDocument.section_names`). The ICB key schema is read from
ICB's generated `docs/user-guide/icb/input-reference.md`.
`GUI/tests/test_icmodel.py` (CTest `GUI-icmodel`) passes every deck of the test
suite through the document and back.

## What the GPB panel knows

The schema — defaults, allowed values, one-line descriptions used as tooltips —
is read at runtime from GPB's own `src/GPB/input_registry.py`, so the forms
cannot drift from the tool. The pickers read the repository: mechanisms and
phase files from `database/chemistry/`, species and materials from
`database/thermo/nasa9.yaml` and `burcat.yaml`, Cantera's NASA7 files and the
SP-database (`sp_custom.py`), all scanned lazily; fluids from CoolProp when it
is importable.

A species or material picker lists one database at a time and only the states
the phase type is made of: gases for a gas, liquids and/or solids for a
dispersed phase, solids for a wall. The state comes from the tag of the name
(`H2O(L)`, `AL(cr)`, `ZrO2(II)`, `CaO(S)`, ...; NASA9 also lists its gases
first), see `database.species_state`. GPB looks every name of a phase up in the
one database `thermo` selects, so names picked from another database switch
`thermo` to it, and the picker says so before OK.

A gas phase is described by its **composition sources** (mechanism, phase file,
CEA equilibrium, Cantera equilibrium, prescribed mixture, explicit species),
which GPB combines, so they are independent switches rather than one choice.
Condensed and solid phases are a table of materials; their per-material solver
models, the constant properties of a calorically-perfect gas, a mixture
composition and the raw key list each open in their own dialog
(`gpbdialogs.py`).

## Files a case names

`filekeys.py` is the one place that knows which keys carry a path — BCB's
`<var>-file` tables and `*-time-file` series, `line-file`, `range-file`,
`eq-CEA-file`, a dispersed `<phase>-distribution`, GPB's `reactions`, `phase`
and `CEA-file`, the `BCB-file` / `ICB-file` / `input-file` of
`[ATLAS-Parameters]`, and the ICB, STB and MDB keys for when those stages
arrive. Each one carries what it names (a file, a directory, or a *stem* a tool
resolves on its own search path), the dialog filters, and the limits the tools
impose — the 32-character cap on a BC series name, the search path of a GPB
mechanism. Panels never test a path themselves: they call
`filekeys.status()` for the mark and `filekeys.value_for()` for what to write.

## Display

Sizes are written for a 100 % interface and scaled: the stylesheet in `px`
(device-independent; a `pt` is drawn 25 % smaller on macOS), the sizes set in
code through `UIKit.px`. The factor is the screen's (`theme.screen_scale`: 1 on
a laptop, up to 1.3 on a 4K-class screen, re-read when the window changes
screen) times the text size of the **Display** menu (Ctrl/Cmd +, −, 0). The
window opens at the design size or the screen's, whichever is smaller, and the
header drops its button labels when the window is narrower than it needs.

## Settings

**Display → Settings…** (Cmd+, on macOS, Ctrl+, elsewhere) opens one window
of pages (`settingsdialog.py`): **Appearance** — the theme from a gallery of
miniatures, the text size — and **Colours**, the theme editor. Every change
previews on the whole application; Cancel puts back what was last applied,
Apply/OK store it. A page is a widget with `refresh()` and
`restore_defaults()`, listed in `SettingsDialog.PAGES`.

A theme is a *spec*: the seed colours plus *overrides*, derived tokens the
theme sets itself (`theme.derive`). The derivation keeps text at WCAG AA
(4.5 : 1) on every surface it is drawn on and mesh edges at 3 : 1: a derived
shade is lifted toward the text colour only where a palette would make it too
faint (`theme._legible`), and text on a filled colour is black or white by
contrast (`theme._on`). The editor shows `theme.SEED_GROUPS` and
`theme.TOKEN_GROUPS`, the WCAG contrast of the pairs that carry text, and
never changes a built-in theme: the first edit makes a copy. The user's themes
are JSON files (`"atlas-theme": 1`) in `<config>/ATLAS/themes/`
(`~/Library/Preferences` on macOS, `~/.config` on Linux), so they can be
imported, exported and shared; `preferences.py` owns that directory and the
QSettings store.

## Running

```bash
ATLAS GUI                       # or: ATLAS BCB-GUI, which opens on Boundaries
python GUI/ATLAS_GUI.py [mesh] [--ini input.ini] [--stage case|gpb|bcb|review]
python -m atlasgui ...
```

## Dependencies

`numpy`, `PyQt6`, `pyvista`, `pyvistaqt` — in `ct-env.yaml` (`pyqt`, `pyvista`,
`pyvistaqt`). Refresh with `conda env update -f ct-env.yaml`.

`assets/atlas-icon.svg` is the application icon (window, Dock, header) and
`atlas-icon.png` its 512 px render, which is what is loaded. It is a
**placeholder**: replace both files with the ATLAS logo.

## Layout

| File | Responsibility |
|------|----------------|
| `document.py` | `AtlasDocument`: routes the INI sections to the tool that owns them |
| `gpbmodel.py` | GPB phases, the schema from `input_registry.py`, validation |
| `bcmodel.py` | `BCBDocument`: blocks, faces, named BC sections, INI I/O |
| `database.py` | what `database/` holds, for the pickers |
| `filekeys.py` | which INI keys name a file, and how a value resolves |
| `mesh_io.py` | multiblock Tecplot / Plot3D reader (numpy only) |
| `faces.py` | BCB face numbering + node extraction (numpy only) |
| `viewport.py` | PyVista `QtInteractor` viewport, picking, block toggling |
| `widgets.py` | `UIKit`: themed widget factory shared by the panels, sizes in code |
| `theme.py` | seed palettes, theme specs and overrides, the Qt stylesheet and its scaling |
| `preferences.py` | the settings store and the user's theme files |
| `settingsdialog.py` | the Settings window: Appearance, Colours (theme editor) |
| `icons.py` | vector icons drawn with QPainter; the app icon from `assets/` |
| `filewidgets.py` | the file field, the browse column, the files-of-a-section dialog |
| `gpbpanel.py`, `gpbdialogs.py`, `bcbpanel.py`, `bcbdialogs.py` | the stage panels |
| `mainwindow.py` | the shell: stages, file actions, status, Case and Review |
| `__main__.py` | CLI entry point / dependency guards |

`mesh_io.py`, `faces.py`, `bcmodel.py`, `gpbmodel.py`, `document.py` and
`filekeys.py` carry no GUI dependency and can be imported and tested headlessly;
`preferences.py` needs QtCore only.

## Face numbering (fixed by BCB)

| Face | Location  | Face | Location   |
|------|-----------|------|------------|
| 1    | `i = 1`   | 2    | `i = imax` |
| 3    | `j = 1`   | 4    | `j = jmax` |
| 5    | `k = 1`   | 6    | `k = kmax` |

For 2-D / single-cell-thick blocks only faces 1-4 are user-assignable; BCB
assigns faces 5/6 automatically, so they are drawn faintly for context.
