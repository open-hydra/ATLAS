# ATLAS GPB Input Parameters


## GPB

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| input-file | input.ini |  | no | Input INI file consumed by GPB. |

## GPB-Phase*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| type | ideal-gas | ideal-gas,heavy-gas,condensed-dispersed,liquid-dispersed,solid-dispersed,solid,solid-bulk,real-fluid | no | Phase model selector for the current section. |
| modeling |  | lagrangian,eulerian | no | Dispersed phase treatment the solver will use; written on line 1 of <name>phase.txt as modeling=<value>. |
| name |  |  | no | Prefix for generated output files. |
| Tmin | 1 | >0 | no | Minimum tabulation temperature [K] (integer; the tables have a 1 K step). |
| Tmax | 5000 | >0 | no | Maximum tabulation temperature [K] (integer; the tables have a 1 K step). |

## GPB-IdealGas

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| phase |  |  | no | Existing Cantera phase file stem (without .yaml): the name of the database file, which may differ from the phase name inside it. |
| thermo |  | NASA7,NASA9,Burcat,custom | no | Source of the species thermodynamics: a database (NASA7, NASA9, Burcat) or custom (the IdealGasSpecies of custom.py). Burcat is not distributed with ATLAS: database/thermo/external/README.md. Without it, the species of a reactions file keep the thermo records of the file. |
| transport |  | CEA,cantera | no | Transport model source. |
| reactions |  |  | no | Reaction mechanism file stem (without .yaml). |
| strict-thermo | False | True,False | no | Refuse (instead of warning) when a database thermo record replaces a mechanism species record by more than 1 kJ/mol at 298.15 K. |
| inerts-mixing | False | True,False | no | Mix equilibrium species into a single mixture phase. |
| species |  |  | no | Manual inert species list. |
| add-species |  |  | no | Alternative key for manual inert species list. |
| mixture |  |  | no | Custom mixture composition string/dictionary. |
| mixture-name | mix |  | no | Output name for custom mixture. |
| cp |  |  | no | Constant-pressure specific heat array for fixed-gas species. |
| cv |  |  | no | Constant-volume specific heat array for fixed-gas species. |
| gamma |  |  | no | Specific-heat ratio array for fixed-gas species. |
| R |  |  | no | Specific gas constant array for fixed-gas species. |
| mw |  |  | no | Molecular weight array for fixed-gas species. |
| mil |  |  | no | Dynamic viscosity array for fixed-gas species. |
| kl |  |  | no | Thermal conductivity array for fixed-gas species. |
| Pr |  |  | no | Prandtl number array for fixed-gas species: gives the missing one of mil and kl, or with mil-law = sutherland the conductivity k = mu cp/Pr. |
| mil-law | constant | constant,sutherland | no | Viscosity law of the fixed-gas species: constant (mil) or sutherland, mu = mil-ref (T/T-ref)^1.5 (T-ref + S-mil)/(T + S-mil), with the conductivity from Pr (k = mu cp/Pr) or the constant kl. |
| mil-ref |  | >0 | no | mil-law = sutherland: viscosity at T-ref [Pa s], one per fixed-gas species. |
| T-ref |  | >0 | no | mil-law = sutherland: temperature of mil-ref [K], one per fixed-gas species. |
| S-mil |  | >0 | no | mil-law = sutherland: Sutherland temperature [K], one per fixed-gas species. |

## GPB-Equilibrium

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| CEA-file |  |  | no | CEA input file stem (.inp extension optional). |
| CEA-section | 1 | >=1 | no | Section index inside CEA output. |
| eq-pressure |  |  | no | Cantera equilibrium pressure as [value, unit]. |
| eq-fuel |  |  | no | Cantera equilibrium fuel composition entry. |
| eq-oxidizer |  |  | no | Cantera equilibrium oxidizer composition entry. |
| eq-of |  | >0 | no | Cantera equilibrium oxidizer-to-fuel ratio. |
| eq-fuel-T | 100.0 |  | no | Fuel inlet temperature for equilibrium setup [K]. |
| eq-oxidizer-T | 90.170 |  | no | Oxidizer inlet temperature for equilibrium setup [K]. |

## GPB-Condensed

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| thermo | NASA9 | NASA7,NASA9,Burcat,custom | no | Source of the material thermodynamics: a database (NASA7, NASA9, Burcat; NASA9 when both thermo and cp are absent) supplies every material it holds; a material it lacks takes the constant cp and rho of the section, and h0 when other materials come from the database. custom takes every material from the CondensedMaterial substances of custom.py (cp, rho, k and optionally the enthalpy and p_sat as functions of T). With cp and no thermo every material is constant. SP-database is the former name of custom. |
| material | ATLAS |  | no | Condensed-phase material names. |
| groups | 1 |  | no | Group index per condensed material. |
| h0 |  |  | no | Optional enthalpy at 298.15 K [J/kg], one per fixed-cp material; makes the Enthalpy column absolute (`h = cp*T + h0 - cp*298.15`, header Enthalpy_abs). |
| psat-vapour |  |  | no | Vapour species of the thermo database (thermo = NASA9 or Burcat), one per material, none to skip one: adds the columns Psat [Pa], Lv [J/kg], Mv [kg/kmol] and Cpv [J/(kg K)] to <name>properties.dat, from the liquid/vapour pair: `p_sat = 1e5*exp(-(g_vap - g_liq)/(R*T))`, `Lv = (h_vap - h_liq)/Mv`, `Cpv = cp_vap/Mv` (dispersed phases only). |
| psat-liquid |  |  | no | Liquid species paired with psat-vapour, one per material; default = the material name. |
| cp |  |  | no | Fixed specific heat values for condensed materials. |
| k |  |  | no | Fixed thermal conductivity values for condensed materials. |
| rho |  |  | no | Density values for condensed materials. |
| evaporation |  | d2-law,CEM,CEM-B,ASM,TC | no | Per-material override of the global evaporation model. |
| liquid-conduction |  | ITC,P2T | no | Per-material override of the liquid-side conduction model. |
| interface |  | VLE,LK | no | Per-material override of the interface model. |
| boiling |  | clamp,ZGR | no | Per-material override of the boiling branch. |
| combustion |  | Beckstead | no | Metal combustion model; presence switches this material to the metal track (mutually exclusive with evaporation and breakup). |
| solidification |  | on,off | no | Solidification of a molten particle with supercooling and recalescence, and melting of a solid particle at T-melt (IGLOO and ICE). |
| alpha-e |  |  | no | Langmuir-Knudsen evaporation accommodation coefficient (interface=LK). |
| k-liq |  |  | no | Liquid thermal conductivity [W/m/K] (required if liquid-conduction=P2T). |
| mu-liq |  |  | no | Liquid viscosity [Pa s] (liquid-conduction=P2T). |
| K-burn |  |  | no | Beckstead d^n burn-rate coefficient K at X-eff=1 [m^n-burn/s]; required > 0 with combustion=Beckstead. |
| n-burn |  |  | no | Beckstead burn-law diameter exponent (nominal 1.8, range 1.5-1.8). |
| X-eff |  |  | no | Effective oxidizer mole fraction C_O2 + 0.6 C_H2O + 0.22 C_CO2; weights K as X-eff (linear) [Beck05]. |
| beta-part |  |  | no | Heat-partition fraction of q-comb released to the particle (weakly constrained; see theory/combustion). |
| xi-cap |  |  | no | Oxide-cap mass fraction retained on the burning particle. |
| T-ign |  |  | no | Ignition temperature [K]; the particle is inert (mdot=0) below it. |
| q-comb |  |  | no | Heat of combustion per unit Al mass [J/kg]; particle heating term = beta-part*q-comb*abs(mdot). |
| T-melt |  |  | no | Melt temperature [K] (default: alumina). |
| h-fus |  |  | no | Heat of fusion [J/kg] (solidification). |
| T-nuc |  |  | no | Nucleation (supercooling) temperature [K]; absent or 0 = 0.8*T-melt. |
| cp-solid |  |  | no | Solid-phase specific heat [J/kg/K] (solidification). |

## GPB-RealFluid

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| fluid |  |  | yes | Fluid name accepted by selected real-fluid model. |
| pmin |  | >0 | yes | Minimum pressure bound [Pa]. |
| pmax |  | >0 | yes | Maximum pressure bound [Pa]. |
| Tmin |  | >0 | yes | Minimum temperature bound [K]. |
| Tmax |  | >0 | yes | Maximum temperature bound [K]. |
| NP | 200 | >=2 | no | Number of pressure grid points. |
| NH | 200 | >=2 | no | Number of enthalpy grid points. |
| thermo | coolprop | coolprop,redlich-kwong,peng-robinson,custom,constant | no | Source of the fluid thermodynamics: CoolProp, a Cantera cubic equation of state (redlich-kwong, peng-robinson), custom (the RealFluid of custom.py named by fluid) or constant (the properties cp, rho, mu, k given in the section; fluid is then only a label). model is the former name of thermo. |
| cp |  | >0 | no | thermo = constant: specific heat [J/kg/K]. |
| rho |  | >0 | no | thermo = constant: density [kg/m3]. |
| mu |  | >0 | no | thermo = constant: dynamic viscosity [Pa s]. |
| k |  | >0 | no | thermo = constant: thermal conductivity [W/m/K]. |
| a | 500 | >0 | no | thermo = constant: speed of sound [m/s]; without it 500 m/s and a WARNING. |

## GPB-Pyrolysis*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| name |  |  | yes | Name of the pyrolysis-gas table (one word, at most 64 characters): the key pyrolysis-gas of a BCB gsi section (BC 506) names it. |
| phase |  |  | no | Name of the [GPB-Phase*] ideal-gas phase whose species the table follows (optional when the deck builds one ideal-gas phase); the product is <phase>-pyrolysis.dat, one table per section. |
| elements |  |  | yes | Elements of the pyrolysis-gas makeup (symbols, case-sensitive: C H O). |
| massf |  |  | yes | Mass fraction of each element, in the order of elements, each in (0, 1]; the sum must be 1 (within 1e-3 renormalised with a WARNING). |
| p |  | >0 | no | Pressure levels [Pa], strictly ascending; or p-min, p-max and p-n. |
| p-min |  | >0 | no | Lowest pressure level [Pa] (with p-max and p-n). |
| p-max |  | >0 | no | Highest pressure level [Pa] (with p-min and p-n). |
| p-n |  | >=1 | no | Number of pressure levels from p-min to p-max (1: one level, p-max = p-min). |
| p-spacing | linear | linear,log | no | Spacing of the p-n levels. |
| T |  |  | yes | Temperature grid [K]: T-min T-max T-step, (T-max - T-min)/T-step an integer (at least two levels). |
| treatment | gas-only | gas-only,strip | no | gas-only: equilibrium of the gas species alone, graphite excluded (the elements of every row equal the makeup); strip: graphite allowed, removed, the gas renormalised (the thesis and RFRAR tables). |
