# CEA Transport Polynomials

The CEA polynomial database stores curve-fit coefficients for the dynamic viscosity $\mu$ and thermal conductivity $\lambda$ of gas-phase species. The fits are taken from the NASA CEA (Chemical Equilibrium with Applications) program.

---

## Polynomial Form

Over each temperature interval $[T_{\text{lo}}, T_{\text{hi}}]$:

$$
\ln \mu = A \ln T + \frac{B}{T} + \frac{C}{T^2} + D
$$

$$
\ln \lambda = A \ln T + \frac{B}{T} + \frac{C}{T^2} + D
$$

where the coefficients $[A, B, C, D]$ differ for viscosity and conductivity. The actual property values are obtained by exponentiation:

$$
\mu = \exp(\ln \mu), \qquad \lambda = \exp(\ln \lambda)
$$

Units of the raw polynomial output are micro-poise (µP) for viscosity and micro-watts per cm·K (µW/cm·K) for conductivity; ATLAS converts to SI (Pa·s and W/m·K) internally.

---

## References

> B.J. McBride, S. Gordon, M.A. Reno, "Coefficients for Calculating Thermodynamic and Transport Properties of Individual Species," NASA TM-4513, 1993.
>
> A. Boushehri, J. Bzowski, J. Kestin, E.A. Mason, "Equilibrium and transport properties of eleven polyatomic gases at low density," *J. Phys. Chem. Ref. Data*, 16(3):445–466, 1987.
>
> R.A. Svehla, "Transport Coefficients for the NASA Lewis Chemical Equilibrium Program," NASA TM-4647, 1994.
