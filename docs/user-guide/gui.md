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
file never loses another tool's setup.

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
    directory, and report how many species the chosen file holds.

    **Constant properties…** turns the species list into a
    calorically-perfect gas (the `cp`, `cv`, `gamma`, `R`, `mw`, `mil`, `kl`,
    `Pr` arrays), one column per species.

=== "Condensed / solid"

    The materials are a table: one row per material, one column per per-material
    key (`groups`, `rho`, `cp`, `k`, `h0`, `psat-vapour`, `psat-liquid`). A
    column whose values are all equal is written once, which is what GPB
    broadcasts. **From database…** picks materials out of the NASA9 or Burcat
    file the phase uses.

    **Per-material models…** opens the solver models (`evaporation`,
    `interface`, `combustion`, `solidification`, the Beckstead and
    solidification constants, …) as one row per key and one column per
    material.

=== "Real fluid"

    The EOS backend, the fluid name (from CoolProp when it is importable) and
    the (p, T) bounds of the table with its grid sizes.

---

## Boundaries (BCB)

See [BCB GUI](./bcb/gui.md) for the mesh view, face picking and BC assignment.

Selecting a **block** (rather than a face) shows which GPB phases live in it:
the chips are the phases defined in the Phases stage, and they write the
block's `phase` key. No chip selected means every phase, which is what BCB
assumes when the key is absent.

---

## Review

The left column lists what the GUI can check without running anything:
required keys, allowed values, per-material value counts, temperature ranges,
duplicate phase names, faces with no BC. Double-click an entry to jump to it.
The right column is the file itself, updated as you edit.

GPB and BCB run their own, deeper checks when they build the case; the GUI's
checks are the ones that can be made from the file alone.
