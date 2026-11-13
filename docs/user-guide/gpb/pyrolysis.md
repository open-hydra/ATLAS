# Pyrolysis-Gas Tables

A charring ablator (carbon-phenolic) that pyrolyses releases a gas through its char: MOSE's boundary condition `506`,
the pyrolysing ablator, blows it at `mdot_pg = phi mdot_ch` with the composition `y_pg(p_w, T_w)` of a table that GPB
writes. One `[GPB-Pyrolysis<n>]` section per material gives the elemental makeup of the gas and the grid; GPB writes
one table per section into `<phase>-pyrolysis.dat`, on the species list of the ideal-gas phase the section names.

```ini
[GPB-Phase1]
name      = gas
type      = ideal-gas
...

[GPB-Pyrolysis1]
name      = MX4926                 ; the name the BCB key pyrolysis-gas gives
phase     = gas                    ; optional with one ideal-gas phase
elements  = C H O
massf     = 0.60957 0.10710 0.28333
p-min     = 1e5                    ; Pa (or a list: p = 1e5 2.1e6 4.1e6)
p-max     = 2.01e7
p-n       = 11
T         = 300 4000 100           ; K: T-min T-max T-step
treatment = gas-only               ; gas-only (default) or strip
```

The keys are listed in the [Input Reference](./input-reference.md#gpb-pyrolysis). The sections are read as
`[GPB-Phase<n>]` are: `[GPB-Pyrolysis1]`, `[GPB-Pyrolysis2]`, ... up to the first one missing. The boundary record that
uses the table is described in [BC Types](../bcb/bc-types.md#gsi-pyrolysing-ablator).

## The Table

The table holds the species of the phase that are made of the makeup's elements only, in the order of
`<phase>-phase.txt`; MOSE maps them onto its species by name and gives 0 to the others. For each pressure and
temperature it holds the equilibrium mass fractions of the pyrolysis gas. Rows sum to 1 within 1e-10.

```text
# hydra pyrolysis-gas composition table
format 1
tables 1
table MX4926
treatment gas-only
elements 3 C 6.0956999999999995E-01 H 1.0710000000000000E-01 O 2.8333000000000003E-01
condensed 0
species 10
CO
...
pressures 11
  1.0000000000000000E+05  2.1000000000000000E+06 ...
temperatures 38
  3.0000000000000000E+02  4.0000000000000000E+02 ...
data
  <y_1> ... <y_10>          one row per (p, T): 11 blocks of 38 rows, pressure-major
...
end table
```

## The Two Treatments

**`gas-only`** (the default): the equilibrium of the gas species alone, graphite excluded. The whole pyrolysis gas is
blown with its elemental makeup: the elements of every row equal `massf` (to round-off, 1e-11 measured) and the mass
blown is `phi mdot_ch`, as the material balance of the char layer gives it. The carbon must then have a gas
carrier: with only `CO` and `CO2` the makeup above holds more carbon than its oxygen can carry, and GPB stops
(`no mixture of the species ... has the makeup's elements in its proportions`). Give the gas list hydrocarbons
(`C2H2,acetylene`, `C2H4`, `CH4`, ...). A short list also changes the equilibrium itself: at 40 bar, with every
C/H/O gas species of `nasa9.yaml` allowed (118), the species outside the ten of the example below hold 0.457 of the
mass at 1500 K (`CH4` 0.240, naphthalene 0.120, benzene 0.081), 0.208 at 2000 K and 0.115 at 2500 K. With `CH4` added
to the ten they hold 0.216 at 1500 K, 0.135 at 2000 K and 0.104 at 2500 K, and the enthalpy of the gas at 40 bar,
2000 K goes from 6.31 to 5.42 MJ/kg, against 5.02 MJ/kg with all 118 species: give the list both `CH4` and `C2H4`.

**`strip`**: the thesis treatment (and RFRAR's): graphite is allowed, then removed, and the gas renormalised. The
condensed carbon `X_C` (0.32 to 0.40 of the pyrolysis-gas mass at the points of the table below) is taken out of the
blown gas while its mass stays in `mdot_pg`: the elements of a row are not the makeup (hydrogen and oxygen are raised
by `1/(1 − X_C)`). GPB prints the range of `X_C` over the grid. Use it to reproduce earlier results.

| p [bar] | T [K] | gas-only: CO | H2 | C2H2 | C2H4 | strip: X_C | CO | H2 | H2O | C2H2 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2000 | 0.496 | 0.074 | 0.429 | 0.002 | 0.396 | 0.821 | 0.177 | 0.000 | 0.002 |
| 40 | 1500 | 0.496 | 0.046 | 0.076 | 0.381 | | | | | |
| 40 | 2000 | 0.496 | 0.070 | 0.378 | 0.056 | 0.396 | 0.819 | 0.177 | 0.002 | 0.002 |
| 40 | 2500 | 0.496 | 0.073 | 0.424 | 0.007 | 0.383 | 0.803 | 0.171 | 0.000 | 0.024 |
| 40 | 3000 | 0.496 | 0.072 | 0.429 | 0.002 | 0.323 | 0.732 | 0.147 | 0.000 | 0.118 |

Makeup C/H/O 0.60957/0.10710/0.28333 (the composition of RFRAR's decks; it is phenol, C6H5OH, less 40 % of its mass as
carbon), gas list `H C2H4 OH CO CO2 H2 H2O O2 O C2H2,acetylene`.

## Engines

`gas-only` is solved with Cantera on the species of the ideal-gas phase as GPB built it (the thermo of its
`thermo.dat`); `strip` with the CEA library of ATLAS (`lib/cea`), on its own database, with graphite `C(gr)`. The
NASA-9 species are evaluated on a 1-bar standard state, the one CEA uses for the same coefficients (`nasa9.yaml` is
read with Cantera's default of 1 atm elsewhere in GPB). A point that does not converge stops GPB with its pressure
and temperature. Outside the polynomial range of a species GPB writes a WARNING (below it) or an INFO (above it), and
both engines extrapolate its thermo: such rows are numerically clean but not physical, and that message is the only
notice. CEA solves mixture temperatures from 160 K to 22000 K: a `strip` point below 160 K stops GPB.
