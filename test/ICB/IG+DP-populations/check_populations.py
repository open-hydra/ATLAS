#!/usr/bin/env python3
"""IG+DP-populations gate: AL2O3(L) on two populations with the scalar zone keys krho and dp of IG+DP.
Every field of population 2 (rp, up, vp, wp, Tp, np) must equal population 1's, and population 1 must
equal IG+DP's single-population reference value for value."""
import re
import sys


def fields(path):
    with open(path) as fh:
        lines = fh.read().split('\n')
    names = re.findall(r'"([^"]+)"', lines[0])
    ni, nj, nk = map(int, re.search(r'I=(\d+), J=(\d+), K=(\d+)', lines[1]).groups())
    nodal, cell = ni * nj * nk, (ni - 1) * (nj - 1) * (nk - 1)
    vals = ' '.join(lines[2:]).split()
    out, pos = {}, 0
    for i, name in enumerate(names):
        size = nodal if i < 3 else cell
        out[name] = vals[pos:pos + size]
        pos += size
    return out


new, ref = fields(sys.argv[1]), fields(sys.argv[2])
bad = 0
for v in ('rp', 'up', 'vp', 'wp', 'Tp', 'np'):
    for label, a, b in ((v + '_12 = ' + v + '_11', new[v + '_12'], new[v + '_11']),
                        (v + '_11 = IG+DP', new[v + '_11'], ref[v + '_11'])):
        ok = len(a) > 0 and a == b
        print(('PASS ' if ok else 'FAIL ') + label)
        bad += not ok
sys.exit(1 if bad else 0)
