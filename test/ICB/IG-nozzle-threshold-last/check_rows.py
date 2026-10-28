"""Check which rows of cells a nozzle zone leaves at rest and which take the nozzle law.

usage: python3 check_rows.py <gas-ic.tec> dx|sx <rows at rest: first-last | none>

A row at rest holds the plenum state in every cell (p = p0 = 5e5, no velocity); every other row takes
the nozzle law (p below p0, flowing along the direction: u > 0 with dx, u < 0 with sx).
"""
import sys


def bands(path):
    lines = open(path).read().split('\n')
    names = lines[0].split('=', 1)[1].split()
    dims = [int(lines[1].split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    vals = [float(v) for line in lines[2:] for v in line.split()]
    nn = dims[0] * dims[1] * dims[2]
    nc = (dims[0] - 1) * (dims[1] - 1) * (dims[2] - 1)
    return dims[0] - 1, {n: vals[3 * nn + b * nc: 3 * nn + (b + 1) * nc] for b, n in enumerate(names[3:])}


rows, field = bands(sys.argv[1])
sign = 1.0 if sys.argv[2] == 'dx' else -1.0
rest = set() if sys.argv[3] == 'none' else set(range(int(sys.argv[3].split('-')[0]),
                                                     int(sys.argv[3].split('-')[1]) + 1))
bad = []
for c, cell in enumerate(zip(field['p'], field['u'], field['v'], field['w'])):
    row = c % rows + 1
    if row in rest:
        ok = cell == (5.0e5, 0.0, 0.0, 0.0)
    else:
        ok = cell[0] < 5.0e5 and sign * cell[1] > 0.0
    if not ok:
        bad.append((row, cell))
print(f'{sys.argv[2]}: {len(field["p"])} cells, rows at rest {sorted(rest) or "none"}, {len(bad)} wrong: {bad[:3]}')
sys.exit(1 if bad or not field['p'] else 0)
