# Chemical Equilibrium

::: warning Work in progress
This page is being populated.
:::

## Cantera Equilibrium

When `eq-fuel` and `eq-oxidizer` are specified, GPB uses Cantera's `equilibrate()` method to compute the equilibrium composition at the given pressure and oxidizer-to-fuel ratio.

Relevant INI keys:

| Key | Description |
|-----|-------------|
| `eq-pressure` | Equilibrium pressure (Pa or with unit, e.g. `3000 psi`) |
| `eq-fuel` | Fuel species name (Cantera syntax) |
| `eq-oxidizer` | Oxidizer species name (e.g. `O2(L)`) |
| `eq-of` | Oxidizer-to-fuel mass ratio |
| `eq-fuel-T` | Fuel inlet temperature (K) |
| `eq-oxidizer-T` | Oxidizer inlet temperature (K) |

The resulting equilibrium mixture is then used as the basis for the thermodynamic / transport table generation.

## CEA Equilibrium

When `CEA-file` and `CEA-section` are specified, GPB reads a pre-run CEA output file and extracts the equilibrium species composition from the named section. The coefficients from this composition then seed the NASA-9 polynomial fit infrastructure.

The CEA transport polynomials database is read from `$ATLASDIR/database/transport/CEApolynomials.yaml`.
