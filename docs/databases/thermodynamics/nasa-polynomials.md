# NASA Polynomial Databases

ATLAS ships one NASA-format thermodynamic database for ideal-gas species, stored in Cantera YAML: `nasa9.yaml`
(`thermo = NASA9`). `thermo = NASA7` selects one that Cantera ships, `nasa_gas.yaml` (748 gas species, 200–6000 K, the
NASA7 form below). `thermo = Burcat` reads `burcat.yaml`, in the same form, which the user supplies: see
[Burcat](#burcat-extended-third-millennium-database).

---

## NASA9 — Glenn Research Center

| Attribute | Value |
|---|---|
| **Format** | NASA 9-coefficient (NASA9) |
| **Species** | 2019 |
| **Temperature ranges** | Up to three intervals: 200 – 1000 – 6000 – 20 000 K |
| **Source** | NASA Glenn Research Center thermodynamic database |

### Polynomial Form

The NASA9 model fits $c_p^\circ / R$ over each temperature interval with nine coefficients:

$$
\frac{c_p^\circ}{R} = \frac{a_1}{T^2} + \frac{a_2}{T} + a_3 + a_4 T + a_5 T^2 + a_6 T^3 + a_7 T^4
$$

Enthalpy and entropy follow by integration:

$$
\frac{H^\circ}{RT} = -\frac{a_1}{T^2} + \frac{a_2 \ln T}{T} + a_3 + \frac{a_4}{2}T + \frac{a_5}{3}T^2 + \frac{a_6}{4}T^3 + \frac{a_7}{5}T^4 + \frac{b_1}{T}
$$

$$
\frac{S^\circ}{R} = -\frac{a_1}{2T^2} - \frac{a_2}{T} + a_3 \ln T + a_4 T + \frac{a_5}{2}T^2 + \frac{a_6}{3}T^3 + \frac{a_7}{4}T^4 + b_2
$$

where $b_1$ and $b_2$ are the integration constants (coefficients 8 and 9 in the YAML).

### Species Coverage

The database covers all major combustion species, including:

- Stable molecules: H₂, O₂, N₂, H₂O, CO, CO₂, CH₄, NO, NO₂, SO₂, HCl, …
- Radicals and atoms: H, O, N, OH, HO₂, CH₃, CH₂O, NH, NH₂, …
- Ions and electrons: H⁺, O⁺, e⁻, …
- Condensed-phase entries (suffixed `(cr)`, `(L)`, `(a)`)

### Reference

> B.J. McBride, S. Gordon, M.A. Reno, "Coefficients for Calculating Thermodynamic and Transport Properties of Individual Species," NASA TM-4513, 1993.
>
> B.J. McBride, M.J. Zehe, S. Gordon, "NASA Glenn Coefficients for Calculating Thermodynamic Properties of Individual Species," NASA/TP-2002-211556, 2002.

---

## Burcat — Extended Third Millennium Database

| Attribute | Value |
|---|---|
| **Format** | NASA 7-coefficient (NASA7) |
| **Species** | thousands, gas and condensed (3746 in the January 2018 edition) |
| **Temperature ranges** | Two intervals: 200 – 1000 – 6000 K |
| **Source** | Burcat, Goos, Ruscic — Active Thermochemical Tables (ATcT) |
| **In ATLAS** | not distributed: `database/thermo/external/burcat.yaml`, put there by the user |

!!! warning "Not distributed with ATLAS"
    The authors provide the database free of charge for non-commercial use, on condition of proper quotation, and
    forbid including it, or parts of it, in any commercial database, software, firmware or hardware, and any other
    commercial use, without their written permission. ATLAS is GPL software that anyone may use commercially, so it does
    not include the file. `thermo = Burcat` needs `burcat.yaml` in `database/thermo/external/` (or in the case
    directory); [`database/thermo/external/README.md`](https://github.com/open-hydra/ATLAS/blob/main/database/thermo/external/README.md)
    gives the authors' notice, where to download the database, the quotation to use, and what is known about
    converting it to Cantera format. Whoever supplies the file is responsible for its use.

### Polynomial Form

The NASA7 model uses seven coefficients per interval:

$$
\frac{c_p^\circ}{R} = a_1 + a_2 T + a_3 T^2 + a_4 T^3 + a_5 T^4
$$

$$
\frac{H^\circ}{RT} = a_1 + \frac{a_2}{2}T + \frac{a_3}{3}T^2 + \frac{a_4}{4}T^3 + \frac{a_5}{5}T^4 + \frac{a_6}{T}
$$

$$
\frac{S^\circ}{R} = a_1 \ln T + a_2 T + \frac{a_3}{2}T^2 + \frac{a_4}{3}T^3 + \frac{a_5}{4}T^4 + a_7
$$

!!! info "Cantera-format files"
    The Burcat files for Cantera in circulation were converted from the Chemkin format. The 2016 edition converted by
    J. Santner, with which ATLAS's tests were written, removes duplicate species names and the tritium species.

### Reference

> A. Burcat, B. Ruscic, "Third Millennium Ideal Gas and Condensed Phase Thermochemical Database for Combustion with Updates from Active Thermochemical Tables," ANL-05/20, 2005.
>
> E. Goos, A. Burcat, B. Ruscic, Extended Third Millennium Ideal Gas Thermochemical Database. Available: http://burcat.technion.ac.il/dir/

---
