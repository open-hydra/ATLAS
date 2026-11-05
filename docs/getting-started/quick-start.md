# Quick Start

This quick start builds the input of a 3-D De Laval nozzle case:

- an air phase, built by GPB;
- an inlet, an isothermal wall, symmetry planes and an outflow, built by BCB;
- the nozzle initial field, built by ICB.

The [ATLAS GUI](../user-guide/gui.md) builds and runs the same case in a window (`ATLAS GUI`).

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

## One Combined input.ini

Each tool reads only its own sections of an INI file, so one `input.ini` can hold the case of all of them.
Create `input.ini` in the case directory:

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
# 1. phase tables, written into fromATLAStoSolver/
ATLAS GPB

# 2. hand the phase files to BCB and ICB, which read them in the case directory
cp fromATLAStoSolver/phase.txt fromATLAStoSolver/thermo.dat .

# 3. boundary conditions and initial field, written into fromATLAStoSolver/
ATLAS BCB ICB
```

GPB prints one warning, `no CEApolynomials record for species 'Ar': simplified law applied`: argon has no CEA
transport fit, and its viscosity and conductivity follow a simplified law.

!!! warning "BCB and ICB read the phase files of the case directory"
    GPB writes `<name>phase.txt` with `<name>thermo.dat` (`<name>properties.dat` for a condensed or solid
    phase) into `fromATLAStoSolver/`; BCB and ICB read the `*phase.txt` files, and their tables, in the
    directory they run in. Copy them after every GPB run that changes a phase: `ATLAS GPB BCB ICB` in one command
    works only when the case directory already holds them. The **Run** stage of the
    [GUI](../user-guide/gui.md#before-the-run) makes this copy itself.

    The phase here has no `name`, so its files have no prefix (`phase.txt`). Without the copy, BCB and ICB find no
    phase file, look for the `phase.txt` of one ideal gas and stop with `[ERROR] phase file phase.txt not found`.

## What Each Step Writes

All the products go into `fromATLAStoSolver/`, the directory the solvers read their input from:

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
- [Tutorials](../tutorials/index.md): the reference cases of `test/`
