# ATLAS case-setup GUI

One window over one `input.ini`: the GPB phases, the BCB boundary conditions,
the ICB initial state and the `[ATLAS-Parameters]` the tools share — the same
file `ATLAS GPB BCB ICB` reads.

## Stages

| Stage | Panel | What it edits |
|-------|-------|---------------|
| Case | `mainwindow.py` | case directory, mesh, `[ATLAS-Parameters]`, overview |
| Phases | `gpbpanel.py` | `[GPB-PhaseN]`: gas, condensed/solid, real fluid |
| Boundaries | `bcbpanel.py` | `[BCB-BlockN]` + the named BC sections, on the 3-D mesh |
| Initial | `icbpanel.py` | `[ICB-Block*]`, `[ICB-BlockN]`: the initial state of every block, and the state of every cell in 3-D |
| Review | `mainwindow.py` | the INI as it will be written, and the checks on it |

Sections of tools not edited here (`[STB-*]`, `[MDB-*]`, `[KAnT-*]`)
are preserved verbatim through a save, as is `[BCB-Block*]` until a mesh says
how many blocks it applies to.

## What the ICB panel knows

`icmodel.py` holds the ICB sections: `[ICB-BlockN]`, `[ICB-Block*]`, and the
zone sections an ICB block names in `zone<n>`. A zone section has no prefix,
like a BC, so BCB takes every named section except those; a new BC cannot take
the name of any section of the file (`AtlasDocument.section_names`). The key
schema is read from ICB's generated `docs/user-guide/icb/input-reference.md`
(`ICB --write-config-doc`), so the forms cannot drift from the tool.

The model also knows what a state means to ICB: the pair that fixes a gas
state, the velocity input, the turbulence model the keys imply, and the phases
a block builds (`case_phases`: the deck's GPB phases, then the `*phase.txt`
files ICB reads). `ICBDocument.validate` gives the checks of the Initial stage
and of Review. A choice the keys cannot show yet (total conditions picked
before any value is typed) is remembered by the panel, per state.

A block split into zones carries its layout (`direction`, `zone<n>`,
`range<n>`) and the zone sections their states; `ICBDocument.split_block`,
`merge_zones` and `ICBlock.set_direction` move the keys between them, and
`validate` reports what ICB refuses in a layout. `icgeom.py` puts the zones on
the mesh as ICB does -- the cell centre, or index, against each range, limits
included, r and t about the x axis (in the x-y plane on a pure 2-D mesh), the
zones in order, the plenum rows of a nozzle zone -- and gives the cells no
zone writes, which ICB stops on.

The nozzle flow is a special mode (`icmodel.SPECIAL_MODES`), offered apart from
the general ones (`MODES`) where the block fits it: `icgeom.NozzleGeometry`
reads the cross-sections of a block as ICB's nozzle law does and refuses the
blocks ICB refuses (`check_nozzle_geometry`), `icgeom.plenum_rows` gives the
rows at rest (centred upstream of `nozzle-threshold`; the law takes the others),
and `icbdialogs.NozzlePlot` draws them.

`icgeom.state_map` gives, for every cell of a mesh block, the state ICB writes
there last -- the block's own or All blocks', or a zone's, the zone order and
the plenum rows of nozzle zones included -- and which cells a plenum leaves at
rest. The Initial stage paints it on `viewport.StateViewport`, the outer
surfaces of the blocks with a colour per cell; a click on a cell opens its
state.

A value can come from a profile file instead (`<key>-file`, with
`<key>-direction` for a table): `icprofile.py` reads a table line by line as
ICB's `read_ascii_table` does and the header of a Tecplot field (the variable
ICB takes, and whether it is cell-centred), and finds the cells of a zone a
table misses on the mesh. The profile dialog (`icbdialogs.py`) edits a table in
place and writes it only when its rows changed.

`GUI/tests/test_icmodel.py` (CTest `GUI-icmodel`, no Qt) passes every deck of
the test suite through the document and back, and checks that `validate`
flags no ICB deck the tool accepts while catching the ones it refuses.
`GUI/tests/test_icgeom.py` (CTest `GUI-icgeom`, numpy) runs ICB on random zone
decks over a pure 2-D, an extruded and a 3-D mesh and checks that `icgeom`
finds the cells ICB writes after each zone and those it leaves unwritten, that
the state `icgeom.state_map` gives every cell is the one ICB writes there
(nozzle zones and their plenums included), that `icprofile` finds the cells a
zone's table misses as ICB does, and that the GUI refuses the nozzle flow where
ICB refuses it and finds the plenum rows ICB writes.

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
| `icmodel.py` | `ICBDocument`: block and zone states, what they mean to ICB, its checks |
| `icgeom.py` | the cells each zone of a block takes on the mesh, the state every cell ends up with, and the cross-sections the nozzle law reads, as ICB (numpy only) |
| `icprofile.py` | profile files (`<key>-file`): tables and Tecplot fields read as ICB reads them |
| `database.py` | what `database/` holds, for the pickers |
| `filekeys.py` | which INI keys name a file, and how a value resolves |
| `mesh_io.py` | multiblock Tecplot / Plot3D reader (numpy only) |
| `faces.py` | BCB face numbering + node extraction (numpy only) |
| `viewport.py` | PyVista `QtInteractor` viewports: the Boundaries one (face picking, block toggling) and the Initial one (a colour per cell, cell picking) |
| `widgets.py` | `UIKit`: themed widget factory shared by the panels, sizes in code |
| `theme.py` | seed palettes, theme specs and overrides, the Qt stylesheet and its scaling |
| `preferences.py` | the settings store and the user's theme files |
| `settingsdialog.py` | the Settings window: Appearance, Colours (theme editor) |
| `icons.py` | vector icons drawn with QPainter; the app icon from `assets/` |
| `filewidgets.py` | the file field, the browse column, the files-of-a-section dialog |
| `gpbpanel.py`, `gpbdialogs.py`, `bcbpanel.py`, `bcbdialogs.py`, `icbpanel.py`, `icbdialogs.py` | the stage panels and their dialogs |
| `mainwindow.py` | the shell: stages, file actions, status, Case and Review (the checks by stage, each tied to its INI section) |
| `__main__.py` | CLI entry point / dependency guards |

`mesh_io.py`, `faces.py`, `bcmodel.py`, `gpbmodel.py`, `icmodel.py`, `icgeom.py`,
`icprofile.py`, `document.py` and `filekeys.py` carry no GUI dependency and can be imported and tested headlessly;
`preferences.py` needs QtCore only.

## Face numbering (fixed by BCB)

| Face | Location  | Face | Location   |
|------|-----------|------|------------|
| 1    | `i = 1`   | 2    | `i = imax` |
| 3    | `j = 1`   | 4    | `j = jmax` |
| 5    | `k = 1`   | 6    | `k = kmax` |

For 2-D / single-cell-thick blocks only faces 1-4 are user-assignable; BCB
assigns faces 5/6 automatically, so they are drawn faintly for context.
