"""Check the velocity that the flow angles give in an ICB IC file (ASCII Tecplot, one 3D block).

usage: python3 check_angles.py <ic.tec with angles> <ic.tec without angles> <alpha> <beta>

The run without angles gives the speed V along x. With the angles (radians) every cell must
carry V (cos alpha cos beta, sin alpha cos beta, sin beta), the direction of the solvers'
inflow BC: a unit vector, so the speed is V whatever the angles.
"""
import math
import sys


def velocity(path):
    lines = open(path).read().split('\n')
    names = lines[0].split('=', 1)[1].replace('"', ' ').split()
    zone = lines[1]
    dims = [int(zone.split(f'{c}=')[1].split(',')[0]) for c in 'IJK']
    vals = [float(v) for line in lines[2:] for v in line.split()]
    nn = dims[0] * dims[1] * dims[2]
    nc = (dims[0] - 1) * (dims[1] - 1) * (dims[2] - 1)
    band = {n: vals[3 * nn + b * nc: 3 * nn + (b + 1) * nc] for b, n in enumerate(names[3:])}
    return list(zip(band['u'], band['v'], band['w']))


angled, straight = velocity(sys.argv[1]), velocity(sys.argv[2])
alpha, beta = float(sys.argv[3]), float(sys.argv[4])
direction = (math.cos(alpha) * math.cos(beta), math.sin(alpha) * math.cos(beta), math.sin(beta))
worst = 0.0
for got, ref in zip(angled, straight):
    speed = ref[0]
    if speed <= 0.0 or abs(ref[1]) + abs(ref[2]) > 1e-12 * speed:
        sys.exit(f'the run without angles is not along x: {ref}')
    worst = max(worst, max(abs(g - speed * d) for g, d in zip(got, direction)) / speed)
u, v, w = angled[0]
print(f'cell 1: V = {straight[0][0]:.6e}, (u, v, w) = ({u:.6e}, {v:.6e}, {w:.6e}), '
      f'|u| / V = {math.sqrt(u * u + v * v + w * w) / straight[0][0]:.15f}; '
      f'max deviation / V over {len(angled)} cells: {worst:.1e}')
sys.exit(0 if worst < 1e-12 else 1)
