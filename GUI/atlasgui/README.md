# ATLAS GUI

One window over one `input.ini`: the GPB phases, the BCB boundary conditions,
the ICB initial state and the `[ATLAS-Parameters]` the tools share — the same
file `ATLAS GPB BCB ICB` reads — and the runs of GPB, BCB and ICB on it.

## Stages

| Stage | Panel | What it edits |
|-------|-------|---------------|
| Case | `mainwindow.py` | case directory, mesh, `[ATLAS-Parameters]`, overview |
| Phases | `gpbpanel.py` | `[GPB-PhaseN]`: gas, condensed/solid, real fluid |
| Boundaries | `bcbpanel.py` | `[BCB-BlockN]` + the named BC sections, on the 3-D mesh |
| Initial | `icbpanel.py` | `[ICB-Block*]`, `[ICB-BlockN]`: the initial state of every block, and in 3-D the state of every cell or the field ICB wrote |
| Review | `mainwindow.py` | the INI as it will be written, and the checks on it |
| Run | `runpanel.py` | runs GPB, BCB and ICB on the saved INI: their log and what they write |

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

An interpolated zone without turbulence keys takes the model ICB adopts from
its old solution (`icprofile.source_turbulence`, by the band names after the
pressure, as ICB's `detect_turbulence`), and the zone coverage checks the
turbulence of the other zones under it. A key ICB does not read gets ICB's hint
(`icmodel.closest_key`); a BC key BCB refuses with a hint (`bcmodel.REFUSED_BC_KEYS`:
the density-weighted turbulence of an ICB zone, the keys of earlier decks) is
marked in the BC editor and listed in Review.

`icgeom.state_map` gives, for every cell of a mesh block, the state ICB writes
there last -- the block's own or All blocks', or a zone's, the zone order and
the plenum rows of nozzle zones included -- and which cells a plenum leaves at
rest. The Initial stage paints it on `viewport.StateViewport`, the outer
surfaces of the blocks with a colour per cell; a click on a cell opens its
state.

After a run, the view shows the field ICB wrote instead (**Field**):
`icfield.py` reads `fromATLAStoSolver/<phase>-ic.tec` (ASCII Tecplot, cell
values, a zone `B<n>-<kind>` per mesh block) or `<phase>-ic.vtm` (its `.vts`
blocks, with pyvista) and derives what a gas's bands imply -- ρ, Y, T from the
molar masses of the phase file, |V| and the Mach number from the cp(T) of its
`thermo.dat`, as ICB computes them. `fieldcolors.py` holds the scales (the
reference blue ramp for a magnitude, blue and red arms of equal lightness about
a neutral grey for a signed quantity, built in OKLab and flipped on a dark
background), `fieldview.py` the controls and the colour bar. Focus never dims a
field's colours. `GUI/tests/test_icfield.py` (CTest `GUI-icfield`) checks the
scales and reads back fields ICB writes from decks of the suite, in both
formats: p, T from total conditions, Mach under a variable cp, Y come back as
the deck set them.

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

## What the Run stage knows

`runner.py` runs the tools as a user would from the case directory, `ATLAS
<TOOL> --input <ini>` through `ATLAS.sh`, one process after the other in the
order GPB, BCB, ICB, and stops at the first that fails (`RunSession`, QtCore
only). Each process is its own process group (a `setsid` before `exec`), so
Stop reaches the tool `ATLAS.sh` started; the `filelist.txt` `ATLAS.sh` made
and the staging directory of a stopped GPB are removed after it. The output is
read unbuffered (`PYTHONUNBUFFERED`, `GFORTRAN_UNBUFFERED_PRECONNECTED`), the
environment is the GUI's with `ATLASDIR`, the CEA tables of the build as
`scripts/setvars.sh` sets them, the Python of GPB (`ATLAS_PYTHON`) and the
threads of Settings → Tools (`preferences.tool_settings`).

A chained run needs two things the tools do not do, and the run does them:
BCB and ICB read the mesh under a default name (`read_mesh.f90`: `mesh.tec`,
`mesh.p3d`, `mesh.szplt`, the first that exists), so a mesh loaded under
another name is linked under the one of its format (`mesh_plan`); and they read
the `*phase.txt`, `*thermo.dat` and `*properties.dat` of the case directory,
where GPB does not write, so the tables GPB has just written are copied there
after it (the hand-off). `preflight` says beforehand what a run does and what
stops it, from the case alone: the INI to save, a tool not built, a Python
without Cantera, the mesh and the phase files BCB and ICB will read (stale,
older than GPB's, missing, or chosen by a `filelist.txt`), the GUI's own errors
in the stage of a tool that runs. What each tool wrote is the difference of
`fromATLAStoSolver/` before and after it.

`runlog.py` reads what a tool printed into its errors and warnings
(`messages`), each placed on a target of the GUI as its own checks are
(`(stage, index)`): the section the message names (`key K of section [S]`
first, then `section [S]`, then a bracketed name the deck holds), else the
section that names a file the message names, else what the tool was building
(GPB announces each phase, ICB each block), else the phase files (GPB's stage)
or the tool's stage. Lines indented under a message go with it, a repeated
message is counted once, a traceback or a Fortran runtime error is one error,
and a failure without a message gets one. The Run stage reads a tool's lines
when it ends; Review lists the messages of the last run with the checks of
their stage while the case is the one that ran, greyed once it has changed.

`GUI/tests/test_runner.py` (CTest `GUI-runner`) checks the preflight and the
messages with the standard library only (and the messages of two refused decks
of the suite as BCB and ICB print them today), and with PyQt6 the runs: a chain on a stand-in
launcher (order, failure, the hand-off of the tables alone, the mesh link),
Stop ending the launcher's child, ICB run by the GUI writing what `ATLAS ICB`
typed in a shell writes, and GPB then ICB when the Python has Cantera.

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

## What the tools wrote, drawn

Each stage draws what its tool wrote, and a case opens from its INI or from a
folder of those files alone (`mainwindow.open_case`: the folder's INI if it
has one, the mesh the tools read there, else its one mesh file; the cases
opened last are kept by `preferences.recent_cases`). The files are those of
`fromATLAStoSolver/`, or of the folder itself when it has none
(`tables.output_dir`: a set of files copied out of a run).

* **Phases.** `tables.py` reads the ASCII Tecplot tables GPB writes -- the
  1-D zones of a gas, a condensed or a solid phase, the (p, h) grid of a real
  fluid (BLOCK, p fastest) -- into the sheets the stage offers: the
  thermodynamics and the transport of a gas as one, its diffusion, its rates
  (the reactions named from `chemistry-info.txt`), the properties of a
  condensed or solid phase, the grid of a real fluid. `plotview.py` draws
  them with QPainter: `XYPlot` curves against T (one y axis, the categorical
  palette in its fixed order, a colour kept per curve while it is drawn,
  hover crosshair, drag to zoom), `MapPlot` a map with its iso-lines
  (`contour_segments`, marching squares) on the scales of `fieldcolors.py`.
  `tableview.py` is the stage's card.
* **Boundaries.** `bcfile.py` reads `<phase>-bc[<L>].txt`: every record line
  (4, 5 or 6 integers) wherever the payload lines in between, the BC id of
  every cell of every face in arrays the shape of the face's cells (m
  fastest, as BCB counts them), the copies of a dispersed phase, the payload
  of a cell decoded by name (`decode`), the blocks of a phase placed on the
  mesh by the deck's `phase` keys or by size (`block_map`), a multigrid
  level drawn over the cells it covers (`fine_ids`). `bcview.py` gives every
  cell its colour (the categorical palette by id; interfaces and null grey)
  and `viewport.MeshViewport.set_written` draws them in place of the faces.
* **Initial.** The field ICB wrote, above.

`GUI/tests/test_outputs.py` (CTest `GUI-outputs`, numpy) reads tables and
boundary files of every form, checks the plot scales and the recent cases,
compares GPB's cp of O2 with Cantera's, and runs BCB on a suite deck to find,
face by face, the id the deck's section implies (and the connection BCB makes
where another block meets a face).

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
| `runner.py`, `runpanel.py`, `runlog.py` | the runs of the tools, the Run stage, their messages placed on the sections they name |
| `icfield.py`, `fieldcolors.py`, `fieldview.py` | the field ICB wrote, the colour scales, the colour bar |
| `tables.py`, `plotview.py`, `tableview.py` | the tables GPB wrote, their plots, the Phases stage's card |
| `bcfile.py`, `bcview.py` | the boundary files BCB wrote, the Boundaries stage's written view |
| `mainwindow.py` | the shell: stages, opening a case (INI, folder, recent), status, Case and Review (the checks by stage, each tied to its INI section) |
| `__main__.py` | CLI entry point / dependency guards |

`mesh_io.py`, `faces.py`, `bcmodel.py`, `gpbmodel.py`, `icmodel.py`, `icgeom.py`,
`icprofile.py`, `icfield.py`, `tables.py`, `bcfile.py`, `document.py` and `filekeys.py` carry no GUI dependency and can be imported and tested headlessly;
`preferences.py` needs QtCore only.

## Face numbering (fixed by BCB)

| Face | Location  | Face | Location   |
|------|-----------|------|------------|
| 1    | `i = 1`   | 2    | `i = imax` |
| 3    | `j = 1`   | 4    | `j = jmax` |
| 5    | `k = 1`   | 6    | `k = kmax` |

For 2-D / single-cell-thick blocks only faces 1-4 are user-assignable; BCB
assigns faces 5/6 automatically, so they are drawn faintly for context.
