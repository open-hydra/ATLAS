# Checking a Mechanism

**Tool:** KAnT · **Cases:** `test/KAnT/equilibrium`, `test/KAnT/ignition_delay` · **Run time:** about 20 seconds each

Before a CFD run with finite-rate chemistry, KAnT runs the mechanisms of the case on 0-D problems that take seconds:
the adiabatic flame temperature of a methane–oxygen rocket chamber, and the ignition delay of methane in oxygen and
steam. Two mechanisms that disagree here will disagree in the CFD.

## What You'll Learn

- How a `[KAnT-Simulation0D]` section defines a sweep of conditions over several mechanisms
- How to read `KAnT-out.dat`, one zone per mechanism

## Part 1: Equilibrium

`input.ini` of `test/KAnT/equilibrium`:

```ini
--8<-- "test/KAnT/equilibrium/input.ini"
```

| Key | Meaning |
|-----|---------|
| `type = HP`, `equilibrium = true` | Equilibrium at constant enthalpy and pressure: the adiabatic flame |
| `pressure-linear = 10 400 20` | 20 pressures from 10 to 400 bar |
| `of` | The oxidizer-to-fuel mass ratio |
| `fuel`, `oxidizer`, `oxidizer-T` | The two streams: liquid methane, and an oxidizer at 530.5 K (mass fractions in %) |
| `reactions` | The mechanisms of [the database](../../databases/chemistry/list.md): CORIA, Jones–Lindstedt, Westbrook–Dryer |
| `thermo = NASA9` | The thermodynamics of every mechanism, so that only their species differ |

```bash
mkdir -p ~/atlas-tutorials/kant-equilibrium && cd ~/atlas-tutorials/kant-equilibrium
cp $ATLASDIR/test/KAnT/equilibrium/input.ini .
ATLAS KAnT
```

`KAnT-out.dat` holds one zone per mechanism: the flame temperature against the pressure. At 10 bar:

| Mechanism | Species | Flame temperature |
|---|---|---|
| CORIA | 17, with the radicals H, O, OH | 3248 K |
| Jones–Lindstedt | 6 | 3513 K |
| Westbrook–Dryer | 5 | 3827 K |

A mechanism without the radicals cannot dissociate the products, and puts the temperature of a hot chamber hundreds of
kelvin too high; the gap closes as the pressure rises and dissociation falls. `ATLAS KAnT --plot` draws the curves.

## Part 2: Ignition Delay

The test case runs eight mechanisms; two are enough to see the method, in `test/tutorials/kant-ignition/input.ini`:

```ini
--8<-- "test/tutorials/kant-ignition/input.ini"
```

10 initial temperatures from 900 K to 1300 K at 15.86 bar, with the detailed FFCM-2 and the global Westbrook–Dryer.

```bash
mkdir -p ~/atlas-tutorials/kant-ignition && cd ~/atlas-tutorials/kant-ignition
cp $ATLASDIR/test/tutorials/kant-ignition/input.ini .
ATLAS KAnT
```

`KAnT-out.dat`: the ignition delay (s) against the initial temperature, a zone per mechanism.

| Initial temperature | FFCM-2 | Westbrook–Dryer |
|---|---|---|
| 900 K | 38.6 ms | 55.9 ms |
| 1033 K | 8.10 ms | 2.73 ms |
| 1300 K | 0.945 ms | 0.046 ms |

The global mechanism has no chain-branching chemistry: from 900 K to 1300 K its delay falls by a factor of 1200, that of
FFCM-2 by 40, and at 1300 K it ignites 20 times too early. A mechanism tuned for the flame temperature can be far off in
ignition.

## Try Next

- `case = <name>` loads the conditions and the measurements of an experiment from
  `database/KAnT/data/reference/cases.yaml`, for a comparison with the data (`test/KAnT/ignition_delay_exp`).
- A counterflow diffusion flame, 1-D: `test/KAnT/counterflow` ([KAnT](../../user-guide/kant/index.md)).
