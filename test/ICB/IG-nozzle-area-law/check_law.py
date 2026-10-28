"""Check the field of ICB's nozzle law on the converging-diverging nozzle of mesh.tec against the
quasi-1-D isentropic law, solved here independently.

usage: python3 check_law.py <ic.tec> <mesh.tec> dx|sx <plenum rows: first-last | none>

Every row of cells i is a cross-section of area A_i = pi |r_ext^2 - r_int^2|, r_int and r_ext the
distances from the x axis of its walls j = 1 and j = J (mid-row, on the first node plane of k), as ICB
takes them; the throat is the smallest. The plenum rows hold p0 and T0 at rest. Every other row holds
the Mach number of A_i / A_throat: exactly 1 at the throat, subsonic upstream of it along the flow
(towards +x with dx, -x with sx), supersonic downstream; p = p0 (1 + d M^2)^(-gamma/(gamma - 1)),
T = T0 / (1 + d M^2), |u| = M sqrt(gamma R T), the x component along the flow. The gas is O2 0.25,
N2 0.75 (H2 1e-20) of constant cp (thermo.dat): gamma = cp / (cp - R).
"""
import math
import sys

P0, T0 = 5.0e5, 450.0
RUNI = 8314.46261815324
Y = {'H2': 1e-20, 'O2': 0.25, 'N2': 0.75}
W = {'H2': 2.016, 'O2': 31.998, 'N2': 28.014}
CP = {'H2': 14300.0, 'O2': 918.0, 'N2': 1040.0}
R = sum(RUNI * Y[s] / W[s] for s in Y)
CP_MIX = sum(Y[s] * CP[s] for s in Y)
GAMMA = CP_MIX / (CP_MIX - R)
D = 0.5 * (GAMMA - 1.0)


def numbers(path):
    lines = open(path).read().split('\n')
    head = [line for line in lines if 'ZONE' in line.upper()][0]
    dims = [int(head.upper().split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    start = lines.index(head) + 1
    return dims, [float(v) for line in lines[start:] for v in line.split()]


def areas(mesh):
    (ni, nj, nk), vals = numbers(mesh)
    nn = ni * nj * nk
    y, z = vals[nn:2 * nn], vals[2 * nn:3 * nn]

    def radius(i, j):          # mid-row on the node plane k = 0
        a, b = i + ni * j, i + 1 + ni * j
        return math.hypot(0.5 * (y[a] + y[b]), 0.5 * (z[a] + z[b]))

    return [math.pi * abs(radius(i, nj - 1) ** 2 - radius(i, 0) ** 2) for i in range(ni - 1)]


def area_ratio(m):
    return ((1.0 + D * m * m) / (0.5 * (GAMMA + 1.0))) ** ((GAMMA + 1.0) / (4.0 * D)) / m


def mach(ratio, supersonic):
    if ratio <= 1.0:
        return 1.0
    lo, hi = (1.0, 2.0) if supersonic else (1e-12, 1.0)
    while supersonic and area_ratio(hi) < ratio:
        lo, hi = hi, 2.0 * hi
    for _ in range(200):              # bisection to the last bit
        mid = 0.5 * (lo + hi)
        if mid in (lo, hi):
            break
        if (area_ratio(mid) > ratio) != supersonic:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


path, mesh, direction, plenum = sys.argv[1:5]
(ni, nj, nk), vals = numbers(path)
nn, nc = ni * nj * nk, (ni - 1) * (nj - 1) * (nk - 1)
names = open(path).read().split('\n')[0].split('=', 1)[1].split()
bands = {n: vals[3 * nn + b * nc: 3 * nn + (b + 1) * nc] for b, n in enumerate(names[3:])}
A = areas(mesh)
throat = min(range(len(A)), key=A.__getitem__)
rows = set() if plenum == 'none' else set(range(int(plenum.split('-')[0]) - 1, int(plenum.split('-')[1])))
sign = 1.0 if direction == 'dx' else -1.0

worst, worst_throat, bad = 0.0, 0.0, []
for c in range(nc):
    i = c % (ni - 1)
    rho = [bands[f'rho{s}'][c] for s in (1, 2, 3)]
    p, u, v, w = (bands[n][c] for n in 'puvw')
    T = p / (RUNI * sum(r / W[s] for r, s in zip(rho, ('H2', 'O2', 'N2'))))
    speed = math.sqrt(u * u + v * v + w * w)
    if i in rows:
        dev = max(abs(p / P0 - 1.0), abs(T / T0 - 1.0), speed)
    else:
        supersonic = sign * (i - throat) > 0
        M = mach(A[i] / A[throat], supersonic)
        factor = 1.0 + D * M * M
        dev = max(abs(p / (P0 * factor ** (-GAMMA / (GAMMA - 1.0))) - 1.0), abs(T / (T0 / factor) - 1.0),
                  abs(speed / (M * math.sqrt(GAMMA * R * T0 / factor)) - 1.0))
        if not sign * u > 0.0:
            bad.append((i + 1, 'u along the flow', u))
        if i == throat:
            worst_throat = max(worst_throat, dev)
    worst = max(worst, dev)
    if dev > 1e-11:
        bad.append((i + 1, 'deviation', dev))
law = [i + 1 for i in range(ni - 1) if i not in rows]
print(f'{direction}: {nc} cells, plenum rows {sorted(r + 1 for r in rows) or "none"}, law rows {law or "none"}, '
      f'throat row {throat + 1}; max relative deviation {worst:.1e} (throat {worst_throat:.1e})')
if bad:
    print('  wrong:', bad[:4])
sys.exit(1 if bad or worst_throat > 1e-12 else 0)
