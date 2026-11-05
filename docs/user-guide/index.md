# ATLAS Tools — User Guide

Each tool reads its sections of the case's INI file and writes its products into `fromATLAStoSolver/`, the
directory the solvers read. Each guide opens with **what the tool can do**, then covers how to configure it;
[INI Files](ini.md) describes what all of them share.

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

With the `ATLAS` command in the shell, from the case directory:

```bash
# 1 — phase property tables (first: BCB and ICB read the phase files)
ATLAS GPB

# 2 — hand the phase files to BCB and ICB, which read them in the case directory
cp fromATLAStoSolver/*phase.txt fromATLAStoSolver/*thermo.dat .   # *properties.dat for condensed and solid phases

# 3 — boundary conditions, initial field
ATLAS BCB ICB

# 4 — source terms (optional)
ATLAS STB

# 5 — decomposition for a parallel MOSE or ICE run (optional, in the solver directory)
ATLAS MDB
```

!!! warning "GPB comes first"
    The order of BCB, ICB and STB is free, but GPB must run first: BCB and ICB read the phase files GPB writes,
    from the case directory (see the [Quick Start](../getting-started/quick-start.md#build-the-case)). MDB splits
    what BCB and ICB wrote, so it runs last.

!!! note "Passive scalars"
    ATLAS does not write passive-scalar (`Pass`) bands: MOSE and Q2D read them by position from the initial
    solution, so a run with passive scalars (`npass > 0`) cannot start from the ATLAS products as they are.

For worked examples, see the [Tutorials](../tutorials/index.md).
