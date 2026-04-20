# Transport Properties

::: warning Work in progress
This page is being populated.
:::

## Dynamic Viscosity

### Sutherland's Law

$$\mu(T) = \mu_\text{ref} \left(\frac{T}{T_\text{ref}}\right)^{3/2} \frac{T_\text{ref} + S}{T + S}$$

where $S$ is the Sutherland temperature.

### CEA Curve Fits

GPB can use CEA polynomial fits for $\mu(T)$ and $\lambda(T)$ when `transport = CEA` is set. Coefficients are read from `$ATLASDIR/database/transport/CEApolynomials.yaml`.

### Cantera

When `transport = cantera`, GPB calls Cantera's mixture-averaged or multicomponent transport model.

## Thermal Conductivity

Thermal conductivity $\lambda$ follows analogous models to $\mu$.

## Mixture Rules

Viscosity mixture rules (Wilke, Davidson–Cooper) are applied when `thermo = NASA9` and more than one species is present with `inerts-mixing = true`.

## Prandtl Number

When the user specifies `Pr` directly in the INI file, GPB back-computes $\lambda = \mu c_p / \text{Pr}$ rather than using curve fits.
