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
| particle-mechanism |  |  | no | Reaction file of the burning materials of a dispersed phase: <stem>.yaml of the case directory, else of database/particle-combustion/. A reaction consumes one material: into gas species only (the combustion record of <name>products.txt), or into gas species and the one condensed product that carried names (the carry record); a reaction that consumes a carried material gives its release record. Every gas species of a reaction is a species of the gas phase. hydra-MI2 reads the file; the burning rate stays the solver model named by combustion. A material with combustion and no reaction stops GPB. |
| cp |  |  | no | Fixed specific heat values for condensed materials. |
| k |  |  | no | Fixed thermal conductivity values for condensed materials. |
| rho |  |  | no | Density values for condensed materials. |
| evaporation |  | d2-law,CEM,CEM-B,ASM,TC | no | Per-material override of the global evaporation model. |
| liquid-conduction |  | ITC,P2T | no | Per-material override of the liquid-side conduction model. |
| interface |  | VLE,LK | no | Per-material override of the interface model. |
| boiling |  | clamp,ZGR | no | Per-material override of the boiling branch. |
| combustion |  | Beckstead,direct,none | no | Burning model of the material: Beckstead (the d^n law) or direct (the d2 law of a drop held at its burning temperature), mutually exclusive with evaporation and breakup; none for a material that does not burn (it overrides the default of the solver section). Absent: no word is written and the solver section decides. A burning material needs its reaction (particle-mechanism). |
| solidification |  | on,off | no | Solidification of a molten particle with supercooling and recalescence, and melting of a solid particle at T-melt (IGLOO and ICE). |
| alpha-e |  |  | no | Langmuir-Knudsen evaporation accommodation coefficient (interface=LK). |
| k-liq |  |  | no | Liquid thermal conductivity [W/m/K] (required if liquid-conduction=P2T). |
| mu-liq |  |  | no | Liquid viscosity [Pa s] (liquid-conduction=P2T). |
| K-burn |  |  | no | Beckstead d^n burn-rate coefficient K at X-eff=1 [m^n-burn/s]; required > 0 with combustion=Beckstead. |
| n-burn |  |  | no | Beckstead burn-law diameter exponent (nominal 1.8, range 1.5-1.8). |
| X-eff |  |  | no | Effective oxidizer mole fraction C_O2 + 0.6 C_H2O + 0.22 C_CO2; weights K as X-eff (linear) [Beck05]. |
| beta-part |  |  | no | Heat-partition fraction of q-comb released to the particle (weakly constrained; see theory/combustion). |
| carry |  | constant,Gallier21 | no | The share of the product a burning drop keeps: constant (share) or the deposition law of Gallier et al. 2021 (IGLOO). Its constants go to the carry row of <name>models.txt, with yield, the kg of the carried material formed per kg burnt, which GPB takes from the carry reaction of particle-mechanism. |
| share |  |  | no | carry = constant: the part of the product formed that the burning drop keeps, [0, 1] (IGLOO). |
| carried |  |  | no | The material a burning material carries: the name of a material of this phase with 0 groups, none for a material that carries nothing. Its line carries no key of the burning model; the carry reaction of particle-mechanism makes it. |
| carried-0 |  |  | no | Carried mass fraction of the injected particle, [0, 1); needs a carried material (IGLOO). |
| residue |  | on,off | no | on: at burnout the carried mass becomes a parcel of the carried material; off: it is handed to the gas, which needs the release reaction of the carried material in particle-mechanism (IGLOO). |
| d-residue |  |  | no | Diameter [m] of the residue parcels of a carried material, the mass flow kept; 0: one residue per droplet (IGLOO). |
| T-ign |  |  | no | Ignition temperature [K]; the particle is inert (mdot=0) below it. |
| q-comb |  |  | no | Heat of combustion per unit mass of the material [J/kg], as the burning model uses it: Beckstead heats the particle by beta-part*q-comb*abs(mdot), direct takes it in its transfer number. The heat the gas receives is the reaction heat of particle-mechanism, not this key. |
| d-stop |  |  | no | Diameter [m] of the residue a burning drop leaves: below it the drop no longer burns and stays, inert (both models, ICE and IGLOO). Absent or 0: the drop burns out. |
| d-burnout |  |  | no | Diameter [m] at which a burning drop without residue is removed and handed whole to the gas (ICE and IGLOO). Absent or 0: the bound built into the solvers, a drop mass of 1e-20 kg. |
| d-gen |  |  | no | Diameter [m] of the generated drops a burning material makes: required when its reaction makes a condensed product that is a material of an eulerian phase (the generated mass, born in that ICE family), refused otherwise (both models, ICE and IGLOO). |
| T-burn |  |  | no | Burning temperature [K] of combustion = direct: the drop burns at it and is held at it. Absent: the boiling temperature of the solver section. The latent heat of the model is the Lv column of the properties table (psat-vapour), evaluated at this temperature. |
| T-melt |  |  | no | Melt temperature [K] (default: alumina). |
| h-fus |  |  | no | Heat of fusion [J/kg] (solidification). |
| T-nuc |  |  | no | Nucleation (supercooling) temperature [K]; absent or 0 = 0.8*T-melt. |
| cp-solid |  |  | no | Solid-phase specific heat [J/kg/K] (solidification). |
| breakup |  | Pilch-Erdman,Reitz-Diawakar,Reitz-KHRT,TAB,ETAB,NoBreakup | no | Breakup model of the material (IGLOO); its constants go to <name>models.txt, each optional (absent: the default given below). NoBreakup for a material that does not break (it overrides the default of the solver section). Absent: no word is written and the solver section decides. ICE has no breakup model: it ignores the word and a breakup row with a warning; give it to a phase IGLOO solves. |
| Cd |  |  | no | Pilch-Erdman drag constant (default 1.0). |
| B |  |  | no | Pilch-Erdman breakup constant (default 0.116). |
| WeBag |  |  | no | Reitz-Diawakar bag-breakup Weber threshold (default 6). |
| Cb |  |  | no | Reitz-Diawakar bag time constant (default pi). |
| Cstrip |  |  | no | Reitz-Diawakar stripping Weber threshold constant (default 0.5). |
| Cs |  |  | no | Reitz-Diawakar stripping time constant (default 20; 8 Ranger-Nicholls, sqrt(3) O'Rourke-Amsden). |
| B0 |  |  | no | Reitz-KHRT KH child-size constant (default 0.61). |
| B1 |  |  | no | Reitz-KHRT KH breakup-time constant (default 20). |
| Ctau |  |  | no | Reitz-KHRT RT time constant (default 1). |
| CRT |  |  | no | Reitz-KHRT RT wavelength constant (default 0.1). |
| mShedLim |  |  | no | Reitz-KHRT shed-mass fraction limit (default 0.03). |
| WeLimit |  |  | no | Reitz-KHRT Weber limit (default 6). |
| Comega |  |  | no | TAB and ETAB oscillation frequency constant (default 8). |
| Cmu |  |  | no | TAB and ETAB oscillation damping constant (default 5). |
| WeCrit |  |  | no | TAB and ETAB critical Weber number (default 6; IGLOO doubles it). |
| method |  | 1,2 | no | TAB product-size law: 1 chi-square, 2 Rosin-Rammler (default 2). |
| n |  |  | no | TAB Rosin-Rammler spread parameter of method 2 (default 3.5). |
| k1 |  |  | no | ETAB bag-regime rate constant (default 0.2222). |
| k2 |  |  | no | ETAB stripping-regime rate constant (default 0.2222). |
| WeTrans |  |  | no | ETAB bag-to-stripping transition Weber number (default 80). |

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
