# ATLAS GUI — case setup

The **ATLAS GUI** sets up a case the way the tools read it: one `input.ini`
holding the GPB phases, the BCB boundary conditions and the shared
`[ATLAS-Parameters]`. It is the same file `ATLAS GPB BCB ICB` consumes, so the
GUI is an editor for the case, not a separate project format.

```bash
ATLAS GUI                      # the whole case
ATLAS GUI -i input.ini         # open an existing case
ATLAS BCB-GUI                  # the same window, opened on Boundaries
```

or directly:

```bash
python utils/ATLAS/GUI/ATLAS_GUI.py [mesh] [--ini input.ini] [--stage gpb]
```

The window opens fitted to the screen. **Display** (top right) sets the
**text size** — 100 % is fitted to the screen, and Ctrl/Cmd +, Ctrl/Cmd − and
Ctrl/Cmd 0 change it from anywhere — and the **colour theme**; both are
remembered. On a narrow window the header buttons keep only their icons, with
the label as tooltip.

**Display → Settings…** (Cmd+, on macOS) opens the Settings window. Every
change shows on the application at once; **Apply** or **OK** keep it,
**Cancel** puts back what was there, **Restore Defaults** resets the page.

* **Appearance** — pick the theme from previews of each one, and the text size.
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
| **Case** | Where the case lives, the mesh, `[ATLAS-Parameters]`, and an overview of what is set up |
| **Phases** | GPB: one card per `[GPB-PhaseN]`, with an editor that follows the phase type |
| **Boundaries** | BCB: the mesh in 3-D, its blocks and faces, and the BCs assigned to them |
| **Initial** | ICB: the initial state of every block, `[ICB-Block*]` and `[ICB-BlockN]` |
| **Review** | The INI as it will be written, plus every check the GUI can make on it |

Sections belonging to tools the GUI does not edit yet (`[STB-*]`, `[MDB-*]`,
`[KAnT-*]`) are carried through a save untouched, so a shared case file never
loses another tool's setup. The zone sections of a multizone ICB block
(`zone1 = plenum` names `[plenum]`) belong to ICB: they are not listed as
boundary conditions, and a new BC cannot take their name.

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

---

## Boundaries (BCB)

See [BCB GUI](./bcb/gui.md) for the mesh view, face picking and BC assignment.

**New** opens a small dialog: the name of the section, its type (with a line
saying what that type is for), and the files that type reads — pick them there
and the section is created with them. Everything it offers can also be set
afterwards, from the BC editor.

Selecting a **block** (rather than a face) shows which GPB phases live in it:
the chips are the phases defined in the Phases stage, and they write the
block's `phase` key. No chip selected means every phase, which is what BCB
assumes when the key is absent.

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
| **How the field is built** | *Uniform*, *Nozzle* (`type = nozzle`, ideal gas only) or *Interpolate* (`old-solution`) |
| **Gas state** | two of `p`, `T`, `p0`, `T0`, `rho`, chosen as a pair; ICB derives the rest |
| **Velocity** | the Mach number (`vel` for a real fluid) with the flow angles, or `u`, `v`, `w` |
| **Composition** | the mass fractions `y<species>`, with their sum, or a CEA equilibrium (`eq-CEA-file`) |
| **Turbulence** | the model and its quantities, specific (`k`, `omega`, …) or density-weighted (`rhoK`, …) |
| **Solid**, **Dispersed phase**, **Real fluid** | `T` and `material`; `krho`, `kT`, `dp` or `rp`, `Pp`; `p` with `T` or `h` |
| **Nozzle**, **Interpolation** | `p0`, `T0`, `nozzle-direction`, `nozzle-threshold`; the source, the law, `old-block-id`, `old-species` |

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
not read (with the name to use instead, for the keys of earlier decks), a
turbulence model without its quantities, a value that is not physical. They are
listed in **Review** too.

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
zones that set different turbulence models.

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

The left column lists what the GUI can check without running anything:
required keys, allowed values, per-material value counts, temperature ranges,
duplicate phase names, faces with no BC, files that are not where the key says
they are. Double-click an entry to jump to it.
The right column is the file itself, updated as you edit.

GPB and BCB run their own, deeper checks when they build the case; the GUI's
checks are the ones that can be made from the file alone.
