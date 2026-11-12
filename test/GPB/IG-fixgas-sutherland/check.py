"""IG-fixgas-sutherland: gasS-transport.dat of mil-law = sutherland against the law of input.ini, row by row: the
viscosity mu = mil-ref (T/T-ref)^1.5 (T-ref + S-mil)/(T + S-mil) and the conductivity mu cp/Pr (or the constant kl),
both printed with 12 decimals, so that a row may differ from the formula by half a unit of the last decimal.
usage: check.py <gasS-transport.dat> <Pr|kl>"""
import sys

import numpy as np

species = ['airS', 'heS']
cp = [1070.0, 5193.0]
mil_ref, T_ref, S_mil = [1.716e-5, 1.87e-5], [273.15, 273.0], [110.4, 79.4]
Pr, kl = [0.72, 0.67], [0.026, 0.15]
Tmin, Tmax = 1, 5000
TOL = 0.5e-12 + 1e-15   # half a unit of the 12th decimal, plus the read error of a value below 1 (2**-53)

lines = open(sys.argv[1]).read().splitlines()
assert lines[1] == 'VARIABLES = "Temperature", "Viscosity", "Conductivity"', lines[1]
nT = Tmax - Tmin + 1
T = np.arange(Tmin, Tmax + 1, dtype=float)
for i, name in enumerate(species):
    head = 2 + i * (nT + 2)
    if lines[head] != f'ZONE T="{name}"' or lines[head + 1] != f'I={nT}, F=POINT':
        sys.exit(f"[FAIL] {sys.argv[1]}: zone {i + 1} is not {name} with {nT} rows: {lines[head:head + 2]}")
    rows = np.array([[float(x) for x in l.split()] for l in lines[head + 2:head + 2 + nT]])
    if rows.shape != (nT, 3) or np.any(rows[:, 0] != T):
        sys.exit(f"[FAIL] {sys.argv[1]}: {name}: the rows are not T = {Tmin} .. {Tmax} K with a 1 K step")
    mu = mil_ref[i] * (T / T_ref[i]) ** 1.5 * (T_ref[i] + S_mil[i]) / (T + S_mil[i])
    k = mu * cp[i] / Pr[i] if sys.argv[2] == 'Pr' else kl[i] + 0 * T
    for col, exact, what in ((1, mu, 'viscosity'), (2, k, 'conductivity')):
        err = np.max(np.abs(rows[:, col] - exact))
        if not err <= TOL:
            sys.exit(f"[FAIL] {sys.argv[1]}: {name}: {what} off the law by {err:.3e} (allowed {TOL:.3e})")
print(f"[ok] {sys.argv[1]}: viscosity and conductivity ({sys.argv[2]}) of {', '.join(species)} on the law")
