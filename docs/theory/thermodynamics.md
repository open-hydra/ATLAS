# Thermodynamics

::: warning Work in progress
This page is being populated.
:::

## Caloric Model

ATLAS supports two caloric models for the ideal-gas phases:

**Calorically perfect gas (CPG)** — constant specific heats:

$$c_p = \text{const}, \quad h(T) = c_p T, \quad \gamma = c_p / c_v$$

**Thermally perfect gas (TPG)** — temperature-dependent specific heats from polynomial fits:

$$c_p(T) = R \sum_{n} a_n T^{n-1}, \quad h(T) = \int_{T_\text{ref}}^{T} c_p(\tau)\,\mathrm{d}\tau$$

GPB generates $c_p(T)$, $h(T)$, and $s^\circ(T)$ tables on the $[T_\text{min},\, T_\text{max}]$ range specified in the INI file.

## Mixture Rules

For a mixture of $N_s$ species with mass fractions $Y_k$:

$$c_{p,\text{mix}} = \sum_{k=1}^{N_s} Y_k c_{p,k}(T), \quad M_{w,\text{mix}} = \left(\sum_{k=1}^{N_s} \frac{Y_k}{M_{w,k}}\right)^{-1}$$

## Heavy-Gas Scaling

When `type = heavy-gas` is set, GPB applies a pressure scaling factor:

$$p_\text{HG} = H_\text{factor} \cdot p, \quad H_\text{factor} = 10^5$$

This is used for propellant-loaded flows where the mixture contains condensed species alongside the gas phase. The factor is defined in `config.py` as `HG_FACTOR`.
