# GPB — Ideal-Gas & Heavy-Gas Phases

## Ideal-gas phase (`type = ideal-gas`)

The user can build the phase exploiting several approaches and databases.

| Approach | Species list | Thermodynamics | Transport | Chemistry |
|---|---|---|---|---|
| Calorically-perfect gas | user-defined | user-defined | user-defined | — |
| Thermally-perfect gas | user-defined | database | database | — |
| Full Cantera phase import | file | file | file | file |
| Finite-rate mechanism | file | database | database | file |
| Cantera equilibrium | run | database | database | — |
| CEA equilibrium | run | NASA9 | database | — |
| Prescribed mixture | user-defined | database | database | — |

These approaches are not mutually exclusive. For example, the species list can be imported from a chemical mechanism, but other species can be added as well.

### Calorically-perfect gas

Specify species list with thermodynamic and transport properties assigned.

```ini
[GPB-Phase1]
name     = gasmix
type     = ideal-gas
species  = N2f Hef
gamma    = 1.4  1.66
mw       = 28.0 4.0
mil      = 1e-5 1.3e-5
kl       = 0.25 0.30
```

### Thermally-perfect gas

Specify species list along with thermodynamic and transport databases.

```ini
[GPB-Phase1]
type      = ideal-gas
species   = N2
thermo    = NASA9
transport = cantera
```

### Direct phase assignment

Full import of a Cantera phase.

Species list, thermodynamic and transported properties as well as chemical reactions are all defined.

```ini
[GPB-Phase1]
type      = ideal-gas
phase     = gri30
```

### Finite-rate chemistry model

Species list imported from the specified chemical mechanism.

Thermodynamics and transport databases can be both selected.

```ini
[GPB-Phase1]
type      = ideal-gas
reactions = gri30
thermo    = NASA9
transport = cantera
```

### Cantera equilibrium

Use a Cantera equilibrium run to define a species composition.

Thermodynamics and transport databases can be both selected.

```ini
[GPB-Phase1]
type         = ideal-gas
eq-of        = 6
eq-pressure  = 3000 psi
eq-fuel      = H2
eq-fuel-T    = 300.0
eq-oxidizer  = O2(L)
```

### CEA equilibrium

Use a CEA input file to define an equilibrium composition.

The thermodynamic database is the NASA9. The transport database may be selected.

```ini
[GPB-Phase1]
type         = ideal-gas
CEA-file     = CEA.inp
transport    = CEA
```

### Prescribed mixture

One species representing a mixture.

Thermodynamics and transport databases can be both selected.

```ini
[GPB-Phase1]
mixture-name = air
mixture      = {N2: 75.4} {O2: 23.3} {Ar: 1.3}
thermo       = NASA9
transport    = CEA
```

### Complex definitions

GPB is capable to deal with more complex scenarios. A complete set of test and tutorials is available in the `test` folder. 

As an example, it is reported an input defintion that computes the combustion products of a CEA equilibrium (`CEA-equilibrium = SRM.inp`). The species from the equilibrium composition are compared with the ones of the Troyes mechanism (`reactions = troyes`), and the ones not included in the latter are added as a single species component (`inerts-mixing = true`).

```ini
[GPB-Phase1]
type            = ideal-gas
CEA-equilibrium = SRM.inp
reactions       = troyes
inerts-mixing   = true
thermo          = NASA9
transport       = CEA
```

---

## Heavy-Gas Phase (`type = heavy-gas`)

Heavy-gas uses the ideal-gas workflow with molecular-weight scaling to emulate a gaseous carrier in mechanical and thermal equilibrium with a condensed-dispersed phase.

All ideal-gas keys are valid; simply change the `type`:

```ini
[GPB-Phase1]
type      = heavy-gas
mixture   = {N2: 55.4} {O2: 23.3} {Ar: 1.3} {AL2O3(L): 20.0}
transport = CEA
```

---