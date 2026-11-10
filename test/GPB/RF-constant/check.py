"""RF-constant: lox-thermo.dat and lox-transport.dat of `thermo = constant` against the constants of input.ini: density,
cp, viscosity, conductivity and speed of sound everywhere, no derivative of the density, T = Tmin + h/cp and
s = cp ln(T/Tmin) (h and s are shifted to zero at (Tmin, pmin)).
usage: check.py <lox-thermo.dat> <lox-transport.dat> <speed of sound>"""
import sys

import numpy as np

cp, rho, mu, k = 1700.0, 1140.0, 1.9e-4, 0.15
pmin, pmax, Tmin, Tmax, NP, NH = 1.0e6, 5.0e6, 90.0, 150.0, 5, 6


def read(path, nvar):
    lines = open(path).read().splitlines()
    values = np.array([float(x) for x in lines[3:] if x.strip()])
    assert values.size == nvar * NP * NH, f"{path}: {values.size} values, expected {nvar * NP * NH}"
    return values.reshape(nvar, NH * NP)


p = np.linspace(pmin, pmax, NP)
h = np.linspace(0.0, cp * (Tmax - Tmin), NH)
P, H = np.meshgrid(p, h)                          # p runs fastest when flattened
P, H = P.ravel(), H.ravel()
T = Tmin + H / cp
one = np.ones_like(T)
a = float(sys.argv[3]) * one
expected_thermo = [P, H, rho * one, T, 0 * one, 0 * one, cp * one, cp * np.log(T / Tmin), 0 * one, a]
expected_transport = [P, H, mu * one, k * one]
for path, nvar, expected, names in ((sys.argv[1], 10, expected_thermo,
                                     "p h rho T drho/dT drho/dh cp s drho/dp a".split()),
                                    (sys.argv[2], 4, expected_transport, "p h mu k".split())):
    got = read(path, nvar)
    for g, e, name in zip(got, expected, names):
        err = np.max(np.abs(g - e)) / max(np.max(np.abs(e)), 1e-30)
        if err > 1e-9:
            sys.exit(f"[FAIL] {path}: {name}: error {err:.3g}")
print("[ok] lox-thermo.dat and lox-transport.dat match the constants")
