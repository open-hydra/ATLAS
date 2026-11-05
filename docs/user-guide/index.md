# ATLAS Tools — User Guide

Each tool builds part of the input of a Hydra run from the mesh and the [databases](../databases/index.md), and
writes it into `fromATLAStoSolver/`, whose files a solver run reads in its `INPUT/`. The [ATLAS GUI](gui.md) sets the
case up and runs the tools; each guide opens with **what the tool can do**, then describes its setup, the sections the
GUI writes for it ([INI Files](ini.md) describes what all of them share).

<div class="grid cards" markdown>

-   :material-atom-variant: **GPB — General Phase Builder**

    ---

    Thermodynamic, transport and chemistry tables for ideal-gas, real-fluid, condensed and solid phases, from
    Cantera, CEA, the bundled databases or constants.

    [:octicons-arrow-right-24: GPB guide](gpb/index.md)

-   :material-dock-left: **BCB — Boundary Condition Builder**

    ---

    The boundary condition of every boundary cell: inlets, outlets, walls, symmetry, periodic pairs, block
    connections, chimera overlaps, gas-surface interaction.

    [:octicons-arrow-right-24: BCB guide](bcb/index.md)

-   :material-cube-outline: **ICB — Initial Condition Builder**

    ---

    The initial field: uniform states, profiles, zones, the nozzle law, or interpolation of a previous
    solution.

    [:octicons-arrow-right-24: ICB guide](icb/index.md)

-   :material-fire: **STB — Source Terms Builder**

    ---

    Volumetric heat sources (uniform, 1-D profile, or a 3-D field remapped conservatively) and the area tables
    of Q2D.

    [:octicons-arrow-right-24: STB guide](stb/index.md)

-   :material-scissors-cutting: **MDB — Mesh Decomposition Builder**

    ---

    Splits the blocks of a mesh, its solution and its BC files, so that MOSE and ICE balance their MPI ranks.

    [:octicons-arrow-right-24: MDB guide](mdb/index.md)

-   :material-chart-line: **KAnT — Kinetic Analyzer and Tester**

    ---

    0-D and 1-D Cantera runs (equilibrium, ignition delay, time evolution, counterflow flame) to check a
    mechanism before a CFD run.

    [:octicons-arrow-right-24: KAnT guide](kant/index.md)

-   :material-monitor-dashboard: **ATLAS GUI**

    ---

    The case in a window: the phases, the boundary conditions on the 3-D mesh, the initial state, the checks,
    and the runs of GPB, BCB and ICB.

    [:octicons-arrow-right-24: GUI guide](gui.md)

-   :material-file-cog-outline: **INI Files**

    ---

    One file for the whole case: the shared `[ATLAS-Parameters]` and what every tool checks when it reads it.

    [:octicons-arrow-right-24: INI files](ini.md)

</div>

## Common Workflow

In the [GUI](gui.md), the **Run** stage runs the tools of the case in this order. From the shell, with the `ATLAS`
command, in the case directory:

```bash
# 1 — phase property tables (first: BCB and ICB read the phase files)
ATLAS GPB

# 2 — boundary conditions, initial field
ATLAS BCB ICB

# 3 — source terms (optional)
ATLAS STB

# 4 — decomposition for a parallel MOSE or ICE run (optional)
ATLAS MDB
```

The same in one command: `ATLAS GPB BCB ICB STB MDB`, which stops at the first tool that fails.

!!! warning "GPB comes first"
    The order of BCB, ICB and STB is free, but GPB must run first: BCB and ICB read the phase files GPB writes
    into `fromATLAStoSolver/`. MDB splits what BCB and ICB wrote there, so it runs last.

!!! note "Phase files written by hand"
    BCB, ICB and MDB read each `*phase.txt` of the case directory, with its `thermo.dat` or `properties.dat`,
    and those GPB wrote into `fromATLAStoSolver/` that the case directory does not hold. A phase file of the case
    directory is therefore read in place of GPB's file of the same name: the launcher warns when the two differ.
    Remove the copy to read GPB's. GPB never removes a file of `fromATLAStoSolver/`, so the phase of an earlier
    deck stays there: when the INI has `[GPB-Phase*]` sections, BCB and ICB read there only the phase files of
    those sections, and the launcher names the others it leaves out.

!!! note "Passive scalars"
    ATLAS does not write passive-scalar (`Pass`) bands: MOSE and Q2D read them by position from the initial
    solution, so a run with passive scalars (`npass > 0`) cannot start from the ATLAS products as they are.

For worked examples, see the [Tutorials](../tutorials/index.md).
