# GPB — Real-Fluid Phase

Contrary to the ideal-gas phase, a real fluid is a single species, whose properties come from an equation of state
(EOS) chosen with the key `thermo`. GPB tabulates them on a grid of `NP` pressures between `pmin` and `pmax` [Pa] and
`NH` enthalpies spanning `Tmin` to `Tmax` [K].

## Standard Definition

```ini
[GPB-Phase1]
type = real-fluid
fluid = CO2
pmin = 8e6
pmax = 1.5e7
Tmin = 320
Tmax = 450
NP   = 40
NH   = 40
```

## EOS Backends

| `thermo` | Backend |
|---|---|
| `coolprop` (default) | CoolProp, the fluids of its library |
| `redlich-kwong` | Redlich–Kwong, the fluids of `database/thermo/redlich-kwong.yaml` |
| `peng-robinson` | Peng–Robinson, the fluids of `database/thermo/peng-robinson.yaml` |
| `custom` | the `RealFluid` class named by `fluid` in `custom.py`: [Custom Substances](../../databases/thermodynamics/custom.md#real-fluids) |
| `constant` | the constant properties `cp`, `rho`, `mu`, `k` of the section: [Constant Properties](#constant-properties) |

`thermo` is the key that selects the thermodynamics in every phase type. It was called `model` in this section; `model`
is still read, as `thermo`, with a `[WARNING]`, and a `thermo` and a `model` that differ stop GPB.

### CoolProp (recommended)

Uses CoolProp's high-accuracy equations of state. Supports a large list of fluids including `CO2`, `Water`, `Nitrogen`, `Hydrogen`, `Methane`, etc.

### Redlich–Kwong

$$p = \frac{R_u T}{v - b} - \frac{a}{\sqrt{T}\,v(v+b)}$$

Implemented internally. Suitable for quick checks; less accurate than CoolProp near the critical point.

### Peng–Robinson

$$p = \frac{R_u T}{v - b} - \frac{a\,\alpha(T)}{v(v+b) + b(v-b)}$$

Implemented internally. Better liquid-density prediction than Redlich–Kwong, but still less accurate than CoolProp.

### Custom

For a fluid that the other backends do not have, or a closed-form model, make a `RealFluid` in `custom.py`: it
gives the enthalpy and entropy at a temperature and pressure, and the state at an enthalpy and pressure. GPB tabulates
it like any other backend. See [Custom Substances](../../databases/thermodynamics/custom.md#real-fluids).

### Constant Properties

To give the properties directly, with no EOS, write `thermo = constant` and the values in the section. `fluid` is then
only a label, written in `<name>phase.txt`.

```ini
[GPB-Phase1]
type   = real-fluid
name   = lox
fluid  = LOX
thermo = constant
cp     = 1700      ; [J/kg/K]
rho    = 1140      ; [kg/m3]
mu     = 1.9e-4    ; [Pa s]
k      = 0.15      ; [W/m/K]
a      = 900       ; [m/s], optional
pmin   = 1e6
pmax   = 5e6
Tmin   = 90
Tmax   = 150
```

| Key | Meaning | |
|---|---|---|
| `cp` | specific heat [J/kg/K] | required, positive |
| `rho` | density [kg/m³] | required, positive |
| `mu` | dynamic viscosity [Pa s] | required, positive |
| `k` | thermal conductivity [W/m/K] | required, positive |
| `a` | speed of sound [m/s] | optional; without it 500 m/s and a `[WARNING]`, as for the other backends |

The density, `cp`, `mu`, `k` and `a` are the same at every pressure and enthalpy of the table, and the derivatives of
the density are zero. The temperature still follows the enthalpy, `T = Tmin + h/cp`, and the entropy is
`s = cp ln(T/Tmin)`; `pmin`, `pmax`, `Tmin`, `Tmax`, `NP` and `NH` define the grid as for any real fluid (`NP` and
`NH` can be small, 2 is enough for constant values).
