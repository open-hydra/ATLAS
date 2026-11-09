# Custom Substances

`thermo = custom` takes the substances of a phase from Python code that you write, in place of a database file. Use
it for what no database holds: a material measured in your laboratory, a propellant that is not published, a fluid with
a closed-form equation of state. It works for every kind of GPB phase.

---

## How it works

Each kind of phase has a class, in `database/thermo/custom_classes.py`, and the class is the **contract** of the
category: it declares what a substance of the category receives and what it must give back, with the unit of each
variable. A substance is an **instance** of the class, made with its own data:

```python
UC = CondensedMaterial("UC", cp=300.0, rho=1000.0, k=lambda T: np.interp(T, T_data, k_data))
```

| Phase `type` | Class | Named by | Receives | Gives |
|---|---|---|---|---|
| `solid`, `solid-bulk`, `condensed-dispersed`, `liquid-dispersed`, `solid-dispersed` | `CondensedMaterial` | `material` | the temperature `T` | `cp`, `rho`; optionally `k`, `h`, `psat` |
| `ideal-gas`, `heavy-gas` | `IdealGasSpecies` | `species`, `mixture`, the species of a `reactions` file | nothing: a species is data | `composition` and `nasa7` (or `species()`); optionally `transport` |
| `real-fluid` | `RealFluid` | `fluid` | `(T, p)` and `(h, p)` | `reference` gives `h`, `s`; `state` gives the state |

The tables of each category [below](#condensed-materials) are the contract in full. It is also in the code: each class
lists its `functions` and `data` as `Quantity` and `Function` objects. The constructor checks the keywords against
them (an output the contract does not have, or a required one that is missing, is an error that names the substance),
GPB checks every value a substance returns, and

```bash
python3 database/thermo/custom_classes.py
```

prints the contract of the three categories.

The first argument is the name of the substance, the name that the input file uses: one word of an INI list, with no
blank, comma, semicolon, `=`, `#`, `{` or `}`. A substance registers itself when it is made, so there is no list to keep;
the Python variable it is assigned to is only for your code (`Mo30W_60UN` for the material `Mo30W-60UN`). Within one
file a name can be used once per category.

An output is a number, for a constant, or a function of the inputs (a `lambda` or a `def`). When several substances
share relations with parameters, as the fluids of one equation of state, derive a class from the category's class that
defines the output methods, and make the substances as its instances ([an example](#real-fluids)): the contract is the
same.

The classes are looked up in two files, in this order:

1. `database/thermo/custom.py`, the substances that ship with ATLAS (the [materials below](#shipped-materials));
2. `custom.py` in the case directory, the folder GPB runs in, if there is one.

A substance of the same category and name made in the case directory **replaces** the shipped one, and GPB says so
(`[INFO] GPB: custom: the condensed material Graphite of ./custom.py replaces the one of database/thermo/custom.py`).
Keep your own substances in the case directory: they stay out of the ATLAS tree, which is also where to put data that
must not be published. Both files start with `from custom_classes import ...`; GPB and the GUI find that module.

!!! note "One category per phase"
    The three categories do not mix: `thermo = custom` in a gas phase reads the `IdealGasSpecies` of the files, in a
    condensed phase the `CondensedMaterial`, in a real-fluid phase the `RealFluid`. A material and a gas species can
    have the same name.

Units are SI throughout. A function of `T` receives a numpy array of temperatures [K], the 1 K table of the
phase, and returns an array of the same size, or a number for a constant. Write it with numpy (`np.where`, `np.interp`)
and not with a loop over `T`.

---

## Condensed materials

A solid or a liquid of a [condensed phase](../../user-guide/gpb/condensed-solid.md):
`CondensedMaterial(name, cp=..., rho=..., k=..., h=..., psat=..., absolute_enthalpy=False)`. Input: the temperature `T`
[K]. Outputs, each a number or a function of `T`; the material evaluates them as `material.cp(T)`, and so on:

| Output | Gives | Unit | Required | Valid values | Used for | If not defined |
|---|---|---|---|---|---|---|
| `cp(T)` | specific heat | J/kg/K | yes | > 0 | the `Cp` column | error |
| `rho(T)` | density | kg/m³ | yes | > 0 | the `Density` column | error |
| `k(T)` | thermal conductivity | W/m/K | no | ≥ 0 | `solid` phases: the `Conductivity` column | 0 |
| `h(T)` | specific enthalpy | J/kg | no | any | the `Enthalpy` column of dispersed phases, and the `Energy` column of solids (ρ·h) | the integral of `cp` from the first temperature of the table, zero there |
| `psat(T)` | saturation pressure | Pa | no | > 0 | dispersed phases: the `Psat` column, which a phase has when one of its materials defines `psat` (zeros for the others) | none |

and one datum, `absolute_enthalpy` (default `False`), described [below](#the-enthalpy-datum).

```python
import numpy as np

from custom_classes import CondensedMaterial


Foam = CondensedMaterial(
    "Foam",
    cp=lambda T: 1000.0 + 0.5 * T,                            # [J/kg/K]
    rho=lambda T: 900.0 - 0.4 * (T - 300.0),                  # [kg/m3]
    psat=lambda T: 1.0e5 * np.exp(10.0 * (1.0 - 350.0 / T)),  # [Pa]
)
```

```ini
[GPB-Phase1]
type     = liquid-dispersed
name     = drop
material = Foam Graphite
thermo   = custom
Tmin     = 300
Tmax     = 600
```

`cp`, `rho`, `k` and `h0` in the section are ignored with a `[WARNING]`: the material gives its own.

### The enthalpy datum

Without `h(T)`, the enthalpy is relative: zero at the first temperature of the table, and the column is named
`Enthalpy`. To put a material next to species of NASA9 or Burcat, whose enthalpy contains the heat of formation, set
`absolute_enthalpy=True` and give `h` on that scale. The column is then named `Enthalpy_abs`:

```python
Wax = CondensedMaterial(
    "Wax",
    cp=2500.0,
    rho=800.0,
    h=lambda T: -2.0e5 + 2500.0 * (T - 298.15),               # -2.0e5 J/kg at 298.15 K
    absolute_enthalpy=True,                                   # h is on the formation scale
)
```

One file carries one datum: a phase whose materials do not all have the same `absolute_enthalpy` is refused
(`condensed materials mix absolute and relative enthalpy data in one phase`).

---

## Ideal-gas species

A species of the thermo database of a [gas phase](../../user-guide/gpb/ideal-gas.md). A species receives nothing: it is
data, and Cantera evaluates its thermodynamics at the temperatures of the solver:
`IdealGasSpecies(name, composition=..., nasa7=..., transport=...)`, with the NASA 7-coefficient polynomials of Chemkin, Burcat and Cantera files:

```python
from custom_classes import IdealGasSpecies


N2 = IdealGasSpecies(                              # N2 of GRI-Mech 3.0, which fits 300-5000 K
    "N2",
    composition={"N": 2},
    nasa7={"Tmin": 300.0, "Tmid": 1000.0, "Tmax": 5000.0,
           "low":  [3.298677, 0.0014082404, -3.963222e-06, 5.641515e-09, -2.444854e-12, -1020.8999, 3.950372],
           "high": [2.92664, 0.0014879768, -5.68476e-07, 1.0097038e-10, -6.753351e-15, -922.7977, 5.980528]},
    transport={"geometry": "linear", "diameter": 3.621, "well_depth": 97.53,
               "polarizability": 1.76, "rotational_relaxation": 4.0},       # optional
)
```

| Datum | Required | Meaning |
|---|---|---|
| `composition` | yes | elements and their counts |
| `nasa7` | yes | `Tmin`, `Tmid`, `Tmax` [K] and the 7 coefficients of the low (`Tmin`–`Tmid`) and high (`Tmid`–`Tmax`) range, in the order of the files; optionally `reference_pressure` [Pa], 1 atm by default as in the database files |
| `transport` | no | the Lennard-Jones data of Cantera's `GasTransportData`: `geometry` (`atom`, `linear` or `nonlinear`), `diameter` [Å], `well_depth` [K], and optionally `dipole` [Debye], `polarizability` [Å³], `rotational_relaxation`. Without it, GPB takes the record of the species in `Lennard-Jones.yaml` |

For any other form (NASA 9-coefficient polynomials, a constant cp, a formula) give the optional output `species`, a
function of nothing that returns a `cantera.Species` with the name of the substance; `composition` and `nasa7` are then
not needed.

The species of a phase are those of the section, taken from the classes as from a database file: a
`species` list, a `mixture`, or the species of a `reactions` file, whose thermo records `custom` replaces as `NASA9`
would (`strict-thermo` applies). **The order of the species in the phase is the order in which they are made**, as it is the order of the file for a database. As for a database, `transport = CEA` takes the transport of
the species by name from the CEA records, and `CEA-file` makes GPB read `NASA9` for the equilibrium species (a
`[WARNING]` says so).

```ini
[GPB-Phase1]
type      = ideal-gas
species   = O2 N2
thermo    = custom
transport = CEA
Tmax      = 400
```

---

## Real fluids

A fluid tabulated on a grid of pressure and mass enthalpy, like the other [real-fluid](real-fluids.md) models:
`RealFluid(name, reference=..., state=...)`. Two functions, both required:

| Function | Receives | Returns |
|---|---|---|
| `reference(T, p)` | `T` [K], `p` [Pa] | `(h, s)`: the enthalpy [J/kg] and entropy [J/kg/K]. GPB uses it for the enthalpy bounds of the table, and shifts `h` and `s` to zero at (`Tmin`, `pmin`) |
| `state(h, p)` | `h` [J/kg], `p` [Pa] | a `dict`, with the keys of the next table |

| Key of `state` | Unit | Meaning | Valid values | Required |
|---|---|---|---|---|
| `T` | K | temperature | > 0 | yes |
| `rho` | kg/m³ | density | > 0 | yes |
| `drho_dT` | kg/m³/K | ∂ρ/∂T at constant `p` | any | yes |
| `drho_dh` | kg/m³/(J/kg) | ∂ρ/∂h at constant `p` | any | yes |
| `drho_dp` | kg/m³/Pa | ∂ρ/∂p at constant `h` | any | yes |
| `cp` | J/kg/K | specific heat | > 0 | yes |
| `s` | J/kg/K | entropy | any | yes |
| `mu` | Pa·s | dynamic viscosity | ≥ 0 | yes |
| `k` | W/m/K | thermal conductivity | ≥ 0 | yes |
| `a` | m/s | speed of sound | > 0 | no |

Without `a`, GPB writes 500 m/s and prints `[WARNING] speed of sound fallback (500 m/s) used for some points`.

An equation of state has parameters, and several fluids can share it. Write it once as a class derived from
`RealFluid` that defines `reference` and `state`, and make each fluid an instance of it with its own parameters. A
calorically perfect gas has a closed form for all of it:

```python
import numpy as np

from custom_classes import RealFluid


class PerfectGas(RealFluid):
    """A calorically perfect gas: the equation of state, for any R, cp, mu, k."""

    def __init__(self, name, R, cp, mu, k, T_ref=298.15, p_ref=1.0e5):
        super().__init__(name)
        self.R, self.cp, self.mu, self.k = R, cp, mu, k
        self.T_ref, self.p_ref = T_ref, p_ref

    def entropy(self, T, p):
        return self.cp * np.log(T / self.T_ref) - self.R * np.log(p / self.p_ref)

    def reference(self, T, p):
        return self.cp * T, self.entropy(T, p)

    def state(self, h, p):
        T = h / self.cp
        rho = p / (self.R * T)
        gamma = self.cp / (self.cp - self.R)
        return {"T": T, "rho": rho,
                "drho_dT": -rho / T,                   # at constant p
                "drho_dh": -rho / (self.cp * T),       # at constant p
                "drho_dp": 1.0 / (self.R * T),         # at constant h
                "cp": self.cp, "s": self.entropy(T, p), "mu": self.mu, "k": self.k,
                "a": np.sqrt(gamma * self.R * T)}


PerfectAir = PerfectGas("PerfectAir", R=287.0, cp=1005.0, mu=1.8e-5, k=0.026)
```

```ini
[GPB-Phase1]
type   = real-fluid
name   = air
fluid  = PerfectAir
thermo = custom
pmin   = 1.0e5
pmax   = 1.0e6
Tmin   = 300
Tmax   = 900
NP     = 5
NH     = 6
```

`state` is called `NP × NH` times, so an expensive equation of state (an iteration, a call to another library) sets the
time GPB takes.

---

## Trying a substance without GPB

A substance is a plain Python object. For a condensed material, `properties(T)` runs the checks that GPB runs and
returns the arrays that it will write:

```bash
cd $ATLASDIR/database/thermo         # or PYTHONPATH=$ATLASDIR/database/thermo from the case directory
python -c "
import numpy as np, custom
print(custom.UC.properties(np.arange(300., 303.))['k'])"
```

---

## Errors

A substance is checked when it is made (its keywords against the contract of its class) and when GPB uses it (every
value it returns); the message names the substance, and the temperature of a bad value:

| Cause | Message |
|---|---|
| the name is not in any `custom.py` | `[ERROR] [GPB-Phase1] material = Nope (thermo = custom): no condensed material 'Nope' in custom.py (database/thermo/custom.py or the case directory). Defined: ...` |
| a `custom.py` that fails when it runs | `[ERROR] [GPB-Phase1] thermo = custom: <file>, line 4: RuntimeError: ...` |
| `cp`, `rho` or `psat` not above 0 (or not a number), `k` below 0 | `[ERROR] GPB: custom condensed material Bad: cp(550 K) = 0 is not a valid value (positive)` |
| a function returns the wrong number of values | `... cp(T) returned 3 value(s) for 301 temperatures` |
| `cp` or `rho` not given | `... CondensedMaterial 'Foam': give rho(T) (required by CondensedMaterial)` |
| an output the contract does not have (a misspelt `kk=`) | `... CondensedMaterial 'Foam': kk is not in the contract of CondensedMaterial (it takes cp, rho, k, h, psat, absolute_enthalpy)` |
| a name made twice in one file | `... CondensedMaterial 'Foam': made twice in the same file` |
| `absolute_enthalpy=True` without `h` | `... CondensedMaterial 'Wax': absolute_enthalpy=True needs h(T), on the formation scale of the databases` |
| a gas species with neither `nasa7` nor `species` | `... IdealGasSpecies 'N2': give composition and nasa7, or species` |
| no `IdealGasSpecies` in the files, for a gas phase | `[ERROR] [GPB-Phase1] thermo = custom: custom.py defines no ideal-gas species ...` |
| `species()` returns something else than a species with the name of the substance | `... species() of N2 must return a cantera.Species named N2` |
| `reference(T, p)` gives an `h` or `s` that is not a number | `... custom real fluid PerfectAir: reference(T = 300, p = 100000) gives s = nan which is not a valid value` |
| `state(h, p)` lacks a key | `... custom real fluid PerfectAir: state(h, p) lacks mu` |
| `state(h, p)` gives a value its key cannot have (`rho` ≤ 0, `mu` < 0, not a number) | `... PerfectAir: state(h = ..., p = ...) gives rho = -1 which is not a valid value` |

---

## Shipped materials

`database/thermo/custom.py` ships seven solid materials, each an instance of `CondensedMaterial` given its `cp`, `rho`
and `k`. The conductivities are correlations from the literature (below), written as functions of `T` in the file and
shared where the materials share them (`Mo30W-60UN` uses the conductivity of `Mo30W` for its matrix). **The
`cp = 300 J/kg/K` and `rho = 1000 kg/m³` of every one are placeholders** (`CP_PLACEHOLDER`, `RHO_PLACEHOLDER` in the
file), because no source for them has been entered: replace both with the data of the material before using it for more
than the layout of the files (in a `custom.py` of the case directory, which replaces the shipped material by name):

```python
from custom_classes import CondensedMaterial

UC = CondensedMaterial("UC", cp=..., rho=..., k=...)     # your data
```

| `material` | k(T) [W/m/K], T in K |
|---|---|
| `Graphite` | $134.0 - 0.1074\,T + 3.719\times10^{-5}\,T^2$ |
| `ZrC` | $0.5209 + 9.812\times10^{-4}\,T + 1.045\times10^{-7}\,T^2$ |
| `Zircaloy` | $131.2 - 0.08432\,T + 1.96\times10^{-5}\,T^2$ |
| `ZrHx` | 16 |
| `UC` | linear interpolation of 32 measured points between 98.8 and 2800 K, constant beyond them |
| `Mo30W` | $0.7\,k_\text{Mo} + 0.3\,k_\text{W}$, with piecewise polynomials for molybdenum and tungsten |
| `Mo30W-60UN` | the Mo30W matrix with 60 % uranium nitride by volume: $k = k_\text{UN} + (1-v_p)(k_m - k_\text{UN})(k_\text{UN}/k_m)^{1/3}$ |

`thermo = SP-database`, the former name of the materials of `sp_custom.py`, is accepted with a `[WARNING]` and means
`thermo = custom`.
