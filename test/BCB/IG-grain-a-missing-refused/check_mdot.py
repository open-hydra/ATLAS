#!/usr/bin/env python3
"""IG-grain-a-missing-refused: the 502 records of a 2D BC file (records of 5 integers: block, i, j, face, code).

    check_mdot.py <bc.txt> <mdot_ref> <mode>

Every 502 record (face 1, three cells) carries mdot_ref first and the mode fifth, exactly as given.
"""
import sys


def main(path, mdot, mode):
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    n, bad = 0, []
    for k, ln in enumerate(lines):
        t = ln.split()
        if len(t) == 5 and t[4] == "502":
            vals = [float(v) for v in lines[k + 1].replace(",", " ").split()]
            n += 1
            if len(vals) < 5 or vals[0] != float(mdot) or vals[4] != float(mode):
                bad.append(f"record {t[:4]}: {vals}")
    for b in bad[:5]:
        print("[FAIL]", b)
    if n != 3 or bad:
        print(f"[FAIL] {n} records 502 (expected 3), {len(bad)} wrong")
        return 1
    print(f"502 on the three cells of face 1, mdot_ref {mdot}, mode {mode} [PASS]")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
