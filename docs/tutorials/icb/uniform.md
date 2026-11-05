# A Uniform State, Block by Block

**Tool:** ICB · **Case:** the mesh and phase of `test/ICB/IG-2D` · **Run time:** under a second

The simplest initial field: one state for every block, and a different one for the block where the gas already moves.

## What You'll Learn

- How `[ICB-Block*]` gives a state to every block, and `[ICB-BlockN]` to one block
- Which keys make a state: pressure and temperature, the velocity, the composition
- What ICB writes, and how to read it back

## The Case

| File | What it is |
|---|---|
| `mesh.p3d` | The 2-D mesh of four blocks of [Inlets, Outlets and Walls](../bcb/walls-and-inlets.md) |
| `phase.txt`, `thermo.dat` | One species, N2, and its table (100 K to 5000 K) |
| `input.ini` | The initial state, in `test/tutorials/icb-uniform/` |

```ini
--8<-- "test/tutorials/icb-uniform/input.ini"
```

| Key | Meaning |
|-----|---------|
| `[ICB-Block*]` | Every block that has no section of its own |
| `[ICB-Block4]` | Block 4 only: a section replaces the `*` one, it does not add to it |
| `p`, `T` | Static pressure (Pa) and temperature (K) |
| `u`, `v`, `w` | Velocity (m/s), 0 when not given |

A block section without `type` is `homogeneous`: one state in every cell. A gas of several species takes its mass
fractions with `y<species>` keys; a gas of one species needs none.

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-uniform && cd ~/atlas-tutorials/icb-uniform
cp $ATLASDIR/test/ICB/IG-2D/{mesh.p3d,phase.txt,thermo.dat} .
cp $ATLASDIR/test/tutorials/icb-uniform/input.ini .
ATLAS ICB
```

## What It Writes

`fromATLAStoSolver/ic.tec`, an ASCII Tecplot file with one zone per block and one value per cell. Its bands are what the solver
reads: `rho1` (the density of species 1, here all of the gas), `u`, `v` (the mesh is 2-D) and `p`. In every cell
ρ = 1.1231 kg/m³, N2 at 1 bar and 300 K; in block 4 `u` = 50 m/s, a Mach number of 0.14.

Open the case folder in the GUI (`ATLAS GUI`, then **Case folder…**) to see the field: the Initial stage draws the
pressure, the temperature, the Mach number of every cell ICB wrote.

## Try Next

- Give `T0 = 300.0` instead of `T` in block 4: ICB takes it as a total temperature and computes the static one from the
  speed on the table of the gas, 298.8 K.
- Write the field in VTK: `IC-format = vtk` in `[ATLAS-Parameters]` gives `fromATLAStoSolver/ic.vtm` and a `.vts` per block
  ([ICB Output](../../user-guide/icb/output.md)).

---

Next: [Zones in a Block](zones.md)
