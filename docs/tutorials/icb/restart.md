# Restart From Another Solution

**Tool:** ICB · **Case:** `test/ICB/IG-interp-mindist` · **Run time:** about 15 seconds

A solution of MOSE on one mesh taken as the initial field of a new mesh: ICB finds, for every new cell, the nearest cell
of the old solution and copies its state. Use it to restart on a refined mesh, or on a mesh of another topology.

## What You'll Learn

- How `old-solution` and `interpolation-law` read a previous solution
- What ICB keeps of the old file: the state, the turbulence band, and what it ignores
- How the interpolation laws differ

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | The new mesh: two 3-D blocks, `core` (70 × 12 × 12 cells) and `outer` (70 × 24 × 24) |
| `field.tec` | A solution written by MOSE on another mesh (14 MB): the coordinates and the cell values `rho1 u v w p`, the Spalart–Allmaras variable and three auxiliary bands |
| `phase.txt` | The gas of that run: one species, an air mixture |
| `input.ini` | The initial state |

```ini
[ICB-Block*]
old-solution = field.tec
interpolation-law = minimum_distance
```

`minimum_distance` takes, for every cell of the new mesh, the state of the nearest cell centre of the old solution:
it needs no relation between the two meshes. The other laws ([IC Strategies](../../user-guide/icb/ic-strategies.md))
use the structure of the meshes: `index` maps cell to cell between blocks of the same size, `multiple` refines a block by
an integer factor, `extrude` revolves a 2-D solution.

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-restart && cd ~/atlas-tutorials/icb-restart
cp $ATLASDIR/test/ICB/IG-interp-mindist/{input.ini,mesh.tec,field.tec,phase.txt} .
ATLAS ICB
```

ICB says what it takes of the old file:

```text
  - read_vtk_tec: adopting            1  turbulence band(s) of 'field.tec' by name
  - read_vtk_tec: ignoring            3  other trailing band(s) (auxiliary variables)
```

The Spalart–Allmaras band is kept (the new field carries `rhoNuTilde`); `T`, `g` and `R`, which MOSE writes for
post-processing, are not part of the state. The two `[WARNING] thermo file, thermo.dat not found` lines are harmless
here: copying a state needs no table of the gas.

## What It Writes

`fromATLAStoSolver/ic.tec`, the two blocks of the new mesh with the bands `rho1 u v w p rhoNuTilde`: pressure between 0.99 and
1.02 bar, temperature between 278 and 305 K, axial speed between -11 and 12 m/s, the flow of the old run.

## Try Next

- A zone of a block can be interpolated while another takes a uniform state: `type = interpolation` in one zone
  ([Zones in a Block](zones.md)).
- An old solution of another gas: `old-species` gives the phase file of the old run (`old-species = old/` reads
  `old/<phase>phase.txt`), when its species are not those of the new one ([IC Strategies](../../user-guide/icb/ic-strategies.md)).

---

Next: [A Gas With Particles](particles.md)
