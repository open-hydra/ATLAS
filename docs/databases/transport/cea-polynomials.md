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

## Records

`database/transport/CEApolynomials.yaml` is a list of records, one per species:

```yaml
  - element: "Ar"
    aliases: ["AR"]
    source: "V3C3 BICH ET AL (1990)"
    viscosity:
      - temperature_range: [200.0, 1000.0]
        coefficients: [0.61205763, -0.67714354E+02, 0.19040660E+03, 0.21588272E+01]
      ...
    conductivity:
      - temperature_range: [200.0, 1000.0]
        coefficients: [0.60968928, -0.70892249E+02, 0.58420624E+03, 0.19337152E+01]
      ...
```

| key | content |
|---|---|
| `element` | the species name; for a species of NASA CEA, as `lib/cea/data/trans.inp` and `thermo.inp` write it (the names of `nasa9.yaml`, the default thermo database), e.g. `Ar`, `SiCL4` |
| `aliases` | optional: other names of the same species, e.g. `["AR"]`, the name in the Chemkin-style mechanism files and in `burcat.yaml` |
| `source` | the code and the reference of the fit, as `trans.inp` writes them |
| `viscosity`, `conductivity` | the temperature intervals, each with its coefficients $[A, B, C, D]$ |

With `transport = CEA`, GPB gives each species the record whose `element`, or one of whose `aliases`, is the species name, compared character by character: `AR` finds the record `Ar` through its alias, `ar` finds no record. Names are never compared without case, because NASA names that differ only in case are different species (`CO` and `Co`, `CS` and `Cs`, `SN` and `Sn`). A species without a record gets the simplified law with a `[WARNING]`.

Every name and alias must identify one record: GPB stops with an `[ERROR]` that names the two records (numbered from 1 in the order of the file) when a name or alias appears twice in the file, and with an `[ERROR]` that names the record when `element` is not a non-empty string or `aliases` is not a list of non-empty strings; it stops as well when the file is not a list of records or a record is not a mapping.

---

## References

> B.J. McBride, S. Gordon, M.A. Reno, "Coefficients for Calculating Thermodynamic and Transport Properties of Individual Species," NASA TM-4513, 1993.
>
> A. Boushehri, J. Bzowski, J. Kestin, E.A. Mason, "Equilibrium and transport properties of eleven polyatomic gases at low density," *J. Phys. Chem. Ref. Data*, 16(3):445–466, 1987.
>
> R.A. Svehla, "Transport Coefficients for the NASA Lewis Chemical Equilibrium Program," NASA TM-4647, 1995.
