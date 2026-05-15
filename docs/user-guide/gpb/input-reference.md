# ATLAS GPB Input Parameters


## GPB

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| input-file | input.ini |  | no | Input INI file consumed by GPB. |

## GPB-Phase*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| type | ideal-gas | ideal-gas,heavy-gas,condensed-dispersed,solid,real-fluid | no | Phase model selector for the current section. |
| name |  |  | no | Prefix for generated output files. |
| Tmin | 1 | >0 | no | Minimum tabulation temperature [K]. |
| Tmax | 5000 | >0 | no | Maximum tabulation temperature [K]. |

## GPB-IdealGas

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| phase |  |  | no | Existing Cantera phase file stem (without .yaml). |
| thermo |  | NASA7,NASA9,Burcat | no | Thermodynamic species database selector. |
| transport |  | CEA,cantera | no | Transport model source. |
| reactions |  |  | no | Reaction mechanism file stem (without .yaml). |
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
| Pr |  |  | no | Prandtl number array for fixed-gas species. |

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
| thermo | NASA9 | NASA7,NASA9,Burcat,SP-database | no | Condensed-phase thermodynamic model selector. |
| material | ATLAS |  | no | Condensed-phase material names. |
| groups | 1 |  | no | Group index per condensed material. |
| cp |  |  | no | Fixed specific heat values for condensed materials. |
| k |  |  | no | Fixed thermal conductivity values for condensed materials. |
| rho |  |  | no | Density values for condensed materials. |

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
| model | coolprop | coolprop,redlich-kwong,peng-robinson | no | Equation-of-state model used for table generation. |
