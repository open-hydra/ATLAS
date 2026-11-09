"""Case-directory custom.py: N2 and O2 (in the order of the database file) with the NASA 7-coefficient polynomials of
Cantera's nasa_gas.yaml, so that `thermo = custom` can be compared with `thermo = NASA7` for the same species."""
from custom_classes import IdealGasSpecies

N2 = IdealGasSpecies(
    "N2",
    composition={'N': 2},
    nasa7={"Tmin": 200.0, "Tmid": 1000.0, "Tmax": 6000.0,
           "low": [3.53100528, -0.000123660987, -5.02999437e-07, 2.43530612e-09, -1.40881235e-12, -1046.97628, 2.96747468],
           "high": [2.95257626, 0.00139690057, -4.92631691e-07, 7.86010367e-11, -4.60755321e-15, -923.948645, 5.87189252]},
)

O2 = IdealGasSpecies(
    "O2",
    composition={'O': 2},
    nasa7={"Tmin": 200.0, "Tmid": 1000.0, "Tmax": 6000.0,
           "low": [3.78245636, -0.00299673415, 9.847302e-06, -9.68129508e-09, 3.24372836e-12, -1063.94356, 3.65767573],
           "high": [3.66096083, 0.000656365523, -1.41149485e-07, 2.05797658e-11, -1.29913248e-15, -1215.97725, 3.41536184]},
)
