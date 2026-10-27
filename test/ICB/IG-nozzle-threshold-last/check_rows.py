"""Check the rows a nozzle zone writes when the first cell past nozzle-threshold is the last one.

usage: python3 check_rows.py <gas-ic.tec> plenum|nozzle

plenum: every cell holds the plenum state (p = p0 = 5e5, at rest), as with nozzle-direction = dx;
nozzle: every cell takes the nozzle law (p below p0, flowing towards -x), as with sx.
"""
import sys


def bands(path):
    lines = open(path).read().split('\n')
    names = lines[0].split('=', 1)[1].split()
    dims = [int(lines[1].split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    vals = [float(v) for line in lines[2:] for v in line.split()]
    nn = dims[0] * dims[1] * dims[2]
    nc = (dims[0] - 1) * (dims[1] - 1) * (dims[2] - 1)
    return {n: vals[3 * nn + b * nc: 3 * nn + (b + 1) * nc] for b, n in enumerate(names[3:])}


field = bands(sys.argv[1])
cells = list(zip(field['p'], field['u'], field['v'], field['w']))
if sys.argv[2] == 'plenum':
    bad = [c for c in cells if c != (5.0e5, 0.0, 0.0, 0.0)]
else:
    bad = [c for c in cells if not (c[0] < 5.0e5 and c[1] < 0.0)]
print(f'{len(cells)} cells, {len(bad)} not {sys.argv[2]}: {bad[:3]}')
sys.exit(1 if bad or not cells else 0)
