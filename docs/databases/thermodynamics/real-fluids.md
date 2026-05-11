# Real-Fluid Databases

For high-pressure propulsion applications where ideal-gas assumptions break down (transcritical injection, supercritical combustion), ATLAS provides two cubic equation-of-state databases implemented as Cantera-compatible YAML files.

---

## Available Databases

| EOS model | Fluids |
|---|---|
| CoolProp | 100+ fluids |  
| Peng-Robinson (PR) | CO₂, H₂O |
| Redlich-Kwong (RK) | CO₂, H₂O |

!!! tip Adding new fluids
    To add new fluids to the cubic EOS databases, create a new entry in `peng-robinson.yaml` or `redlich-kwong.yaml`, and add the appropriate critical constants and acentric factor. Critical constants for most species are available at the [NIST Chemistry WebBook](https://webbook.nist.gov/chemistry/).

---

## Equations of State

### Peng-Robinson

$$
P = \frac{RT}{V_m - b} - \frac{a(T)}{V_m(V_m + b) + b(V_m - b)}
$$

$$
a(T) = a_c \left[1 + \kappa\left(1 - \sqrt{T/T_c}\right)\right]^2, \quad \kappa = 0.37464 + 1.54226\,\omega - 0.26992\,\omega^2
$$

$$
a_c = 0.45724\,\frac{R^2 T_c^2}{P_c}, \qquad b = 0.07780\,\frac{R T_c}{P_c}
$$

### Redlich-Kwong

$$
P = \frac{RT}{V_m - b} - \frac{a(T)}{V_m(V_m + b)\,\sqrt{T}}
$$

$$
a = 0.42748\,\frac{R^2 T_c^{2.5}}{P_c}, \qquad b = 0.08664\,\frac{R T_c}{P_c}
$$

---

## Reference

- Peng-Robinson: Peng, D.-Y., & Robinson, D. B. (1976). A new two-constant equation of state. Industrial & Engineering Chemistry Fundamentals, 15(1), 59–64. https://doi.org/10.1021/i160057a011
- Redlich-Kwong: Redlich, O., & Kwong, J. N. S. (1949). On the thermodynamics of solutions. V. An equation of state. Fugacities of gaseous solutions. Chemical Reviews, 44(1), 233–244. https://doi.org/10.1021/cr60135a012
- CoolProp: Bell, I. H., Wronski, J., Quoilin, S., & Lemort, V. (2014). Pure and pseudo-pure fluid thermophysical property evaluation and the open-source thermophysical property library CoolProp. Industrial & Engineering Chemistry Research, 53(6), 2498–2508. https://doi.org/10.1021/ie4033999

---
