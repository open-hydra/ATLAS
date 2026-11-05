# Tutorials

Step-by-step cases, from one tool on one feature to a whole case for an MPI run. Each tutorial starts from a case of
the test suite (`test/` of the ATLAS directory): you copy its files into a folder of your own, run the tool, and read
what it wrote. The tests themselves, and what each one checks, are listed in [Testing](../development/testing.md).

## Before You Start

- ATLAS installed, and the `ATLAS` command in your shell ([Installation](../getting-started/installation.md));
  `$ATLASDIR` is the ATLAS directory.
- A folder for the tutorials, `~/atlas-tutorials` in the pages: a tool writes `fromATLAStoSolver/` in the directory
  it runs in, so run them on copies, never in `test/`.
- The [Quick Start](../getting-started/quick-start.md) first, if you have not run it: it builds a whole 3-D case in
  one command.

!!! note "Phase files in the tutorials"
    GPB writes the phase files into `fromATLAStoSolver/`, and BCB and ICB read them from there. Most BCB and ICB
    tutorials copy instead the phase file of their test case into the case directory: a phase file written by hand,
    which the tools read first. [A Case for MPI](mdb/index.md) builds its phase with GPB.

## The Path

| Chapter | Tutorials | You learn |
|---|---|---|
| [Phases (GPB)](gpb/index.md) | 8 | the thermodynamic, transport and chemistry tables of gases, particles, solids and real fluids |
| [Boundary Conditions (BCB)](bcb/index.md) | 8 | inlets, walls and outlets, patches, reservoir inlets, tables, connections, chimera, particles, gas-surface interaction |
| [Initial Fields (ICB)](icb/index.md) | 6 | uniform states, zones, the nozzle law, profiles, restarts, particles |
| [Source Terms (STB)](stb/index.md) | 2 | heat sources, the area tables of Q2D |
| [A Case for MPI (MDB)](mdb/index.md) | 1 | a whole case in one command, then cut for four ranks |
| [Checking a Mechanism (KAnT)](kant/index.md) | 1 | flame temperatures and ignition delays of several mechanisms |

Every tutorial has the same parts: **What You'll Learn**, **The Case** (its files and its INI, key by key),
**Run It**, **What It Writes** (the files, and how to read them), and **Try Next**. The run times are those of a
laptop.

The [ATLAS GUI](../user-guide/gui.md) opens any of these folders (**Case folder…**) and draws what the tools wrote.

!!! tip "The tutorials are tests"
    Every page runs a case of the suite, and `ctest -L tutorial` runs them all (in the build directory): the cases a
    page copies as they are, and the INI files the pages write, which are in `test/tutorials/<page>/` and shown on
    the pages from there. A page and its test cannot drift apart.
