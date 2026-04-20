# Equations of State

::: warning Work in progress
This page is being populated.
:::

## Ideal Gas

$$p = \rho R_\text{spec} T, \quad R_\text{spec} = R_u / M_w$$

This is the default EOS for all `type = ideal-gas` phases.

## Real-Fluid EOS

For `type = real-fluid`, GPB pre-computes a 2-D lookup table in $(p, h)$ space over a user-defined range.

### CoolProp (default)

CoolProp is called via its Python interface to generate high-accuracy tables for pure fluids (e.g. $\text{CO}_2$, $\text{H}_2\text{O}$). Set `model = coolprop` (default).

### Redlich–Kwong

$$p = \frac{R_u T}{v - b} - \frac{a}{\sqrt{T}\, v(v+b)}$$

Set `model = redlich-kwong`.

### Peng–Robinson

$$p = \frac{R_u T}{v - b} - \frac{a\,\alpha(T)}{v(v+b) + b(v-b)}$$

Set `model = peng-robinson`.

## Lookup Table Grid

The $(p, h)$ grid dimensions are controlled by `NP` (pressure points, default 200) and `NH` (enthalpy points, default 200). Finer grids improve accuracy at the cost of larger files and longer build times.
