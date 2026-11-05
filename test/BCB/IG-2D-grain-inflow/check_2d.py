#!/usr/bin/env python3
"""IG-2D-grain-inflow: the 502 lines of a 2D BC file (records of 5 integers: block, i, j, face, code).

    check_2d.py <bc.txt> <mode> [<turbulence value> ...]

Every 502 record (face 1, three cells) carries mdot_ref = a*rhoGrain*SF = 0.0052 x 1750, n 0.35, pRef 4.829e6, Taf 0
(no eq-CEA-file), the mode, the mass fraction of O2 (1) and, in mode 2, the turbulence values given, in order.
"""
import sys


def main(path, mode, *turb):
    want = [0.0052 * 1750.0, 0.35, 4.829e6, 0.0, float(mode), 1.0] + [float(t) for t in turb]
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    n, bad = 0, []
    for k, ln in enumerate(lines):
        t = ln.split()
        if len(t) == 5 and t[4] == "502":
            vals = [float(v) for v in lines[k + 1].replace(",", " ").split()]
            n += 1
            if len(vals) != len(want) or any(abs(a - b) > 1e-12 * max(abs(b), 1e-300) for a, b in zip(vals, want)):
                bad.append(f"record {ln.split()[:4]}: {vals}, expected {want}")
    for b in bad[:5]:
        print("[FAIL]", b)
    if n != 3 or bad:
        print(f"[FAIL] {n} records 502 (expected 3), {len(bad)} wrong")
        return 1
    print(f"502 on the three cells of face 1, mode {mode}, {len(want)} fields [PASS]")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
