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
| **Review** | The INI as it will be written, plus every check the GUI can make on it |

Sections belonging to tools the GUI does not edit yet (`[ICB-*]`, `[STB-*]`,
`[MDB-*]`, `[KAnT-*]`) are carried through a save untouched, so a shared case
file never loses another tool's setup. This includes the zone sections of a
multizone ICB block (`zone1 = plenum` names `[plenum]`): they are not listed as
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
