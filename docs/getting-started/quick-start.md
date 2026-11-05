# Quick Start

This quick start builds the input of a 3-D De Laval nozzle case:

- an air phase, built by GPB;
- an inlet, an isothermal wall, symmetry planes and an outflow, built by BCB;
- the nozzle initial field, built by ICB.

The [ATLAS GUI](../user-guide/gui.md) builds and runs the same case in a window from the mesh alone
(`ATLAS GUI`): it writes the setup of every tool. This page runs it from the shell, with the setup written out.

## Prerequisites

- ATLAS built with `./install.sh build`, with its conda environment `ct-env` (see [Installation](installation.md));
- the `ATLAS` command in the shell: open a new terminal after the build, or run
  `source <ATLAS>/scripts/setvars.sh`, `<ATLAS>` being the directory of the clone (it also sets `ATLASDIR`).

## Case Directory

Create a case directory and copy into it the mesh and the wall-temperature table of two test cases:

```bash
mkdir nozzle3d-air
cd nozzle3d-air

# the mesh BCB and ICB read: a 3-D nozzle of one block
cp $ATLASDIR/test/ICB/IG-nozzle3D/mesh.tec .

# the wall temperature against x and the angle about the x axis, read by the isothermal wall
cp $ATLASDIR/test/BCB/IG-xtheta-variable-T/Twall.dat .
```

## The Setup Of The Tools

The setup of every tool is one file, `input.ini`, in which each tool reads only its own sections: the GUI writes it
when the case is set up in its window. For the shell, create it in the case directory:

```ini
[GPB-Phase1]
mixture-name = air
mixture      = {N2: 75.4} {O2: 23.3} {Ar: 1.3}
thermo       = NASA9
transport    = CEA

[ATLAS-Parameters]
IC-format = tec

[BCB-Block1]
face1 = inflow
face2 = extrapolation
face3 = symmetry
face4 = isoth
face5 = symmetry
face6 = symmetry

[inflow]
type = inlet
p0   = 3.0e+5
T0   = 500.0

[isoth]
type      = wall
direction = xt
T-file    = Twall.dat

[ICB-Block1]
type             = nozzle
p0               = 3.0e+5
T0               = 500.0
nozzle-threshold = 0.0
```

| Section | Read by | What it sets |
|---|---|---|
| `[GPB-Phase1]` | GPB | an ideal gas of one species, `air`, mixed from N₂, O₂ and Ar (mass percentages) with the NASA9 thermodynamics and the CEA transport fits |
| `[ATLAS-Parameters]` | every tool | the parameters the tools share: here the Tecplot format of the initial field |
| `[BCB-Block1]` | BCB | the boundary condition of each of the six faces of block 1 ([face numbering](../user-guide/bcb/bc-setup.md#block-face-mapping)) |
| `[inflow]`, `[isoth]` | BCB | the two boundary conditions that take parameters: a total-conditions inlet (BC 401) and a wall whose temperature follows `Twall.dat` |
| `[ICB-Block1]` | ICB | the nozzle law from the chamber state `p0` [Pa], `T0` [K]; the rows upstream of x = 0 stay at rest |

Every value is SI. What the tools check when they read the file (unknown keys, sections written twice,
values out of range) is described in [INI Files](../user-guide/ini.md).

## Build The Case

From the case directory:

```bash
ATLAS GPB BCB ICB    # phase tables, then boundary conditions, then the initial field
```

The tools run one after the other and the chain stops at the first that fails. GPB prints one warning,
`no CEApolynomials record for species 'Ar': simplified law applied`: argon has no CEA transport fit, and its
viscosity and conductivity follow a simplified law.

!!! note "One directory for every tool: `fromATLAStoSolver/`"
    Every tool writes into `fromATLAStoSolver/` of the case. GPB writes the phase files there (`phase.txt` and
    `thermo.dat`: the phase has no `name`, so its files have no prefix), and BCB and ICB read them from there, so
    nothing is copied. The tools can also run one at a time (`ATLAS GPB`, then `ATLAS BCB`, ...). A phase file of the
    same name in the case directory is read in place of GPB's (a phase written by hand); the launcher warns when the
    two differ.

## What Each Step Writes

All the products go into `fromATLAStoSolver/`. They are the input of a solver run, which reads them in its own
`INPUT/` directory (figaro moves them there).

| Tool | Files | Content |
|---|---|---|
| GPB | `phase.txt`, `thermo.dat`, `transport.dat`, `composition.txt` | the species `air` and its molar mass; cp, h, s and transport from 1 K to 5000 K, 1 K step ([GPB output](../user-guide/gpb/output.md)) |
| BCB | `bc.txt` | one record per boundary cell: block, cell, face, BC id and its values ([BCB output](../user-guide/bcb/output.md)) |
| ICB | `ic.tec` | the initial field: density, velocity and pressure in every cell ([ICB output](../user-guide/icb/output.md)) |

```bash
ls fromATLAStoSolver
# bc.txt  composition.txt  ic.tec  phase.txt  thermo.dat  transport.dat
```

## Next Steps

- [INI Files](../user-guide/ini.md): the shared parameters and what the tools check
- [User Guide](../user-guide/index.md): every tool, its keys and its files
- [ATLAS GUI](../user-guide/gui.md): the same case in a window, with the mesh in 3-D
- [Tutorials](../tutorials/index.md): step-by-step cases, tool by tool
