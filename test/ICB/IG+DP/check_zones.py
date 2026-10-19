#!/usr/bin/env python3
"""IG+DP, zone cases: the dispersed-phase keys of a zone apply to the cells of that zone.
check_zones.py NEW REF krho: a block split at x = 0 into a zone with krho 0.20 (left) and one with krho 0.40 (right), the
gas state of IG+DP in both: the left cells must carry IG+DP's reference (krho 0.20) value for value, the right cells twice
its rp and np and the same up, vp, wp, Tp.
check_zones.py NEW REF interp: a block that builds only the dispersed phase, its left zone interpolated from IG+DP's
reference and its right zone in vacuum: the left cells must carry the reference values, the right cells 1e-20."""
import re
import sys


def fields(path):
    with open(path) as fh:
        lines = fh.read().split('\n')
    names = [q or b for q, b in re.findall(r'"([^"]+)"|([^\s",]+)', lines[0].split('=', 1)[1])]   # quoted or bare
    ni, nj, nk = map(int, re.search(r'I=(\d+), J=(\d+), K=(\d+)', lines[1]).groups())
    nodal, cell = ni * nj * nk, (ni - 1) * (nj - 1) * (nk - 1)
    vals = ' '.join(lines[2:]).split()
    out, pos = {}, 0
    for i, name in enumerate(names):
        size = nodal if i < 3 else cell
        out[name] = vals[pos:pos + size]
        pos += size
    return out, (ni, nj, nk)


def centres_x(x, dims):
    ni, nj, nk = dims
    x = [float(v) for v in x]
    node = lambda i, j, k: x[i + ni * (j + nj * k)]
    return [sum(node(i + a, j + b, k + c) for a in (0, 1) for b in (0, 1) for c in (0, 1)) / 8.0
            for k in range(nk - 1) for j in range(nj - 1) for i in range(ni - 1)]


new, dims = fields(sys.argv[1])
ref, _ = fields(sys.argv[2])
mode = sys.argv[3]
xc = centres_x(new['x'], dims)
if min(abs(v) for v in xc) < 1e-6:
    sys.exit('FAIL a cell centre lies on the zone limit x = 0')
left = [n for n, v in enumerate(xc) if v < 0.0]
right = [n for n, v in enumerate(xc) if v > 0.0]
bad = 0


def check(label, ok):
    global bad
    print(('PASS ' if ok else 'FAIL ') + label)
    bad += not ok


def close(a, b):
    return abs(a - b) <= 1e-12 * max(abs(a), abs(b), 1e-300)


for v in ('rp', 'up', 'vp', 'wp', 'Tp', 'np'):
    a, r = new[v + '_11'], ref[v + '_11']
    if mode == 'krho':
        check('%s_11 left (%d cells) = IG+DP' % (v, len(left)), all(a[n] == r[n] for n in left))
        if v in ('rp', 'np'):
            check('%s_11 right (%d cells) = 2 x IG+DP' % (v, len(right)),
                  all(close(float(a[n]), 2.0 * float(r[n])) for n in right))
        else:
            check('%s_11 right (%d cells) = IG+DP' % (v, len(right)), all(a[n] == r[n] for n in right))
    else:
        check('%s_11 left (%d cells) = the interpolated source' % (v, len(left)),
              all(close(float(a[n]), float(r[n])) for n in left))
        check('%s_11 right (%d cells) = 1e-20 (vacuum)' % (v, len(right)), all(float(a[n]) == 1e-20 for n in right))
sys.exit(1 if bad else 0)
