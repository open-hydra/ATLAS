#!/usr/bin/env python3
"""IG-carbon-phenolic-profile: every 506 record of face 4 (50 cells, centres x = 0.02 i - 0.01) carries
pyro_id 2, surf 1, phi = 0.2 + 0.1 x, hv0 = -9e5 + 1e5 x (the linear laws of phi.dat and hv0.dat), qrad 1e6, eps 0.85.
    check_profile.py <bc.txt>
Tolerance 1e-9 relative on phi and hv0 (linear interpolation in double precision; measured 2.0e-12); the rest exact."""
import sys

lines = [ln for ln in open(sys.argv[1]).read().split('\n') if ln.strip()]
bad, n = 0, 0
for k, ln in enumerate(lines):
    t = ln.split()
    if len(t) == 6 and t[5] == '506':
        n += 1
        i, f = int(t[1]), [v.strip() for v in lines[k + 1].split(',') if v.strip()]
        x = 0.02 * i - 0.01
        phi, hv0 = 0.2 + 0.1 * x, -9.0e5 + 1.0e5 * x
        ok = (len(f) == 6 and f[0] == '2' and f[1] == '1' and abs(float(f[2]) - phi) <= 1e-9 * phi and
              abs(float(f[3]) - hv0) <= 1e-9 * abs(hv0) and float(f[4]) == 1.0e6 and float(f[5]) == 0.85 and t[4] == '4')
        if not ok:
            bad += 1
            print(f'[FAIL] cell i={i}: {f}, expected 2, 1, {phi!r}, {hv0!r}, 1e6, 0.85')
if n != 50:
    bad += 1
    print(f'[FAIL] {n} records 506, expected 50 (face 4)')
print('[PASS]' if bad == 0 else f'[FAIL] {bad}')
sys.exit(1 if bad else 0)
