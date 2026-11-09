"""Case-directory custom.py of the test CP-custom: a liquid with a saturation pressure, a wax with an absolute enthalpy,
and a Graphite that replaces the one of database/thermo/custom.py."""
import numpy as np

from custom_classes import CondensedMaterial

Foam = CondensedMaterial(
    "Foam",
    cp=lambda T: 1000.0 + 0.5 * T,                            # [J/kg/K]
    rho=lambda T: 900.0 - 0.4 * (T - 300.0),                  # [kg/m3]
    psat=lambda T: 1.0e5 * np.exp(10.0 * (1.0 - 350.0 / T)),  # [Pa]
)

Wax = CondensedMaterial(
    "Wax",
    cp=2500.0,
    rho=800.0,
    h=lambda T: -2.0e5 + 2500.0 * (T - 298.15),               # -2.0e5 J/kg at 298.15 K, on the formation scale
    absolute_enthalpy=True,
)

Graphite = CondensedMaterial("Graphite", cp=710.0, rho=1700.0)   # replaces the Graphite of database/thermo/custom.py
