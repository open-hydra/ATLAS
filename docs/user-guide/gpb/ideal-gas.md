# GPB — Ideal-Gas & Heavy-Gas Phases

## Ideal-gas phase (`type = ideal-gas`)

The user can build the phase exploiting several approaches and databases.

| Approach | Species list | Thermodynamics | Transport | Chemistry |
|---|---|---|---|---|
| Calorically-perfect gas | user-defined | user-defined | user-defined | — |
| Thermally-perfect gas | user-defined | database | database | — |
| Full Cantera phase import | file | file | file | file |
| Finite-rate mechanism | file | database (file without `thermo`) | database | file |
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

Each species needs two of `cp`, `cv`, `gamma`, `R`, `mw`; the others follow from the universal gas constant R<sub>u</sub> = 8314.46261815324 J/(kmol K), the exact SI value that Cantera also uses. The bundled NASA CEA library (CEA equilibrium, `CEA-file`) keeps its own constant, 8314.51 J/(kmol K).

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

`phase` (like `reactions`) takes the **name of the yaml file** without `.yaml`, searched in the working directory and in `database/chemistry/`; it may differ from the phase name written inside the file, which is the name FLINT uses to select its routine. Example: `phase = WD-andersen` loads `database/chemistry/WD-andersen.yaml`, whose phase is named `WD-Andersen`; `phase = WD-Andersen` is not a file and GPB stops with an error that suggests `WD-andersen`.

### Finite-rate chemistry model

Species list imported from the specified chemical mechanism.

Thermodynamics and transport databases can be both selected. Without `thermo`, the thermodynamic records of the mechanism file are used.

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

### Which keys apply to which approach

- `phase = <file>` imports the yaml as it is: `thermo`, `transport` and `reactions` are **ignored** (the thermo records, the transport data and the reactions of the file are used; the transport model is Cantera's) and GPB says so with a `[WARNING]` naming the ignored keys.
- `reactions = <file>` takes the species list and the reactions from the file, the thermo records from the `thermo` database, or from the file when `thermo` is not given (said with an `[INFO]` line; with `CEA-file` the NASA9 database, as for the CEA equilibrium species), and the transport data from the file (`transport = cantera`) or from `database/transport/CEApolynomials.yaml` (`transport = CEA`).
- The thermo databases (`NASA7`, `NASA9`, `Burcat`) carry **no transport data**: with `transport = cantera` every species of the file needs its Lennard-Jones record in the file (a species without it is refused); with `transport = CEA` the records of the file are not used (a species without a CEA record gets the simplified law with a `[WARNING]`).
- With `thermo` (or `CEA-file`), a species of the mechanism that exists in the database is **replaced** by the database record: GPB prints one line per species with the enthalpy difference at 298.15 K, a `[WARNING]` above 1 kJ/mol, and refuses only with `strict-thermo = true`. A species absent from the database keeps the file record (`This species is not present in the employed database`). Without `thermo` and `CEA-file` no record is replaced. Species that do not come from the file (`species`, `mixture`) take the `thermo` database, NASA9 when `thermo` is not given.
- `Tmin` and `Tmax` are integers (the tables have a 1 K step); the defaults are 1 K and 5000 K.

### Checks and messages

Every diagnostic goes to standard output only; nothing is ever written into the product files (FLINT reads `chemistry-info.txt` and `phase.txt` positionally). The products of a run are written into a temporary directory `.gpb-tmp-<random>/` of its own next to `fromATLAStoSolver/` and moved there only when every phase of the deck succeeded: a refusal (exit status 1) or a crash leaves no product of that run and no temporary directory; files already present in `fromATLAStoSolver/` are never removed (a product of the same name is replaced, stale files of earlier runs stay). If GPB is killed from outside, its `.gpb-tmp-<random>/` stays behind: no later run reads it; remove it by hand.

| situation | level | message starts with | what to do |
|---|---|---|---|
| a boolean key (`inerts-mixing`, `strict-thermo`) with a value that is neither true nor false (e.g. `tru`, read as false before) | ERROR | `[ERROR] key <k> of section [<s>]: <k> = <v> is not a boolean` | write `true` or `false` (also yes/no, on/off, 1/0, t/f) |
| `Tmin` or `Tmax` that is not an integer number of kelvin (e.g. `300.5`, silently replaced by the default before); also in condensed and solid sections | ERROR | `[ERROR] key Tmin of section [<s>]: Tmin = <v> is not an integer number of kelvin` | write an integer (`300` or `300.0`) |
| an explicit `Tmin` below the polynomial range of a species | WARNING | `[WARNING] GPB: Tmin = <T> K is below the polynomial range of <n> species` | nothing: cp, h, s are extrapolated linearly below the range; the default `Tmin = 1` prints no line |
| `Tmax` above the polynomial maximum of a species (cp frozen at the bound, h and s extended linearly) | INFO | `[INFO] GPB: cp frozen at the polynomial maximum for <n> species above their range` | nothing: the line names the species; the tables keep the requested range (the NASA7 records of many mechanism files end at 3500 K, below the default `Tmax = 5000`) |
| `reactions =` without `thermo` (the thermo records of the file are used) | INFO | `[INFO] GPB: reactions = <file> without thermo: the thermo records of the file are used` | nothing; add `thermo = NASA7|NASA9|Burcat` to replace them with a database |
| `reactions =` without `thermo`, with `CEA-file` (the NASA9 records replace those of the file) | INFO | `[INFO] GPB: reactions = <file> without thermo, with CEA-file: NASA9 database assumed` | nothing: the CEA equilibrium species use NASA9 too |
| `thermo` with a value that is not a database | ERROR | `[ERROR] GPB: thermo = <v> is not a database` | `NASA7`, `NASA9` or `Burcat` |
| `thermo = NASA7` or `Burcat` together with `CEA-file` (the CEA equilibrium species use the NASA9 database) | WARNING | `[WARNING] key thermo of section [<s>]: thermo = <db> is ignored with CEA-file` | remove `thermo`, or drop `CEA-file` |
| `phase =` together with `thermo =`, `transport =` and/or `reactions =` | WARNING | `[WARNING] GPB: phase = <file>: keys ignored` | remove the keys, or use `reactions =` to select the databases |
| a database thermo record replaces a mechanism species record | INFO, WARNING above 1 kJ/mol at 298.15 K, ERROR with `strict-thermo = true` | `[INFO]/[WARNING] GPB: species <sp>: thermo from the database replaces the file record (dh298 ...)` (`dh<T>` when a record starts above 298.15 K) | check the record; leave out `thermo` (without `CEA-file`) or use `phase =` to keep the file records; `strict-thermo = true` to refuse |
| a falloff reaction of a form other than `falloff-Troe` and `falloff-Lindemann` (`falloff-SRI` in FFCM-1 and FFCM-2, `falloff-Tsang`, ...) or a `chemically-activated` reaction, in any phase (the refusal lives in the GPB writer only: KAnT and Cantera load the same yaml as it is) | ERROR | `[ERROR] GPB: phase <name>: <n> reactions have a form the chemistry tables cannot hold (they carry the Arrhenius, falloff-Troe and falloff-Lindemann forms only): <i> (<equation>; <type>), ...` | convert the reactions to Troe or Lindemann, or use the file in Cantera and KAnT only |
| explicit `orders` on a falloff reaction (Cantera 3.0 already refuses such a file when it loads it) | WARNING | `[WARNING] GPB: phase <name>: the explicit orders of <n> falloff reactions are not written (the chemistry tables carry orders for Arrhenius-type reactions only): <i> (<equation>), ...` | nothing is written for those reactions: the `Reaction orders` block of `chemistry-info.txt` lists Arrhenius-type reactions only |
| PLOG or multi-pressure Chebyshev reactions: the tables hold the rate at 1 atm only (single-pressure Chebyshev is accepted silently) | WARNING | `[WARNING] GPB: phase <name>: <n> pressure-dependent reactions (PLOG / multi-pressure Chebyshev) are tabulated at 1 atm only` | accept the 1 atm rates, or use a mechanism without pressure dependence |
| a species of the file without transport data: with `transport = cantera` it is refused; with `transport = CEA` it takes its CEApolynomials record (simplified law without one); without `transport` no transport table is written | ERROR / INFO | `[ERROR] key reactions of section [<s>]: <file>.yaml has <n> of <ns> species without transport data` / `[INFO] GPB: transport = CEA: <n> species of <file>.yaml carry no transport data` | add the Lennard-Jones records to the file, or use `transport = CEA` |
| a yaml phase without a transport model with `transport = cantera` or `phase =` (e.g. `TSR-Rich-39`) | ERROR | `[ERROR] key reactions|phase of section [<s>]: <file>.yaml declares no transport model for the phase` | add `transport: mixture-averaged` and the Lennard-Jones records to the file, or use `reactions =` with `transport = CEA` |
| a file Cantera cannot load, or no file of that name (the error names the database files the key may have meant: `phase` and `reactions` take the file name, not the phase name) | ERROR | `[ERROR] key reactions|phase of section [<s>]: <file>.yaml cannot be loaded by Cantera: <Cantera's line>` | fix the file, or write the file name suggested by the message |
| `transport = CEA` with a species absent from `CEApolynomials.yaml` | WARNING | `[WARNING] GPB: transport = CEA: no CEApolynomials record for species '<sp>'` | add the species to `database/transport/CEApolynomials.yaml`, or use `transport = cantera` |
| `transport =` with a value other than `cantera`, `CEA` or `constant` (the values are case-sensitive) | WARNING | `[WARNING] GPB: transport = <v> is not cantera, CEA or constant: simplified law applied for species '<sp>'` | write `cantera` or `CEA` |
| phase named `gas` | WARNING | `[WARNING] GPB: phase name 'gas' identifies no mechanism` | give the phase the mechanism's name in the yaml (FLINT selects the routine by that name) |

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