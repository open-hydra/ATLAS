---
title: ATLAS
hide:
  - navigation
  - toc
---

<div class="atlas-hero" markdown>

<p class="atlas-hero__eyebrow">Pre-processing for the Hydra solvers</p>

<h1 class="atlas-hero__title">ATLAS</h1>

<p class="atlas-hero__lead">From a mesh and one INI file to the input of the solvers: phase tables, boundary
conditions, initial fields, source terms, and the decomposition of the mesh for parallel runs.</p>

[Get started](getting-started/index.md){ .md-button .md-button--primary }
[Quick Start](getting-started/quick-start.md){ .md-button .atlas-hero__ghost }
[ATLAS GUI](user-guide/gui.md){ .md-button .atlas-hero__ghost }

<p class="atlas-hero__name"><strong>A</strong>uxiliary <strong>T</strong>oolbox and <strong>L</strong>ibraries for
hydr<strong>A</strong> <strong>S</strong>olvers · Fortran and Python · GPL-3.0</p>

</div>

## One case, one input file, one output directory

Every tool reads its sections of the same `input.ini` in the case directory and writes its products into
`fromATLAStoSolver/`, the directory the solvers read.

<div class="atlas-flow" markdown>

<div class="atlas-flow__step atlas-flow__step--io" markdown>
<span class="atlas-flow__tag">Case</span>

**`input.ini`**, the mesh (`mesh.tec`, `.p3d`, `.szplt`) and the [databases](databases/index.md)
</div>

<div class="atlas-flow__step" markdown>
<span class="atlas-flow__tag">GPB</span>

[**Phases**](user-guide/gpb/index.md): `phase.txt`, `thermo.dat`, `transport.dat`, chemistry tables
</div>

<div class="atlas-flow__step" markdown>
<span class="atlas-flow__tag">BCB</span>

[**Boundaries**](user-guide/bcb/index.md): `bc.txt`, one per multigrid level
</div>

<div class="atlas-flow__step" markdown>
<span class="atlas-flow__tag">ICB</span>

[**Initial field**](user-guide/icb/index.md): `ic.tec` or `ic.vtm`
</div>

<div class="atlas-flow__step atlas-flow__step--opt" markdown>
<span class="atlas-flow__tag">STB · MDB</span>

[**Sources**](user-guide/stb/index.md) and the [**decomposition**](user-guide/mdb/index.md) for MPI
</div>

<div class="atlas-flow__step atlas-flow__step--io" markdown>
<span class="atlas-flow__tag">Solvers</span>

**`fromATLAStoSolver/`**, read by MOSE, ARES, Q2D, FUSS, IGLOO, ICE
</div>

</div>

=== "Shell"

    ```bash
    ATLAS GPB                                                    # phase tables
    cp fromATLAStoSolver/phase.txt fromATLAStoSolver/thermo.dat .  # BCB and ICB read them here
    ATLAS BCB ICB                                                # boundary conditions, initial field
    ```

=== "GUI"

    ```bash
    ATLAS GUI -i input.ini       # set up the case, then Run (Cmd/Ctrl+R): GPB, BCB, ICB
    ```

=== "Install"

    ```bash
    git clone https://github.com/open-hydra/ATLAS.git
    cd ATLAS
    ./install.sh build           # Fortran tools, the ATLAS command, the conda environment ct-env
    ```

The [Quick Start](getting-started/quick-start.md) builds a 3-D nozzle case with these commands.

## Where to start

<div class="grid cards" markdown>

-   :material-monitor-dashboard:{ .lg .middle } __Set up a case in a window__

    ---

    The phases, the boundary conditions on the 3-D mesh, the initial state, the checks, and the runs of GPB, BCB
    and ICB, with what they wrote drawn back.

    [:octicons-arrow-right-24: ATLAS GUI](user-guide/gui.md)

-   :material-console:{ .lg .middle } __Run the tools from the shell__

    ---

    Install ATLAS, then build the phase tables, the boundary conditions and the initial field of a nozzle.

    [:octicons-arrow-right-24: Getting Started](getting-started/index.md)

-   :material-file-cog-outline:{ .lg .middle } __Look up a key__

    ---

    Every key of every tool, with its default and its allowed values, and what the tools check in an INI file.

    [:octicons-arrow-right-24: INI Files](user-guide/ini.md)

-   :material-database:{ .lg .middle } __Choose a mechanism or a database__

    ---

    42 mechanism files (Cantera yaml), the NASA and Burcat thermodynamics, CEA and Lennard-Jones transport, real-fluid
    equations of state.

    [:octicons-arrow-right-24: Databases](databases/index.md)

-   :material-school-outline:{ .lg .middle } __Learn from the reference cases__

    ---

    The cases of the test suite, tool by tool, with what each one proves.

    [:octicons-arrow-right-24: Tutorials](tutorials/index.md)

-   :material-source-branch:{ .lg .middle } __Work on ATLAS__

    ---

    The build, the code layout, the regression tests and how to contribute.

    [:octicons-arrow-right-24: Developer Guide](development/index.md)

</div>

## The tools

| Tool | Name | Builds | Language |
|---|---|---|---|
| [**GPB**](user-guide/gpb/index.md) | General Phase Builder | thermodynamic, transport and chemistry tables of ideal-gas, real-fluid, condensed and solid phases | Python |
| [**BCB**](user-guide/bcb/index.md) | Boundary Condition Builder | the BC record of every boundary cell: inlets, walls, connections, chimera, gas-surface interaction | Fortran |
| [**ICB**](user-guide/icb/index.md) | Initial Condition Builder | the initial field: uniform, profiles, zones, nozzle law, interpolation of a previous solution | Fortran |
| [**STB**](user-guide/stb/index.md) | Source Terms Builder | volumetric heat sources, remapped conservatively from another mesh; the area tables of Q2D | Fortran |
| [**MDB**](user-guide/mdb/index.md) | Mesh Decomposition Builder | more, smaller blocks for MPI balance, with the BC files of every multigrid level rewritten | Fortran |
| [**KAnT**](user-guide/kant/index.md) | Kinetic Analyzer and Tester | 0-D and 1-D Cantera runs to check a mechanism before a CFD run | Python |

Each tool stops on an input it cannot honour, naming the section, the key and, for a misspelt key, the closest
known one ([INI Files](user-guide/ini.md#what-the-tools-check)).

## The GUI

<div class="atlas-shot" markdown>

![The Initial stage of the ATLAS GUI on the nozzle of the Quick Start: the nozzle law with its A/A* plot, and the pressure field ICB wrote](user-guide/images/gui-initial-field.png){ loading=lazy }

</div>

`ATLAS GUI` holds the case in six stages, in the order the tools run: **Case**, **Phases** (GPB, with the tables
it wrote), **Boundaries** (BCB, the BC of every face, or of every cell as written), **Initial** (ICB, the state of
every cell, or the field written), **Review** (the INI and every check) and **Run**. What it saves is the
`input.ini` the tools read: a case set up in the window runs from the shell, and the reverse.

[:octicons-arrow-right-24: The ATLAS GUI](user-guide/gui.md)

## In the Hydra suite

Each phase GPB builds is the input of one Hydra solver; [Hydra](https://github.com/open-hydra) couples them.

| Phase (`[GPB-Phase*] type`) | Solver | |
|---|---|---|
| `ideal-gas`, `heavy-gas` | [MOSE](https://github.com/open-hydra/MOSE) | compressible Euler and Navier–Stokes on multi-block structured grids |
| `ideal-gas` on a 2-D mesh | [Q2D](https://github.com/open-hydra/Q2D) | the 2-D (x, y) cases, planar or axisymmetric |
| `real-fluid` | [ARES](https://github.com/open-hydra/ARES) | real-fluid flow |
| `solid` | [FUSS](https://github.com/open-hydra/FUSS) | heat conduction in solids |
| dispersed, `modeling = lagrangian` | [IGLOO](https://github.com/open-hydra/IGLOO) | Lagrangian particles |
| dispersed, `modeling = eulerian` | [ICE](https://github.com/open-hydra/ICE) | Eulerian condensed phase |

[GROOT](https://github.com/open-hydra/GROOT), the radiative-transfer solver of the suite, takes no ATLAS phase.
ATLAS is not required by the solvers: their input files can be written by hand or by another pre-processor.
