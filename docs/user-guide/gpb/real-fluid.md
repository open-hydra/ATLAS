# GPB — Real-Fluid Phase

Contrary to the ideal-gas phase, a real fluid is a single species, whose properties come from an equation of state
(EOS) chosen with the key `model`. GPB tabulates them on a grid of `NP` pressures between `pmin` and `pmax` [Pa] and
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

| `model` | Backend |
|---|---|
| `coolprop` (default) | CoolProp, the fluids of its library |
| `redlich-kwong` | Redlich–Kwong, the fluids of `database/thermo/redlich-kwong.yaml` |
| `peng-robinson` | Peng–Robinson, the fluids of `database/thermo/peng-robinson.yaml` |

### CoolProp (recommended)

Uses CoolProp's high-accuracy equations of state. Supports a large list of fluids including `CO2`, `Water`, `Nitrogen`, `Hydrogen`, `Methane`, etc.

### Redlich–Kwong

$$p = \frac{R_u T}{v - b} - \frac{a}{\sqrt{T}\,v(v+b)}$$

Implemented internally. Suitable for quick checks; less accurate than CoolProp near the critical point.

### Peng–Robinson

$$p = \frac{R_u T}{v - b} - \frac{a\,\alpha(T)}{v(v+b) + b(v-b)}$$

Implemented internally. Better liquid-density prediction than Redlich–Kwong, but still less accurate than CoolProp.
