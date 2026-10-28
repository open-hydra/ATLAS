"""Check that ICB zones given by total conditions carry the static state of the solvers' inlet.

usage: python3 check_totals.py <bc.txt> <ic.tec of the mach run> [<ic.tec> ...]

bc.txt holds the supersonic inlet (BC 405) given by mach, p0 and T0: its record is mach, T, p.
Every cell of every IC file (one block of N2, ASCII Tecplot) must carry that T and p, and the
velocity of the first IC file: the zones reach the same state from T0 or T, by mach or by u, v, w.
The speed of the first one is mach times the speed of sound at T, gamma from the cp of thermo.dat
interpolated between its 1 K rows (the solvers' table lookup).
"""
import math
import os
import sys

R = 8314.46261815324 / 28.014   # N2, as phase.txt
TOL = 1e-12


def cp_at(T):
    rows = [line.split() for line in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'thermo.dat'))]
    cp = {int(float(r[0])): float(r[1]) for r in rows if len(r) == 5 and r[0][0].isdigit()}
    i = int(T)
    return cp[i] + (cp[i + 1] - cp[i]) * (T - i)


def inlet(path):
    lines = open(path).read().split('\n')
    for head, record in zip(lines, lines[1:]):
        if head.split()[-1:] == ['405']:
            values = [v.strip() for v in record.split(',')]
            return float(values[0]), float(values[1]), float(values[2])
    sys.exit(f'{path}: no BC 405 record')


def cells(path):
    lines = open(path).read().split('\n')
    names = lines[0].split('=', 1)[1].split()
    zone = lines[1]
    dims = [int(zone.split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    vals = [float(v) for line in lines[2:] for v in line.split()]
    nn = dims[0] * dims[1] * dims[2]
    nc = (dims[0] - 1) * (dims[1] - 1) * (dims[2] - 1)
    band = {n: vals[3 * nn + b * nc: 3 * nn + (b + 1) * nc] for b, n in enumerate(names[3:])}
    return [{'T': p / (R * rho), 'p': p, 'u': (u, v, w)}
            for rho, u, v, w, p in zip(band['rho1'], band['u'], band['v'], band['w'], band['p'])]


mach, T_in, p_in = inlet(sys.argv[1])
reference = cells(sys.argv[2])
cp = cp_at(T_in)
speed = math.sqrt(sum(c * c for c in reference[0]['u']))
worst = abs(speed / (mach * math.sqrt(cp / (cp - R) * R * T_in)) - 1)
print(f'speed of the mach run: {speed:.10f} m/s, mach a(T) - 1 = {worst:.1e}')
for path in sys.argv[2:]:
    dev = 0.0
    for cell, ref in zip(cells(path), reference):
        speed = math.sqrt(sum(c * c for c in ref['u']))
        dev = max(dev, abs(cell['T'] / T_in - 1), abs(cell['p'] / p_in - 1),
                  max(abs(a - b) for a, b in zip(cell['u'], ref['u'])) / speed)
    c = cells(path)[0]
    print(f'{path}: T = {c["T"]:.10f} K, p = {c["p"]:.8f} Pa, (u, v, w) = '
          f'({c["u"][0]:.8f}, {c["u"][1]:.8f}, {c["u"][2]:.8f}); max relative deviation {dev:.1e}')
    worst = max(worst, dev)
print(f'inlet (BC 405): T = {T_in:.10f} K, p = {p_in:.8f} Pa')
sys.exit(0 if worst < TOL else 1)
