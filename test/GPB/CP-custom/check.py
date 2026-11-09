"""CP-custom: <name>properties.dat of a dispersed phase against the formulas of custom.py, written here again.
usage: check.py <properties.dat> <header word> <material> ..."""
import re
import sys

import numpy as np

T0 = 300.0                                             # Tmin of the deck: the relative enthalpy is zero there
FORMULAS = {                                           # material -> (cp, rho, h, psat or None) as functions of T
    "Foam": (lambda T: 1000 + 0.5 * T, lambda T: 900 - 0.4 * (T - 300), lambda T: 1000 * (T - T0) + 0.25 * (T**2 - T0**2),
             lambda T: 1e5 * np.exp(10 * (1 - 350 / T))),
    "Graphite": (lambda T: 710 + 0 * T, lambda T: 1700 + 0 * T, lambda T: 710 * (T - T0), None),
    "Wax": (lambda T: 2500 + 0 * T, lambda T: 800 + 0 * T, lambda T: -2e5 + 2500 * (T - 298.15), None),
}

path, header_word, materials = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(path).read()
variables = re.search(r"VARIABLES = (.*)", text).group(1)
if f'"{header_word}"' not in variables:
    sys.exit(f"[FAIL] {path}: header has {variables}, expected {header_word}")
zones = re.split(r'ZONE T="([^"]+)"\n', text)[1:]
found = dict(zip(zones[::2], zones[1::2]))
if list(found) != materials:
    sys.exit(f"[FAIL] {path}: zones {list(found)}, expected {materials}")
for name in materials:
    rows = np.array([[float(x) for x in line.split()] for line in found[name].splitlines()[1:] if line.strip()])
    T = rows[:, 0]
    cp, rho, h, psat = FORMULAS[name]
    expected = [cp(T), rho(T), h(T)] + ([psat(T)] if psat else [])
    for col, e in enumerate(expected, start=1):
        tol = 1e-6 if col == 4 else 1e-9               # Psat is written with 7 significant digits (%.6e)
        err = np.max(np.abs(rows[:, col] - e) / np.maximum(np.abs(e), 1.0))
        if err > tol:
            sys.exit(f"[FAIL] {name} column {col}: relative error {err:.3g}")
    if psat is None and "Psat" in variables and np.any(rows[:, 4] != 0):
        sys.exit(f"[FAIL] {name}: Psat should be zero")
print(f"[ok] {path}: {', '.join(materials)} match the formulas")
