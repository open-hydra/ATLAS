# Inlets, Outlets and Walls

**Tool:** BCB · **Case:** `test/BCB/IG-2D` · **Run time:** under a second

The boundary conditions of a 2-D injector of four blocks: an oxygen inlet and a methane inlet, an outlet, adiabatic
walls and a symmetry plane. The faces where two blocks meet need no section: BCB finds them and writes them as
connections.

## What You'll Learn

- How a `[BCB-BlockN]` section gives a name to each face of a block
- How the BC sections (`[injOX]`, `[adia]`, ...) give a type and its values to a name
- How to read the BC file BCB writes, record by record

## The Case

| File | What it is |
|---|---|
| `mesh.p3d` | The mesh: four blocks of 2-D cells, in PLOT3D |
| `phase.txt` | The phase: an ideal gas of two species, `O2` and `CH4` (written by hand for the test; BCB reads the names and their order, not the molar masses) |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = injOX
face2 = connection
face3 = symmetry
face4 = adia

[BCB-Block2]
face1 = injCH4
face2 = connection
face3 = symmetry
face4 = adia

[BCB-Block3]
face1 = adia
face2 = connection
face3 = symmetry
face4 = adia

[BCB-Block4]
face1 = connection
face2 = outflow
face3 = symmetry
face4 = adia

[adia]
type = wall
q = 0.0

[injCH4]
type = inlet
g = 10
T = 500
yCH4 = 1.0

[injOX]
type = inlet
g = 10
T = 200
yO2 = 1.0

[outflow]
type = outlet
p = 1.0d+5
```

### Key Points

| Key | Meaning |
|-----|---------|
| `face1` … `face4` | The faces of a 2-D block: 1 and 2 at the ends of `i`, 3 and 4 at the ends of `j` ([BC Setup](../../user-guide/bcb/bc-setup.md)) |
| `connection`, `symmetry` | Keywords: a BC that takes no value needs no section of its own |
| `type = wall`, `q = 0.0` | A wall of zero heat flux: adiabatic |
| `type = inlet`, `g`, `T` | An inlet given by its mass flux (kg m⁻² s⁻¹) and its static temperature (K): the variant `404` of the [inlet table](../../user-guide/bcb/bc-types.md#inlet) |
| `yO2 = 1.0` | The mass fractions of the gas that enters; the species not given are 0 |
| `type = outlet`, `p` | An outlet at the static pressure `p` (Pa) |

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-walls && cd ~/atlas-tutorials/bcb-walls
cp $ATLASDIR/test/BCB/IG-2D/{input.ini,mesh.p3d,phase.txt} .
ATLAS BCB
```

BCB prints the BC of every face, block by block (`Face n. = 1  -> injOX = single patch`), and four times
`[WARNING] thermo file, thermo.dat not found`: the case has no species table, and none of its conditions needs one.

## What It Writes

`fromATLAStoSolver/bc.txt`, one record per boundary cell: 1180 records. A record is a line of integers, `block i j face id`, then,
for the types that carry values, a line of values. The first one is a cell of the oxygen inlet:

```text
       1       1       1       1     404
  2.0000000000000000E+02,  1.0000000000000000E+01,         normal,         normal,  1.0000000000000000E+00,  1.0000000000000000E+00,  9.9999999999999995E-21,
```

Block 1, cell (1, 1), face 1, type `404`: `T` = 200 K, `g` = 10, the flow `normal` to the face, the relaxation factor 1,
then the mass fractions in the order of `phase.txt`: 1 for O2, and 1e-20 for CH4 (BCB writes 1e-20, not 0, for an
absent species).

What every face became:

| Block | Face 1 | Face 2 | Face 3 | Face 4 |
|---|---|---|---|---|
| 1 | `404` inlet (20 cells) | `101` connection | `300` symmetry | `301` wall |
| 2 | `404` inlet (30 cells) | `101` connection | `300` symmetry | `301` wall |
| 3 | `101` on 50 cells, `301` wall on 80 | `101` connection | `300` symmetry | `301` wall |
| 4 | `101` connection | `406` outlet | `300` symmetry | `301` wall |

Face 1 of block 3 is declared `adia`, but 50 of its cells face blocks 1 and 2: BCB connects them and keeps the wall on
the other 80, and says so: `[LOG] BC-force-connect: block 3 face 1: 50 cells connected to block(s) 1 2, 80 cells keep
the declared BC [adia]`. [Block Connectivity](../../user-guide/bcb/connectivity.md) describes the rule;
[BCB Output](../../user-guide/bcb/output.md) gives the values of every type.

## Try Next

- Give the oxygen a total temperature instead: `T0 = 220` in place of `T`, and the record becomes a `403`.
- Turn the wall `adia` isothermal: `T = 300` in place of `q = 0.0`, and its records become `302`.
- Write `face4 = adiabatic` in block 1, with no section `[adiabatic]`: BCB stops with
  `[ERROR] Missing type entry for bc: adiabatic`.

---

Next: [Several Conditions on One Face](multipatch.md)
