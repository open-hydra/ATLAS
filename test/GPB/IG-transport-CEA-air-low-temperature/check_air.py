#!/usr/bin/env python3
"""Rows of the air zone of transport.dat at 100 K and 37 K against the dilute-gas air of Lemmon and Jacobsen, Int. J. Thermophys. 25,
21 (2004), Eq. (2) and (5) with their Tables I, II and IV for air.

Bounds: the deviation that the CEA tables of GPB had from that air when they were made, rounded to 0.1 %, plus the uncertainty that
Lemmon and Jacobsen declare: viscosity 1.0 % at 100 K (+0.01 %, and 1 % in the dilute gas for air) and 5.3 % at 37 K (-0.31 %, and
5 % for air overall: there their air equations are extended below their data, which start at 80 K); conductivity 3.9 % at 100 K
(-1.85 %, and 2 % in the dilute gas). At 37 K the conductivity of their air is extended below its data (from 87.5 K) and is not compared.
Usage: check_air.py <transport.dat> <zone>   (Python 3, no other package); exit status 1 on any failure.
"""
import math
import sys

B = (0.431, -0.4623, 0.08406, 0.005341, -0.00331)                  # Table II
M, EK, SIGMA, TC = 28.9586, 103.3, 0.360, 132.6312                 # Table I, air
N1, N2, T2, N3, T3 = 1.308, 1.405, -1.1, -1.036, -0.3              # Table IV, air


def eta0(T):
    x = math.log(T / EK)
    return 0.0266958 * math.sqrt(M * T) / (SIGMA ** 2 * math.exp(sum(b * x ** i for i, b in enumerate(B)))) * 1e-6   # Pa s


def lambda0(T):
    tau = TC / T
    return (N1 * eta0(T) * 1e6 + N2 * tau ** T2 + N3 * tau ** T3) * 1e-3                                       # W/(m K)


rows, zone = {}, None
for line in open(sys.argv[1]):
    if line.startswith('ZONE'):
        zone = line.split('"')[1]
    elif zone == sys.argv[2]:
        p = line.split()
        try:
            rows[float(p[0])] = (float(p[1]), float(p[2]))
        except (ValueError, IndexError):
            pass

failures = 0
for T, j, bound, ref, what in ((100.0, 0, 1.0, eta0, 'viscosity'), (37.0, 0, 5.3, eta0, 'viscosity'),
                               (100.0, 1, 3.9, lambda0, 'conductivity')):
    if T not in rows:
        print(f'FAIL no row at {T:g} K in zone {sys.argv[2]} of {sys.argv[1]}')
        failures += 1
        continue
    dev = 100.0 * (rows[T][j] / ref(T) - 1.0)
    ok = abs(dev) <= bound
    failures += not ok
    print(f"{'PASS' if ok else 'FAIL'} {what} of {sys.argv[2]} at {T:g} K: {rows[T][j]:.6e}, {dev:+.2f} % from Lemmon and Jacobsen "
          f"(bound {bound} %)")
sys.exit(1 if failures else 0)
