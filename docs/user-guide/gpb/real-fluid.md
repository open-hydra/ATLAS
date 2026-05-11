# GPB — Real-Fluid Phase

Contrary to the ideal-gas phase, the real-fluid is limited to a single species, and the user must select an equation of state (EOS) backend. This drastically limits the applicability of the real-fluid phase to specific applications.

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

### CoolProp (recommended)

Uses CoolProp's high-accuracy equations of state. Supports a large list of fluids including `CO2`, `Water`, `Nitrogen`, `Hydrogen`, `Methane`, etc.

### Redlich–Kwong

$$p = \frac{R_u T}{v - b} - \frac{a}{\sqrt{T}\,v(v+b)}$$

Implemented internally. Suitable for quick checks; less accurate than CoolProp near the critical point.

### Peng–Robinson

$$p = \frac{R_u T}{v - b} - \frac{a\,\alpha(T)}{v(v+b) + b(v-b)}$$

Implemented internally. Better liquid-density prediction than Redlich–Kwong, but still less accurate than CoolProp.
