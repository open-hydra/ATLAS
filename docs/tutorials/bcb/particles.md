# Particles at the Boundaries

**Tool:** BCB · **Case:** `test/BCB/DP-basic` · **Run time:** a few seconds

The boundary conditions of a dispersed phase, the particles or droplets that Hydra's Lagrangian (IGLOO) and Eulerian
(ICE) solvers carry: two injectors, one given relative to the gas and one given by its own state, with a size
distribution read from a file.

## What You'll Learn

- How the keys of a dispersed phase are written: `<phase>-<key>` in the BC section of the face
- The two ways to give a particle inlet: scaled on the gas (`401`) or by its own mass flux (`402`)
- How a size distribution is given: a name (`Normal`, ...) or a file

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | Three blocks of an axisymmetric mesh |
| `drop-phase.txt` | The dispersed phase `drop`: one material (`dummy`) in one population (written by hand for the test) |
| `size-dist.txt` | A size distribution: radius (m) and mass fraction of each class |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = adiabatic
face2 = out
face3 = symmetry
face4 = isoth

[BCB-Block2]
face1 = injOX
face2 = connection
face3 = symmetry
face4 = adiabatic

[BCB-Block3]
face1 = injCH4
face2 = connection
face3 = adiabatic
face4 = adiabatic

[injCH4]
type = inlet
drop-krho = 0.25
drop-kV = 0.80
drop-kT = 0.30
drop-rp = 0.0001
drop-sigmap = 0.5
drop-distribution = ./size-dist.txt

[injOX]
type = inlet
drop-gp = 345.0
drop-Tp = 450
drop-Vp = 100.0
drop-alphap = 26.0
drop-dp = 0.01
drop-sigmap = 0.0
drop-distribution = Normal

[adiabatic]
type = wall
q = 0.0

[isoth]
type = wall
T = 2000

[out]
type = outlet
p = 1.0
```

The phase is named by its file, `drop-phase.txt`, so its keys are `drop-<key>`; a gas phase in the same case would
read the keys without the prefix ([BC Types](../../user-guide/bcb/bc-types.md#inlet)).

| Inlet | Keys | Variant |
|---|---|---|
| `injCH4` | `krho`, `kV`, `kT`: the density, the speed and the temperature of the particles as fractions of those of the gas | `401` |
| `injOX` | `gp` (kg m⁻² s⁻¹), `Vp` (m/s), `Tp` (K), and a direction angle `alphap` | `402` |

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-particles && cd ~/atlas-tutorials/bcb-particles
cp $ATLASDIR/test/BCB/DP-basic/{input.ini,mesh.tec,drop-phase.txt,size-dist.txt} .
ATLAS BCB
```

## What It Writes

`fromATLAStoSolver/drop-bc.txt`, named after the phase. The two inlets:

```text
       3       1       1       1       1     401
  2.5000000000000000E-01  8.0000000000000004E-01         normal,         normal,  2.9999999999999999E-01  1.0000000000000000E-04  5.0000000000000000E-01 ./size-dist.txt  0.0000000000000000E+00
       2       1       1       1       1     402
  3.4500000000000000E+02  1.0000000000000000E+02  2.6000000000000000E+01         normal,  4.5000000000000000E+02  5.0000000000000001E-03  0.0000000000000000E+00 Dirac  0.0000000000000000E+00
```

- `401`: `krho`, `kV`, the two angles, `kT`, the radius `rp`, the width `sigmap` of the distribution, the file of the
  distribution, and the injection spacing `ds` (0: the solver's own).
- `402`: `gp`, the speed, `alphap` = 26 and `betap` normal, `Tp`, the radius 0.005 m (`drop-dp` is a diameter: BCB
  writes half of it), `sigmap`, and `Dirac`: a `Normal` distribution of width 0 is one size.

A dispersed phase with several materials or populations repeats the whole table once per (material, population) pair;
see [BCB Output](../../user-guide/bcb/output.md).

## Try Next

- Several materials and populations: `alumina 2` and `water 1` in `drop-phase.txt` make three (material, population)
  pairs, and a key may take one value per pair (`drop-Tp = 450 460 470`): the case `test/BCB/DP-population-list`.
- A gas and its particles in one case: `test/BCB/IG+CD`.

---

Next: [Gas-Surface Interaction](gas-surface.md)
