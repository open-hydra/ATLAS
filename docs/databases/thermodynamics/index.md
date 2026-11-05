# Thermodynamics Databases

ATLAS bundles four thermodynamic database files in `database/thermo/` (`nasa9.yaml`, `burcat.yaml`,
`peng-robinson.yaml`, `redlich-kwong.yaml`) and one Python module (`sp_custom.py`), covering ideal-gas species from
cryogenic to plasma temperatures and real-fluid equations of state for high-pressure propellants. GPB selects
them with `thermo` (ideal gas, condensed and solid phases) and `model` (real fluid).

| `thermo` / `model` | File | Format | Phase | Temperature range | Source |
|---|---|---|---|---|---|
| `NASA9` | `nasa9.yaml` | NASA9 polynomials | all | 200 – 20 000 K | NASA Glenn Research Center |
| `Burcat` | `burcat.yaml` | NASA7 polynomials | all | 200 – 6000 K | Burcat / Goos / Ruscic (ATcT) |
| `NASA7` | `nasa_gas.yaml` of Cantera | NASA7 polynomials | gas | 200 – 6000 K | 748 gas species of the NASA 7-coefficient database, shipped with Cantera (not a file of ATLAS) |
| `peng-robinson`, `redlich-kwong` | `peng-robinson.yaml`, `redlich-kwong.yaml` | cubic EOS | real fluid | — | critical constants, acentric factor |
| `coolprop` | CoolProp library | multiparameter EOS | real fluid | per fluid | CoolProp, 100+ fluids |
| `SP-database` | `sp_custom.py` | Python | solid | per material | see [Custom](custom.md) |

---
