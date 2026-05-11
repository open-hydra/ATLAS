# Custom Thermodynamic Properties

Custom database provides temperature-dependent thermophysical properties for further species or materials. This database is not a standard YAML file but a Python function that returns tabulated or polynomial properties.

!!! info "Current Status"
    The custom database is currently under development and may not be fully functional. Please refer to the source code for the latest implementation details.

---

## Graphite

| Property | Value / Model |
|---|---|
| $c_p$ | 300 J/(kg·K) — constant |
| $\rho$ | 1000 kg/m³ — constant |
| $k(T)$ | Polynomial: $k = 134.0 - 0.1074\,T + 3.719 \times 10^{-5}\,T^2$ |

$$
k_\text{Graphite}(T) = 134.0 - 0.1074\,T + 3.719 \times 10^{-5}\,T^2 \quad [\text{W/m·K}]
$$

---

## Adding a New Material

Append a new `elif` block to `compute_properties_from_database` in `sp_custom.py` following the established pattern:

```python
elif name == 'MyMaterial':
    k   = 0.0 * temperatures
    cp  = 0.0 * temperatures
    rho = 0.0 * temperatures
    e   = 0.0 * temperatures
    for i in range(0, len(temperatures)):
        k[i]   = ...          # W/(m·K)
        cp[i]  = ...          # J/(kg·K)
        rho[i] = ...          # kg/m³
        if i > 0:
            e[i] = e[i-1] + rho[i] * cp[i] * (temperatures[i] - temperatures[i-1])
        else:
            e[i] = 0.0
```

Then set `material = MyMaterial` and `thermo = SP-database` in `input.ini`.
