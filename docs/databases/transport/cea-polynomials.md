# CEA Transport Polynomials

The CEA polynomial database stores curve-fit coefficients for the dynamic viscosity $\mu$ and thermal conductivity $\lambda$ of gas-phase species. The fits are taken from the NASA CEA (Chemical Equilibrium with Applications) program; below 200 K six records also carry intervals that ATLAS adds, fitted to reference data ([Intervals added by ATLAS](#intervals-added-by-atlas)).

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
| `source` | the code and the reference of the fit, as `trans.inp` writes them; the code `V<n>C<n>` counts the NASA intervals of viscosity and conductivity |
| `viscosity`, `conductivity` | the temperature intervals, each with exactly four coefficients $[A, B, C, D]$, finite numbers; an interval that ATLAS adds carries its own `source` |

With `transport = CEA`, GPB gives each species the record whose `element`, or one of whose `aliases`, is the species name, compared character by character: `AR` finds the record `Ar` through its alias, `ar` finds no record. Names are never compared without case, because NASA names that differ only in case are different species (`CO` and `Co`, `CS` and `Cs`, `SN` and `Sn`). A species without a record gets the simplified law with a `[WARNING]`.

Every name and alias must identify one record: GPB stops with an `[ERROR]` that names the two records (numbered from 1 in the order of the file) when a name or alias appears twice in the file, and with an `[ERROR]` that names the record when `element` is not a non-empty string or `aliases` is not a list of non-empty strings; it stops as well when the file is not a list of records or a record is not a mapping.

Every interval has exactly four coefficients, finite numbers, in the form $[A, B, C, D]$, and a temperature range of finite numbers. GPB stops with an `[ERROR]` that names the file, the record, the property and the interval when an interval that a table uses has another number of coefficients or a coefficient that is not a finite number, and when any interval of a property of a record of a species of the run has a temperature range that is not a list of finite numbers (the lowest and the highest bound of the property come from every interval). GPB also stops, naming the file, the record, the property and the temperatures, when a table temperature lies between the lowest and the highest bound of a property and no interval contains it, or when a property has no intervals. The bounds of an interval are read as its smallest and largest value; where intervals overlap, a temperature takes the last interval of the list that contains it; a record of a species that the run does not use is checked for its name and aliases only.

---

## Intervals added by ATLAS

The NASA fits of N2, O2, Ar, He, Ne and Kr begin at 200 K, as those of ten other records. Below 200 K the records of these six species carry, before the NASA intervals, two intervals per property in the NASA form, each with its own `source`, for example `"ATLAS fit to Lemmon and Jacobsen (2004), dilute gas, Eq. (2), 20-200 K"`:

| species | reference | viscosity from | conductivity from | largest deviation from the reference, viscosity / conductivity |
|---|---|---|---|---|
| N2 | Lemmon and Jacobsen (2004), dilute gas, Eq. (2) and (5) | 20 K | 80 K | 0.27 % / 1.92 % |
| O2 | same | 54.33 K | 86.5 K | 0.24 % / 0.45 % |
| Ar | same | 50 K | 50 K | 0.67 % / 0.44 % |
| He | Bich, Millat and Vogel (1990), Table 5 | 5 K | 5 K | 0.25 % / 0.32 % |
| Ne | same, Table 6 | 27.09 K | 27.09 K | 0.11 % / 0.11 % |
| Kr | same, Table 8 | 119.78 K | 119.78 K | 0.19 % / 0.82 % |

- The intervals are least-squares fits of $\ln \mu$ and $\ln \lambda$, with the value and the slope $d \ln p / d \ln T$ equal to those of the NASA interval at 200 K and to each other at the inner bound; their coefficients are written with all the digits of a double (the shortest decimal that reads back the same double), so the joints are continuous within the rounding of double precision. Each interval increases strictly with temperature (its slope is a polynomial of degree two in $1/T$, positive at its ends and at its vertex).
- The fits use the reference data where their authors give them: Lemmon and Jacobsen state that their nitrogen and argon equations are well behaved down to about 20 K and 50 K; for oxygen they give no such limit, and its fit starts at the triple point, 54.33 K; the conductivities of nitrogen and oxygen start at the lowest temperatures of the dilute-gas conductivity data that the paper lists, 80 K and 86.5 K. The tables of Bich, Millat and Vogel start at 5 K for helium and at the normal boiling points of neon and krypton.
- Deviations: on a 1 K grid for Lemmon and Jacobsen, at the points of the tables for Bich, Millat and Vogel. The largest deviations of the nitrogen conductivity (1.92 %), of the krypton conductivity (0.82 %) and of the argon viscosity (0.67 %) are at or near 200 K, where the NASA interval itself deviates from the reference by +1.92 %, +0.82 % and −0.55 %.

---

## Below and above the intervals

GPB tabulates every species from `Tmin` (1 K by default) to `Tmax`. Outside the intervals of a record (`src/GPB/cea_transport_rule.py`):

- **Below the lowest viscosity bound** $T_{lo}$ the viscosity continues the record with its value and its logarithmic slope $n = A - B/T_{lo} - 2C/T_{lo}^2$ at $T_{lo}$:

    | $n$ | viscosity below $T_{lo}$ |
    |---|---|
    | $1/2 < n < 3/2$ | $\mu(T) = \mu(T_{lo}) \, (T/T_{lo})^{3/2} \, (T_{lo} + S)/(T + S)$, $S = T_{lo} (n - 1/2)/(3/2 - n)$: the Sutherland law with value and slope of the record at $T_{lo}$ |
    | $0 < n \le 1/2$ or $n \ge 3/2$ | $\mu(T) = \mu(T_{lo}) \, (T/T_{lo})^n$ |
    | $n \le 0$ | $\mu(T) = \mu(T_{lo})$, with an `[INFO]` line when the table has rows below $T_{lo}$ (the record `RP-1`: $n = -7.17$ at 270 K) |

    For $n > 0$ the viscosity increases with temperature, joins the record with its value and its slope, and goes to zero with $T$.

- **Below the lowest conductivity bound** $T_k$ the Prandtl number keeps its value at $T_k$: $\lambda(T) = \lambda(T_k) \, \mu(T) \, c_p(T) / (\mu(T_k) \, c_p(T_k))$, with $\mu$ as above and $c_p$ the specific heat of the species from its thermo record in the run, held at its value at the bound of its thermo range outside it, as GPB holds it for a species zone of `thermo.dat`. The Prandtl number $\mu c_p / \lambda$ of the species tables is then constant below $T_k$; the conductivity depends on the thermo database of the run where $c_p$ changes below $T_k$. GPB stops with an `[ERROR]` if that specific heat is not a positive finite number.
- **Above the highest bound** of a property the property keeps its value at that bound.

At $T_k$ the conductivity is continuous; its slope changes there.

---

## References

> B.J. McBride, S. Gordon, M.A. Reno, "Coefficients for Calculating Thermodynamic and Transport Properties of Individual Species," NASA TM-4513, 1993.
>
> A. Boushehri, J. Bzowski, J. Kestin, E.A. Mason, "Equilibrium and transport properties of eleven polyatomic gases at low density," *J. Phys. Chem. Ref. Data*, 16(3):445–466, 1987.
>
> R.A. Svehla, "Transport Coefficients for the NASA Lewis Chemical Equilibrium Program," NASA TM-4647, 1995.
>
> E.W. Lemmon, R.T. Jacobsen, "Viscosity and thermal conductivity equations for nitrogen, oxygen, argon, and air," *Int. J. Thermophys.*, 25(1):21–69, 2004.
>
> E. Bich, J. Millat, E. Vogel, "The viscosity and thermal conductivity of pure monatomic gases from their normal boiling point up to 5000 K in the limit of zero density and at 0.101325 MPa," *J. Phys. Chem. Ref. Data*, 19:1289, 1990.
