"""Check the temperature ICB writes from 1-D profiles in zones (ASCII Tecplot IC files).

usage: python3 check_profile.py zones|first <ic.tec>
       python3 check_profile.py solid <solid-ic.tec>

zones: the cells of zone lo (x < 0.5) carry T = 400 + 200 x from lo.dat, those of zone hi T = 300;
first: every cell carries T = 350 + 100 (x - 0.0625) / 0.875 from first.dat, the first cell 350;
solid: the cells whose centre lies at x < 0 carry T = 300 (zone cold), the others 600 (zone hot).
The gas is O2 0.233, N2 0.767: T = p / (R rho).
"""
import sys

R = 8314.46261815324 * (0.233 / 31.998 + 0.767 / 28.014 + 1e-20 / 2.016)


def read(path):
    lines = open(path).read().split('\n')
    names = lines[0].split('=', 1)[1].split()
    dims = [int(lines[1].split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    vals = [float(v) for line in lines[2:] for v in line.split()]
    ni, nj, nk = dims
    ncoord = 3 if 'z' in names[:3] else 2      # a 2-D file: x y, one node plane
    layers = (0, 1) if nk > 1 else (0,)
    nn = ni * nj * nk
    nc = (ni - 1) * (nj - 1) * max(nk - 1, 1)
    x = vals[:nn]
    centres = []
    for k in range(max(nk - 1, 1)):
        for j in range(nj - 1):
            for i in range(ni - 1):
                corners = [x[(i + a) + ni * ((j + b) + nj * (k + c))]
                           for a in (0, 1) for b in (0, 1) for c in layers]
                centres.append(sum(corners) / len(corners))
    bands = {n: vals[ncoord * nn + b * nc: ncoord * nn + (b + 1) * nc]
             for b, n in enumerate(names[ncoord:])}
    return centres, bands


mode, path = sys.argv[1], sys.argv[2]
centres, bands = read(path)
if mode == 'solid':
    temperature = bands['T']
    expected = [300.0 if xc < 0.0 else 600.0 for xc in centres]
else:
    rho = [sum(v) for v in zip(*(bands[n] for n in bands if n.startswith('rho')))]
    temperature = [p / (R * r) for p, r in zip(bands['p'], rho)]
    if mode == 'zones':
        expected = [400.0 + 200.0 * xc if xc < 0.5 else 300.0 for xc in centres]
    else:
        expected = [350.0 + 100.0 * (xc - 0.0625) / 0.875 for xc in centres]
worst = max(abs(t / e - 1.0) for t, e in zip(temperature, expected))
cold = sum(1 for e in expected if e == 300.0)
print(f'{mode}: {len(temperature)} cells, T from {min(temperature):.6f} to {max(temperature):.6f} K, '
      f'{cold} at 300 K expected; max relative deviation {worst:.1e}')
sys.exit(0 if worst < 1e-12 else 1)
