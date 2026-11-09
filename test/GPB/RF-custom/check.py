"""RF-custom: air-thermo.dat and air-transport.dat against the closed form of PerfectAir (custom.py), written here again.
The tables are written one value per line, variable by variable, p running fastest; h and s are shifted to zero at
(Tmin, pmin). usage: check.py <air-thermo.dat> <air-transport.dat> <speed of sound: formula|500>"""
import sys

import numpy as np

R, cp, mu, k, T_ref, p_ref = 287.0, 1005.0, 1.8e-5, 0.026, 298.15, 1.0e5
pmin, pmax, Tmin, Tmax, NP, NH = 1.0e5, 1.0e6, 300.0, 900.0, 5, 6


def read(path, nvar):
    lines = open(path).read().splitlines()
    values = np.array([float(x) for x in lines[3:] if x.strip()])
    assert values.size == nvar * NP * NH, f"{path}: {values.size} values, expected {nvar * NP * NH}"
    return values.reshape(nvar, NH * NP)


entropy = lambda T, p: cp * np.log(T / T_ref) - R * np.log(p / p_ref)
p = np.linspace(pmin, pmax, NP)
h_abs = np.linspace(cp * Tmin, cp * Tmax, NH)
P, H = np.meshgrid(p, h_abs)                       # H[j, i]: j runs over h, i over p, p fastest when flattened
P, H = P.ravel(), H.ravel()
T = H / cp
rho = P / (R * T)
gamma = cp / (cp - R)
a = np.sqrt(gamma * R * T) if sys.argv[3] == "formula" else np.full_like(T, 500.0)
shift_h = cp * Tmin
expected_thermo = [P, H - shift_h, rho, T, -rho / T, -rho / (cp * T), np.full_like(T, cp),
                   entropy(T, P) - entropy(Tmin, pmin), 1.0 / (R * T), a]
expected_transport = [P, H - shift_h, np.full_like(T, mu), np.full_like(T, k)]
for path, nvar, expected, names in ((sys.argv[1], 10, expected_thermo,
                                     "p h rho T drho/dT drho/dh cp s drho/dp a".split()),
                                    (sys.argv[2], 4, expected_transport, "p h mu k".split())):
    got = read(path, nvar)
    for g, e, name in zip(got, expected, names):
        err = np.max(np.abs(g - e) / np.maximum(np.abs(e), 1e-30)) if name not in ("h", "s") else \
            np.max(np.abs(g - e)) / max(np.max(np.abs(e)), 1.0)
        if err > 1e-9:
            sys.exit(f"[FAIL] {path}: {name}: error {err:.3g}")
print("[ok] air-thermo.dat and air-transport.dat match the closed form")
