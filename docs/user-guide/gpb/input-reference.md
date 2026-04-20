# GPB Input Reference

Full list of INI keys recognised by GPB, grouped by phase type.

## Common Keys (all phase types)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `name` | string | section name | Phase name used in the output filename |
| `type` | string | `ideal-gas` | Phase type (see [index](./)) |
| `Tmin` | real | `1.0` | Lower temperature bound for property tables (K) |
| `Tmax` | real | `5000.0` | Upper temperature bound for property tables (K) |

---

## Ideal-Gas / Heavy-Gas Keys

### Model Selectors

| Key | Choices | Description |
|-----|---------|-------------|
| `thermo` | `NASA9`, `CEA`, `cantera`, `fixed` | Thermodynamic data source |
| `transport` | `CEA`, `cantera`, `sutherland`, `fixed` | Transport data source |
| `reactions` | mechanism name / `none` | Reaction mechanism name (Cantera `.yaml`) |
| `phase` | Cantera phase name | Phase name inside the Cantera mechanism file |

### Species

| Key | Type | Description |
|-----|------|-------------|
| `species` | space-separated list | Species to include (e.g. `N2 O2 H2O`) |
| `add-species` | space-separated list | Additional inert species to append |
| `inerts-mixing` | bool | Apply mixture rules to inert species |

### Fixed-Gas Properties

Over-specified sets are accepted; GPB solves the algebraic system to find all remaining properties.

| Key | Type | Description |
|-----|------|-------------|
| `gamma` | real (one per species) | Specific heat ratio |
| `cp` | real (one per species) | Specific heat at constant pressure (J kg⁻¹ K⁻¹) |
| `cv` | real (one per species) | Specific heat at constant volume (J kg⁻¹ K⁻¹) |
| `R` | real (one per species) | Specific gas constant (J kg⁻¹ K⁻¹) |
| `mw` | real (one per species) | Molar mass (g mol⁻¹) |
| `mil` | real (one per species) | Dynamic viscosity (Pa s) |
| `kl` | real (one per species) | Thermal conductivity (W m⁻¹ K⁻¹) |
| `Pr` | real (one per species) | Prandtl number |

### Mixture

| Key | Type | Description |
|-----|------|-------------|
| `mixture` | `{species: fraction} ...` | Mixture composition by mass fraction |
| `mixture-name` | string | Optional label for the mixture |

::: tip Mixture syntax
```ini
mixture = {N2: 75.4} {O2: 23.3} {Ar: 1.3}
```
Fractions are mass fractions in percent; they are normalised internally.
:::

### Cantera Equilibrium

| Key | Type | Description |
|-----|------|-------------|
| `eq-pressure` | real (with optional unit) | Equilibrium pressure, e.g. `101325` or `3000 psi` |
| `eq-fuel` | string | Cantera fuel species (e.g. `H2`, `C3H8`) |
| `eq-oxidizer` | string | Cantera oxidizer species (e.g. `O2`, `O2(L)`) |
| `eq-of` | real | Oxidizer-to-fuel mass ratio |
| `eq-fuel-T` | real | Fuel inlet temperature (K) |
| `eq-oxidizer-T` | real | Oxidizer inlet temperature (K) |

### CEA Equilibrium

| Key | Type | Description |
|-----|------|-------------|
| `CEA-file` | string | Path to CEA input/output file (e.g. `CEA.inp`) |
| `CEA-section` | string | Section name within the CEA file |

---

## Condensed / Solid Keys

| Key | Type | Description |
|-----|------|-------------|
| `material` | string | Material name from ATLAS database (e.g. `AL2O3(L)`, `UC`) |
| `groups` | space-separated list | Condensed phase group names |
| `thermo` | `Burcat`, `SP-database`, `fixed` | Thermodynamic data source |
| `rho` | real | Density (kg m⁻³) |
| `cp` | real | Specific heat (J kg⁻¹ K⁻¹) — used when `thermo = fixed` |
| `k` | real | Thermal conductivity (W m⁻¹ K⁻¹) |

---

## Real-Fluid Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `fluid` | string | **required** | CoolProp / NIST fluid name (e.g. `CO2`, `Water`) |
| `pmin` | real | — | Minimum pressure for lookup table (Pa) |
| `pmax` | real | — | Maximum pressure for lookup table (Pa) |
| `Tmin` | real | `1.0` | Minimum temperature (K) |
| `Tmax` | real | `5000.0` | Maximum temperature (K) |
| `NP` | integer | `200` | Number of pressure grid points |
| `NH` | integer | `200` | Number of enthalpy grid points |
| `model` | `coolprop`, `redlich-kwong`, `peng-robinson` | `coolprop` | EOS backend |
