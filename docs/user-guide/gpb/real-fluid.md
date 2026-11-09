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
