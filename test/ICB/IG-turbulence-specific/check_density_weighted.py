"""Check the turbulence bands of an ICB IC file (ASCII Tecplot, one 2D block).

usage: python3 check_density_weighted.py <ic.tec> <band>=<value>[*rho] ...

<band>=<value>*rho: a specific key, written times the cell density (sum of the partial
densities); <band>=<value>: a density-weighted key, written as given.
"""
import re
import sys

path, specs = sys.argv[1], sys.argv[2:]
lines = open(path).read().split('\n')
names = lines[0].split('=', 1)[1].replace('"', ' ').split()
zone = lines[1]
I = int(zone.split('I=')[1].split(',')[0]); J = int(zone.split('J=')[1].split(',')[0])
vals = [float(v) for line in lines[2:] for v in line.split()]
nn, nc = I * J, (I - 1) * (J - 1)
ncoord = 2
bands = {n: vals[ncoord * nn + b * nc: ncoord * nn + (b + 1) * nc] for b, n in enumerate(names[ncoord:])}
rho = [sum(bands[n][c] for n in bands if re.fullmatch(r'rho\d+', n)) for c in range(nc)]
worst = 0.0
for spec in specs:
    band, value = spec.split('=')
    weighted = value.endswith('*rho')
    v = float(value[:-4] if weighted else value)
    if band not in bands:
        sys.exit(f'band {band} missing (bands: {" ".join(names[ncoord:])})')
    dev = max(abs(bands[band][c] / (v * (rho[c] if weighted else 1.0)) - 1) for c in range(nc))
    print(f'{band}: {bands[band][0]:.6e} (rho {rho[0]:.6f}, expected {spec}), max rel. deviation {dev:.1e}')
    worst = max(worst, dev)
sys.exit(0 if worst < 1e-12 else 1)
