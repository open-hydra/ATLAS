# Lennard-Jones Transport Database

The Lennard-Jones transport database stores the potential parameters needed by Cantera's mixture-averaged and multicomponent transport models. These parameters — molecular geometry, collision diameter $\sigma$, well depth $\varepsilon/k_B$, dipole moment $\mu$, polarizability $\alpha$, and rotational relaxation number $Z_\text{rot}$ — are combined with Chapman-Enskog theory to compute viscosity, thermal conductivity, and diffusion coefficients.

---

## Theory

Viscosity of a pure species from Chapman-Enskog theory:

$$
\mu = 2.6693 \times 10^{-6} \frac{\sqrt{M T}}{\sigma^2 \,\Omega^{(2,2)*}(T^*)}
$$

where $T^* = k_B T / \varepsilon$, $M$ is the molar mass in g/mol, $\sigma$ is in Å, and $\Omega^{(2,2)*}$ is the collision integral.

Thermal conductivity via Eucken's relation:

$$
\lambda = \frac{1}{4} \left( 9\gamma - 5 \right) \frac{\mu c_v}{M}
$$

---

## References

> R.J. Kee, J.F. Grcar, M.D. Smooke, J.A. Miller, "PREMIX: A Fortran Program for Modeling Steady Laminar One-dimensional Premixed Flames," Sandia Report SAND85-8240, 1985. (Original source for many LJ parameters.)
>
> Cantera documentation: https://cantera.org/documentation/dev/sphinx/html/yaml/species.html#transport
