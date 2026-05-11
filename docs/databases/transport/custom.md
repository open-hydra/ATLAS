# Custom Transport Model

Custom transport model provides empirical correlations for the dynamic viscosity $\mu$ and thermal conductivity $\lambda$ of the desired species. The model is implemented as a Python function that accepts a temperature array and returns the corresponding transport properties.

!!! info "Current Status"
    Currently the only species described here is liquid paraffin wax, used as a regression fuel in hybrid rocket motors.

## Liquid Paraffin Wax (Marano Correlation)

The Marano model provides empirical correlations for the dynamic viscosity $\mu$ and thermal conductivity $\lambda$ of liquid paraffin wax, used as a regression fuel in hybrid rocket motors. The correlation coefficients were fitted to experimental data for a high-molecular-weight alkane (dotriacontane, C₃₂H₆₆).

### Dynamic Viscosity

$$
\mu(T) = 10^{-3} \exp\!\left( A_\mu + \frac{B_\mu}{T} + C_\mu \ln T + D_\mu T^2 + \frac{E_\mu}{T^2} \right) \quad [\text{Pa·s}]
$$

| Coefficient | Value |
|---|---:|
| $A_\mu$ | 104.673 740 20 |
| $B_\mu$ | −14 186.441 94 |
| $C_\mu$ | −13.543 674 95 |
| $D_\mu$ | −3.161 × 10⁻⁶ |
| $E_\mu$ | 2 129 422.162 0 |

### Thermal Conductivity

$$
\lambda(T) = A_\lambda + B_\lambda\, T \quad [\text{W/m·K}]
$$

| Coefficient | Value |
|---|---:|
| $A_\lambda$ | 0.208 397 216 0 |
| $B_\lambda$ | −1.425 55 × 10⁻⁴ |

---

## Reference

> G. Leccese, "Modeling and simulation of hybrid rocket propellant combustion: regression rate and heat transfer analysis," PhD thesis, Sapienza University of Rome, 2019.
