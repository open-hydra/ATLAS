# ATLAS GUI

The **ATLAS GUI** sets up a case the way the tools read it and runs them on
it. The case is one `input.ini` holding the GPB phases, the BCB boundary
conditions, the ICB initial state and the shared `[ATLAS-Parameters]`: the same
file `ATLAS GPB BCB ICB` consumes, so the GUI is an editor for the case, not a
separate project format. The **Run** stage then runs GPB, BCB and ICB on it,
as `ATLAS GPB BCB ICB` would from the case directory, with their log and the
files they write; each stage draws what its tool wrote — the property tables
of the phases, the BC of every boundary cell, the initial field. A case can
equally be opened from its INI or from a folder of files the tools wrote, to
look at them.

```bash
ATLAS GUI                      # the whole case
ATLAS GUI -i input.ini         # open an existing case
ATLAS GUI --case run_folder    # open a case folder: its INI, mesh and files
ATLAS BCB-GUI                  # the same window, opened on Boundaries
```

or directly:

```bash
python utils/ATLAS/GUI/ATLAS_GUI.py [mesh] [--ini input.ini | --case folder] [--stage gpb]
```

The window opens fitted to the screen. **Display** (top right) sets the
**text size** — 100 % is fitted to the screen, and Ctrl/Cmd +, Ctrl/Cmd − and
Ctrl/Cmd 0 change it from anywhere — and the **colour theme**; both are
remembered. On a narrow window the header buttons keep only their icons, with
the label as tooltip. The window is never smaller than 1080 × 640 at 100 %
text (more at a larger size, never more than the screen has), and a page that
does not fit what it is given scrolls — a card is never squeezed over
another, nor a row cut off.

**Display → Settings…** (Cmd+, on macOS) opens the Settings window. Every
change shows on the application at once; **Apply** or **OK** keep it,
**Cancel** puts back what was there, **Restore Defaults** resets the page.

* **Appearance** — pick the theme from previews of each one, and the text size.
* **Tools** — how the Run stage starts the tools: the ATLAS directory (empty:
  the one the GUI belongs to; the page says whether `ATLAS.sh` is there and
  when BCB and ICB were built), the Python GPB runs with (empty: the GUI's own
  if it has Cantera, else `ATLAS_PYTHON`, else the conda environment
  `ATLAS.sh` activates; **Check** asks it for Cantera) and the OpenMP threads
  of BCB and ICB (empty: as the environment says).
* **Colours** — the theme editor. The *base colours* (background, panels,
  text, accent, the status colours, the 3-D view) set the look; the *derived
  colours* (borders, hover, selection, labels, the INI preview, …) follow them
  unless you set one, and ↺ lets it follow again. A preview and the WCAG
  contrast of every pair that carries text show the result as you edit.
  Built-in themes are never changed: your first edit makes a copy. Every
  theme keeps text at WCAG AA (4.5 : 1) unless you override a colour below
  it, which the contrast panel then flags.
  **Duplicate**, and **Manage → Rename / Delete / Import / Export**, handle
  your themes, which are saved as JSON files you can share
  (`~/Library/Preferences/ATLAS/themes` on macOS, `~/.config/ATLAS/themes` on
  Linux).

!!! tip "Nothing is hidden"
    Every field writes straight into the INI — there is no Apply button to
    forget — and the **Review** stage shows the exact file as it will be
    written. Anything the forms do not model is kept untouched and can be
    edited as raw `key = value` lines.

---

## The workflow

The rail on the left follows the order the tools run in.

| Stage | What it holds |
|-------|---------------|
| **Case** | Where the case lives, the mesh, `[ATLAS-Parameters]`, the cases opened last, what the tools wrote, and an overview of what is set up |
| **Phases** | GPB: one card per `[GPB-PhaseN]`, with an editor that follows the phase type, and the tables GPB wrote, drawn |
| **Boundaries** | BCB: the mesh in 3-D, its blocks and faces, and the BCs assigned to them, or the BC of every boundary cell as BCB wrote it |
| **Initial** | ICB: the initial state of every block, `[ICB-Block*]` and `[ICB-BlockN]`, and the mesh in 3-D with the state every cell takes, or the field ICB wrote (p, T, Mach, …) |
| **Review** | The INI as it will be written, plus every check the GUI can make on it, by stage |
| **Run** | GPB, BCB and ICB run on the case: what the run will do first, the log of every tool, the files written into `fromATLAStoSolver/` |

### The status bar

Along the bottom, whatever the stage: the case file (and **unsaved** when it
has changes), the number of **phases** and **blocks**, then two meters that
fill as the case is set up and turn green when it is complete —
**coverage**, the faces of the mesh that have a boundary condition, and
**initial**, the blocks ICB can write: those with an initial state, their own
section or `[ICB-Block*]`'s, and no error in it (a block with none, or whose
state has an error, is not counted; the checks of **Review** say which). On
the right, how the last run ended and the number of errors and warnings. A
long file name or message is shortened with an ellipsis, its whole text in
the tooltip, rather than pushing the others out.

Sections belonging to tools the GUI does not edit yet (`[STB-*]`, `[MDB-*]`,
`[KAnT-*]`) are carried through a save untouched, so a shared case file never
loses another tool's setup. The zone sections of a multizone ICB block
(`zone1 = plenum` names `[plenum]`) belong to ICB: they are not listed as
boundary conditions, and a new BC cannot take their name.

### Opening a case

**Open** (header) offers:

* **INI file…** (Cmd/Ctrl+O) — the case of an `input.ini`. The mesh BCB and
  ICB read in its folder (`mesh.tec`, `mesh.p3d`) is loaded with it, and the
  stages draw what the tools wrote there.
* **Case folder…** (Cmd/Ctrl+Shift+O) — a folder: its `input.ini` (or its one
  INI, or the one you choose when there are several), its mesh — the one the
  tools read, else the one mesh file there — and the files of its
  `fromATLAStoSolver/`. A folder with **no INI** opens too: the case is then
  the files alone, to look at — the tables, the boundary file, the initial
  field — and a deck written from there is a new one. Choosing a
  `fromATLAStoSolver/` folder itself opens the case around it; a folder of the
  tools' files with no `fromATLAStoSolver/` (copied out of a run) is read as
  it is.
* **Recent** — the last eight cases opened or saved, an INI or a folder.

Opening a case over one with unsaved changes asks first. The **Case** stage
offers the same (**Open INI…**, **Open folder…**, the recent cases), and
**What the tools wrote** lists, tool by tool, the files the case holds, each
with the button that draws them in its stage.

---

## Phases (GPB)

Each phase becomes one property table in `fromATLAStoSolver/`, named after the
phase `name`. **Add phase** offers the types of
[the GPB input reference](./gpb/input-reference.md); the editor then shows only
what that type uses.

=== "Gas"

    A gas phase is built from **composition sources**, which GPB combines: a
    finite-rate mechanism, a full Cantera phase file, a CEA or Cantera
    equilibrium, a prescribed mixture, an explicit species list. Switch on the
    ones the phase uses and fill in their fields; the mechanism and phase-file
    pickers list the yaml files of `database/chemistry/` and of the case
    directory, report how many species the chosen file holds, and take a file
    from anywhere else through **Browse…**.

    **Pick species…** lists the gaseous species of the mechanism or of a
    database (NASA7, NASA9, Burcat) — never a liquid or a solid.

    **Constant properties…** turns the species list into a
    calorically-perfect gas (the `cp`, `cv`, `gamma`, `R`, `mw`, `mil`, `kl`,
    `Pr` arrays), one column per species.

=== "Condensed / solid"

    The materials are a table under the `thermo` database they are read
    from: one row per material, one column per per-material key (`groups`,
    `rho`, `cp`, `k`, `h0`, `psat-vapour`, `psat-liquid`). A column whose
    values are all equal is written once, which is what GPB broadcasts.
    **From database…** picks materials out of NASA7, NASA9, Burcat or the
    SP-database, listing only what the phase type can be made of: liquids for
    a liquid-dispersed phase, solids for a solid-dispersed phase or a wall,
    both for a condensed-dispersed one.

    **Per-material models…** opens the solver models (`evaporation`,
    `interface`, `combustion`, `solidification`, the Beckstead and
    solidification constants, …) as one row per key and one column per
    material.

=== "Real fluid"

    The EOS backend, the fluid name (from CoolProp when it is importable) and
    the (p, T) bounds of the table with its grid sizes.

!!! note "The picker and `thermo`"
    GPB looks every species or material name of a phase up in the single
    database `thermo` selects (NASA9 when it is not set). The pickers open on
    that database; picking from another one sets `thermo` to it, and the
    picker says so — including when that replaces the thermo records of a
    mechanism. With `CEA-file` a gas reads NASA9 only, so only NASA9 is
    offered.

### The tables GPB wrote

Right of the editor, **Tables GPB wrote** draws the tables of the phase
selected, read from `fromATLAStoSolver/` (or from the case folder, for phase
files given to BCB and ICB by hand); the menu above the plot shows any other
phase the case holds, and says when the phase selected has not been written
yet.

| Phase | Sheets | Drawn as |
|-------|--------|----------|
| Ideal gas | *Thermodynamics and transport* (`thermo.dat`, `transport.dat`: cp, h, s, dcp/dT, μ, λ), *Binary diffusion* (`diffusion.dat`), *Reaction rates* (`chemistry-Arrhenius.dat`: kf, kb), *Fall-off rates* (Troe, Lindemann: k∞, k₀, Kc, Fcent) | curves against T, one per species, pair or reaction |
| Condensed, solid | *Properties* (`properties.dat`: cp, ρ, h or λ and e, psat) | curves against T, one per material |
| Real fluid | *Property grid* (`thermo.dat` and `transport.dat`: T, ρ, cp, s, a, the derivatives of ρ, μ, λ) | a map over p and h |

A curve keeps its colour while it is drawn: tick the species, materials,
pairs or reactions under the plot, up to eight (the list is the legend, with
a filter when it is long); up to four, their names are written at the ends of
the lines. The reactions are named from `chemistry-info.txt`, as numbered in
the mechanism (`R4 · 0.5 O2 + H2 ⇌ H2O`, ⇌ where the reaction is reversible).
Rates and diffusion coefficients open on a logarithmic scale (**Log scale**),
which reaches 24 decades below the largest value: a rate at 1 K is 1e-300.
**Hover** for the values at a temperature; **drag** across the plot to zoom
into a range of T, **double-click** (or **All T**) to see all of it.

The map of a real fluid colours the quantity chosen on the (p, h) grid of the
table — one hue, light to dark, or blue and red about zero for a derivative
that changes sign — with its iso-lines at the values the colour bar marks;
hover gives every property at that (p, h). h and s are counted from 0 at
(Tmin, pmin), as GPB writes them.

Under the plot: the files and when GPB wrote them, and a warning when the INI
was saved after them or the case has changes not saved. **Tables** on GPB's
row of the Run stage opens this view. The **Tables** switch in the header puts
the card away, which gives the editor the whole width (a condensed phase's
table of materials is wide); it is remembered, and asking for a table (from
the Run or the Case stage) brings the card back.

---

## Boundaries (BCB)

See [BCB GUI](./bcb/gui.md) for the mesh view, face picking and BC assignment.

**New** opens a small dialog: the name of the section, its type (with a line
saying what that type is for), and the files that type reads — pick them there
and the section is created with them. Everything it offers can also be set
afterwards, from the BC editor.

A key BCB refuses in a BC is shown red in the BC editor, its reason in the
tooltip, and listed in **Review**: the density-weighted turbulence of an ICB
zone (`rhoNuTilde`, `rhoK`, `rhoOmega`, `rhoRij` — a boundary takes `nuTilde`,
`k`, `omega`, `Rij` specific, and the solver multiplies them by the density of
the state it builds there), and the keys of earlier decks (`kappa`, `mit`,
`rt`, …). With `strict-keys = F` BCB warns instead of stopping, and so does
Review.

Selecting a **block** (rather than a face) shows which GPB phases live in it:
the chips are the phases defined in the Phases stage, and they write the
block's `phase` key. No chip selected means every phase, which is what BCB
assumes when the key is absent.

### What BCB wrote

**Assigned | Written**, at the top of the 3-D view, switches from the BCs the
deck assigns to the faces to the boundary file BCB wrote
(`fromATLAStoSolver/<phase>-bc.txt`, [BCB output](./bcb/output.md)): every
cell of every face in the colour of the BC id it was written with. This is
what the solver reads, which the deck alone does not show: where another
block meets a face BCB connects the two (`101`) whatever the face was given,
a chimera face gets its donors, a wall becomes a heat-flux or a temperature
wall (`301`, `302`) from the keys of its section, an inlet the variant its
keys select (`401`–`421`).

The BCs take the categorical colours in the order of their ids; the faces
between blocks — connections, chimera, periodic — and the null BC are neutral
grey, so the boundaries stand out. The legend under the view names every id
and counts its cells. A **click on a cell** outlines it and gives its record:
the block, the face, the cell, the id and what it is, and the values of its
payload by name (`T = 2000, ks = 0, eps = 0`; the mass fractions by species;
the neighbour of a connection; the donor counts of a chimera cell); the face
is selected in the tree, with what the deck assigns it on the right.

The menu over the legend picks the phase, and a multigrid level (`bc2.txt`,
…, each of its cells drawn over the mesh cells it covers). The blocks of a
phase are numbered from 1 in its own file: they are placed on the mesh by the
`phase` keys of the deck, or, with no deck, by their sizes in mesh order; a
block of another phase stays faint. A dispersed phase writes its table once
per material and population: the colours are the first copy's, a click shows
each. The notes say when BCB wrote the file, warn when the INI was saved
after it or the case has changes not saved, and when the file does not fit
the mesh on the screen. The faces 5 and 6 of a planar block, which BCB sets
itself, are not drawn. **Boundaries** on BCB's row of the Run stage opens this
view.

---

## Initial (ICB)

The list holds **All blocks** — the `[ICB-Block*]` section, the state of every
block without a section of its own — and one row per block of the mesh (of the
BCB deck when no mesh is loaded). A row says where the block's state comes
from: its own section, *same as All blocks*, or *no initial state* (red: ICB
stops on it). Most cases give All blocks a state and override a few blocks with
**Give it its own state**, which starts from a copy.

One section gives the state of every phase the block builds, so the editor
shows a card for each thing the state needs, for the phases of the block:

| Card | What it writes |
|------|----------------|
| **Phases** | the block's `phase` key (none selected: every phase, as ICB assumes) |
| **How the field is built** | *Uniform* or *Interpolate* (`old-solution`), the general ways; **Special**: *Nozzle flow* (`type = nozzle`) |
| **Gas state** | two of `p`, `T`, `p0`, `T0`, `rho`, chosen as a pair; ICB derives the rest |
| **Velocity** | the Mach number (`vel` for a real fluid) with the flow angles, or `u`, `v`, `w` |
| **Composition** | the mass fractions `y<species>`, with their sum, or a CEA equilibrium (`eq-CEA-file`) |
| **Turbulence** | the model and its quantities, specific (`k`, `omega`, …) or density-weighted (`rhoK`, …) |
| **Solid**, **Dispersed phase**, **Real fluid** | `T` and `material`; `krho`, `kT`, `dp` or `rp`, `Pp`; `p` with `T` or `h` |
| **Nozzle flow**, **Interpolation** | `p0`, `T0`, `nozzle-direction`, `nozzle-threshold`; the source, the law, `old-block-id`, `old-species` |

The species are those of the phase files ICB reads (`*phase.txt` in the case
directory, then `fromATLAStoSolver/`, where GPB writes them), else the species
list of the gas in the Phases stage. The angles `alpha` and `beta` are shown in
degrees and written in radians, which is what ICB reads ([Velocity](./icb/ic-setup.md#velocity)).
A gas given by total conditions takes its speed either way: ICB expands `p0` and
`T0` at the speed of `u`, `v`, `w` as at a Mach number
([Total conditions](./icb/ic-setup.md#total-conditions)).

The **Checks** card under the form lists what ICB would stop on, from the deck
alone: a block with no state, a gas state without a pair, a speed given twice
(`mach` and `u`, `v`, `w`), mass fractions that do not sum to 1, a key ICB does
not read (with ICB's hint: the name to use instead for the keys of earlier
decks, else the key it differs from in letter case or by a letter or two — ICB
reads keys case-sensitively, `rhok` is not `rhoK`), a turbulence model without
its quantities, a value that is not physical. They are listed in **Review** too.
In **All keys…**, a key typed in the wrong letter case takes the documented
spelling.

### Special initialisations

*Uniform* and *Interpolate* build any block. A special initialisation is a law
for one kind of geometry, so it sits apart, under **Special**, and is offered
only where it applies: a greyed entry says why not. When it is chosen, the
button names it and the editor shows its card.

**Nozzle flow** starts a nozzle from rest in its plenum
([Nozzle initialization](./icb/ic-setup.md#nozzle-initialization-ig)). It
builds an ideal gas, and the block must be a nozzle along x: a duct about the
x axis meshed along it, the cell centres advancing along +x with i, the rows of
cells its cross-sections between the walls j = 1 and j = J, with a throat. ICB
stops on any other block, and so the GUI does not offer the law there once the
mesh is loaded. Choosing it drops the static state and the velocity of a
gas-only block (the law sets them in every row); *Back to a uniform state*
drops the nozzle keys.

The **Nozzle flow** card takes `p0` and `T0`, the direction of the flow and
the x where the plenum ends: the rows centred upstream of it — below it towards
+x, above it towards −x — stay at rest (empty: no plenum). A plot shows the
cross-sections as the law reads them, A/A* against x: the throat, the plenum
rows shaded, the subsonic and supersonic rows of the law. The line under it
says whether the block is a nozzle and which rows are the plenum. On a block
that is not one, the curve is drawn red, the line names what ICB refuses — a
constant section, a row without cross-section, i not along +x — and Review
lists it as an error.

### Profiles

A value ICB can read cell by cell — `p`, `T`, `p0`, `T0`, `rho`, `mach` of a gas,
`p`, `T`, `h`, `vel` of a real fluid, `T` of a solid, and the mass fraction of a
species (**Profile…** under the species table) — has a profile button beside it.
It opens the profile of that value, given one of two ways
([Variable initialization](./icb/ic-setup.md#variable-initialization-file-driven)):

* **Table along a direction** — two columns, the coordinate along `x`, `y`, `z`,
  `r` or `t` and the value, edited in the dialog and written to the file named
  (only when the rows changed; an existing file is overwritten only when you
  agree). A plot shows the table against the span of the cell centres of the
  block or zone: ICB stops on a cell the table does not reach, so the part of
  the span outside the table is drawn red and counted.
* **Tecplot field** — a structured field file; the dialog reads its header and
  says which variable ICB takes (the first after the coordinates) and whether it
  is cell-centred, as ICB needs.

The profile replaces the constant (ICB refuses both), and **Use a constant**
gives the value back as one number. A field shows its profile file in place of
the value. The checks read the files too: a table that is not monotone or not two
numbers per row, a table that misses cells of the zone on the mesh, a field that
is not cell-centred.

### Zones

A block — or All blocks — can give parts of itself different states: **Split
into zones…** cuts it along one letter at the values you give and shows the
zones it would make, with the cells each takes on the mesh. Every zone starts
from the state the block had; the block then keeps only its layout
(`direction`, `zone<n>`, `range<n>`) and each zone becomes a section of its
own.

The zones are listed under their block, and selecting one edits its state with
the same cards as a block. The block's page holds the layout:

* **Ranges along** — the letters the ranges are given along, three at most:
  `x`, `y`, `z` (the cell centre), `r` and `t` (the distance from the x axis
  and the angle about it, in degrees from y towards z; on a 2-D mesh both are
  taken in the x-y plane), `i`, `j`, `k` (the cell index, from 1). A letter
  added gives every zone the full extent of the block along it.
* **The zone table** — one row per zone in the order ICB writes them, with its
  range per letter, the cells it takes on the mesh and its state. A cell in two
  ranges takes the state of the later zone (the arrows change the order), and
  the limits are included. Names and limits are edited in place; **Add zone**
  copies the selected one; double-click a state to edit it.
* **Coverage** — with the mesh loaded, whether every cell of the block is in a
  zone. A cell in no zone stops ICB, so the line names how many there are and
  the first of them, as ICB would. A nozzle zone also writes its plenum rows —
  the whole cross-section upstream of `nozzle-threshold` — outside its range,
  and the count takes them in.

**Merge the zones…** gives the block one state again, that of the zone you
pick. The checks also catch what ICB refuses in a layout: letters out of the
order `x y z r t i j k`, a range without one pair per letter, a gap in the
numbering of the zones (ICB stops reading at the first missing number), a zone
whose range holds no cell, a zone every cell of which a later zone takes, and
zones that set different turbulence models. An interpolated zone that gives no
turbulence keys takes the model of its old solution, as ICB does (the GUI reads
the band names of an ASCII Tecplot source: `mi_t` or `nuTilde`, `k` and `omega`,
the Reynolds stresses): the cells of the other zones without turbulence keys
then stay 0, a warning under Spalart-Allmaras and an error under k-omega.

### The 3-D view

Right of the editor, the mesh is drawn with every cell in the colour of the
state ICB writes into it last: All blocks, the state of a block of its own, each
zone, in the order ICB writes them. The legend under the view names the colours
and counts the cells of each. The plenum a nozzle flow leaves at rest takes a
lighter tint of its state's colour, with an entry of its own. The cells no
state writes are drawn grey, **outlined in red** and counted as *No state: ICB
stops*: a gap between the ranges of the zones shows before ICB runs. A 3-D
block shows the cells along its six faces, a 2-D block every cell.

The state selected in the list is in full colour and the others are dimmed; in
3-D, a selected block or zone shows the other blocks see-through, so a block
inside the mesh can be seen. A **click on a cell** names it — its block, its
index, its centre and the state it takes — and opens that state; a click on a
legend entry opens its state too. While the stage is open, the header holds the
view controls: Iso, XY, XZ, YZ and Fit; **Mesh lines**, the edges of the cells
(off at first: on a fine mesh they hide the colours); **Focus**, off for every
state in full colour. A mesh of 2-D blocks opens face on (XY).

A state keeps its colour as others are added or moved. The seven colours come
round again past the seventh state; the legend and a click tell them apart.

### The initial field

**States | Field**, at the top of the view, switches from the states of the
deck to the field ICB wrote (Run stage), read from `fromATLAStoSolver/`:
`<phase>-ic.tec` (`IC-format = tec`, the default) or `<phase>-ic.vtm` with its
`vtk/` blocks (`IC-format = vtk`); a binary `.szplt` is not read. Every cell is
coloured by the quantity chosen under the view, with one field per phase when
ICB wrote several. For a gas the list starts with what is read most:

| Quantity | From |
|----------|------|
| p, u, v, w, the turbulence bands, the partial densities | the file, as the solver reads them |
| ρ, the mass fractions Y | the partial densities (one per species of `<phase>-phase.txt`) |
| T | `p / (ρ R)`, R the gas constant of the mixture, from the molar masses of `<phase>-phase.txt` |
| \|V\|, Mach | the speed of sound `√(γ R T)`, γ from the mixture's cp(T) of `<phase>-thermo.dat` |

These are ICB's own thermodynamics: the temperature ICB reached from total
conditions, the Mach number a block was given, come back as they were set.
Without the phase file there is no T; without `thermo.dat`, no Mach number
(a note under the bar says so). A solid shows T and its material, a real fluid
its bands and speed, a dispersed phase its bands.

A magnitude takes one hue, light to dark (dark to light on a dark background);
a quantity with values on both sides of zero (a velocity component) takes two
hues about a neutral grey at zero, blue below and red above, on a scale
symmetric about zero. The bar under the view gives the scale, its end values
and the range of the values; a **click on a cell** gives its values — the
quantity shown, p, T and the Mach number — and the state it takes. **Focus**
leaves the colours as they are (a dimmed colour would read as another value):
a selected block or zone shows the other blocks see-through. A block the
field has nothing for (another phase is built there) is grey.

Under the bar the view says which file it shows and when ICB wrote it, and
warns when the INI was saved after it or the case has changes not saved: the
field is then that of an earlier case, and running ICB again updates it (the
view reads the file again whenever ICB has written it). A field whose blocks
do not have the cells of the mesh on the screen is not drawn on them. From
the Run stage, **Field** on ICB's row opens this view.

---

## Files

Many keys of a case name a file: a wall temperature table, an inlet time
series, the CEA deck a composition comes from, the mechanism of a gas phase.
Every one of them is chosen with a file browser rather than typed.

* In the **BC editor**, a key that takes a file has a browse button at the end
  of its row, and picking it from the key menu opens the chooser straight away.
  **Files of this BC…** gathers them all in one window: every file key the
  boundary's type reads, set or not, with any other one reachable below.
* In **Phases**, the mechanism, phase-file and CEA-input pickers list what the
  ATLAS database and the case directory hold, and **Browse…** reaches a file
  anywhere else.
* In **Case**, `BCB-file`, `ICB-file` and `input-file` are browsed the same way.

What is written into the INI is the path the tool will look for, not the one
the browser returned:

| | |
|---|---|
| a file inside the case directory | its name, relative to that directory — the tools run there |
| a file outside it | a relative path if that is shorter, otherwise the absolute one |
| `reactions`, `phase` (GPB) | the file stem alone, which is what GPB resolves against the case directory and `database/chemistry/` |

Two cases are caught as they happen rather than at run time. A **mechanism
outside GPB's search path** cannot be found by its stem, and a **time-series
name longer than 32 characters** is refused by BCB (the BC record keeps 32 of
them, so the solver would look for a file that does not exist); both offer to
copy the file into the case directory, which fixes the name and the path at
once. A value that does not resolve is marked in the editor and listed in
**Review**.

---

## Review

The left column lists what the GUI can check without running anything, grouped
by the stage that fixes it, in the order the tools run, each group with its
count of errors, warnings and notes: required keys, allowed values,
per-material value counts, temperature ranges, duplicate phase names, faces with
no BC, the initial states ICB would stop on, files that are not where the key
says they are. With the mesh loaded it adds what only the mesh shows: the cells
no zone writes, a nozzle flow on a block that is not a nozzle, a profile table
that misses cells.

The right column is the file itself, updated as you edit. A **click** on an
entry brings its section into view and marks it; a **double click** opens the
entry in its stage.

GPB, BCB and ICB run their own, deeper checks when they build the case. After a
run (**Run** stage), the errors and warnings they printed are listed here too,
marked with the tool (`BCB · key rhoK of section [isoth]: unknown key …`), in
the group of the stage that fixes them, each on what it names:

| The message names | The entry opens |
|-------------------|-----------------|
| a section: `key T0 of section [noz]`, `composition of section [injOX]`, `[GPB-Phase1] …`, `section [ICB-Block2]` | that section: the BC, the GPB phase, the ICB block or the zone of a block, `[ATLAS-Parameters]` in Case; a click marks the key it names in the file |
| a file: `table file Twall.dat: …` | the section whose key names the file |
| nothing of the deck, while GPB builds a phase or ICB a block | that phase, that block (`- Ideal-gas phase: gas`, `- Initialization block n. = 2` precede the messages about them) |
| the phase files: `thermo file, thermo.dat not found` | Phases, where GPB builds them |

A message the tool printed again (once per block, per cell) is one entry with
its count; the lines indented under it (a hint, the values involved) are in its
tooltip. A Python traceback is one error, its last line; a tool that fails
without an error message gets one that says so. **Right-click → Show in the
log** shows an entry's line in the log of the Run stage. The entries stay until
the next run; when the case changes after the run, they are greyed and the
first line of the list says so.

---

## Run

**Run** — in the stage, or in the header from any stage (Cmd+R on macOS,
Ctrl+R elsewhere) — saves the case and runs the selected tools on it, one after
the other in the order GPB, BCB, ICB, each as `ATLAS <TOOL> --input <ini>` in
the case directory. A tool that fails stops the run: the next ones are
skipped, as in `ATLAS GPB BCB ICB`. **Stop** ends the tool that runs (the tool
itself, not only `ATLAS.sh`) and skips the others; the `filelist.txt` and the
GPB staging directory a stopped tool leaves are removed.

| Card | What it shows |
|------|---------------|
| **Tools** | GPB, BCB and ICB, each with what it builds from the deck (*2 phases: gas, drop*, *3 blocks, 5 boundary conditions*, *All blocks, Block 2*) or why it has nothing to build, a box to leave it out of the run, its state, and once it has run its time, the files it wrote and the errors and warnings it printed; **Log** and **First error** jump to them, **… messages in Review** lists them on the sections they name ([Review](#review)) |
| **Before the run** | What the run does first and what would stop it, from the case alone (below); **Tools…** opens Settings → Tools |
| **Log** | The output of the tools as they run: ▶ a tool starts, ✔ it is done, ✖ it failed, ■ it was stopped, › what the run does besides; errors and warnings in their colours. **Save log…** writes it to a file |
| **fromATLAStoSolver/** | The files there, those of the last run first, in bold, with the tool that wrote them; a double click draws a table, the boundary file or the initial field in its stage, and opens any other file |

The status bar shows the tool that runs, or how the last run ended, and the
window's title the INI and whether it has unsaved changes.

### Before the run

BCB and ICB read what they need from the case directory under fixed names;
two of them a GUI case does not always have there, and the run provides them,
saying so in the log:

* **The mesh.** BCB and ICB read `mesh.tec`, `mesh.p3d` or `mesh.szplt`, the
  first that exists. A mesh loaded under another name (`chamber.p3d`) is
  linked under the default name of its format (`mesh.p3d → chamber.p3d`)
  before BCB or ICB runs. When another default mesh comes first (a
  `mesh.tec` next to the `mesh.p3d` on the screen), the run warns that the
  tools read that one.
* **The phase files.** BCB and ICB read the `*phase.txt` of the case
  directory, with their `thermo.dat` or `properties.dat`; GPB writes them into
  `fromATLAStoSolver/`. With **Give BCB and ICB the phase tables GPB writes**
  (on by default, remembered), the tables GPB has just written are copied into
  the case directory after GPB, before BCB and ICB; its other products
  (`transport.dat`, `composition.txt`, ...) are for the solver and stay where
  they are. Without GPB in the run, the list names the phase files BCB and ICB
  will read, and warns when one is older than GPB's last, when one belongs to
  no phase of the deck, and when there is none (the tools then assume one
  ideal gas).

The list also says when the INI is saved first, when a tool is not built or
GPB has no Python with Cantera (the run cannot start), when a `filelist.txt` in
the case directory decides the phase files instead (`ATLAS.sh` keeps a file it
did not make), and when the checks of **Review** find errors in the stage of a
tool that runs (the run asks before it starts).
