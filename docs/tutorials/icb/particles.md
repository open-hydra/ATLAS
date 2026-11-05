# A Gas With Particles

**Tool:** ICB · **Case:** the mesh and phases of `test/ICB/IG+DP` · **Run time:** under a second

The initial field of two phases at once: a gas, and liquid alumina droplets carried by it, as in the nozzle of a solid
rocket motor. ICB builds the dispersed phase from the state of the gas.

## What You'll Learn

- How a block builds every phase of the case, and how a dispersed phase is given relative to the gas
- What ICB writes for a dispersed phase, population by population

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | The 2-D nozzle of [Nozzle Flow](nozzle.md) |
| `gas-phase.txt`, `gas-thermo.dat` | The gas `gas`: N2 |
| `particles-phase.txt`, `particles-properties.dat` | The dispersed phase `particles`: AL2O3(L) in one population, solved as an Eulerian phase (`modeling=eulerian`), and its properties against T |
| `input.ini` | The initial state, in `test/tutorials/icb-particles/` |

```ini
--8<-- "test/tutorials/icb-particles/input.ini"
```

The block has no `phase` key, so it builds both phases. `p` and `T` are the state of the gas; `krho` is the density
of the particles as a fraction of that of the gas, and `dp` their diameter (m). They move with the gas, at its
temperature times `kT` (1 when not given).

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-particles && cd ~/atlas-tutorials/icb-particles
cp $ATLASDIR/test/ICB/IG+DP/{mesh.tec,gas-phase.txt,gas-thermo.dat,particles-phase.txt,particles-properties.dat} .
cp $ATLASDIR/test/tutorials/icb-particles/input.ini .
ATLAS ICB
```

## What It Writes

Two files, one per phase:

- `fromATLAStoSolver/gas-ic.tec`: `rho1 u v w p`, the gas at 1 bar and 555.56 K, ρ = 0.6065 kg/m³;
- `fromATLAStoSolver/particles-ic.tec`: the bands of population 1 of material 1, `rp_11 up_11 vp_11 wp_11 Tp_11 np_11`: the
  density of the particles, 0.1213 kg/m³ (0.20 of the gas), their velocity, their temperature, and their number per m³,
  1.16 × 10¹⁰, from the diameter and the density of alumina in `particles-properties.dat`.

## Try Next

- Two populations of the material (`AL2O3(L) 2` in `particles-phase.txt`) with one value per population:
  `krho = 0.20, 0.30` (the test `IG+DP-population-forms`).
- Build the gas alone in one block: `phase = gas` in its section.
- The nozzle law for both phases: `type = nozzle` with `p0 = 10.342e+5` and `T0 = 555.56` (see [Nozzle Flow](nozzle.md)):
  the particles take the speed and the temperature of the gas in every row.

---

Next: the [source terms](../stb/index.md).
