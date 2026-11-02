#!/usr/bin/env python3
"""IG-grain-a-missing-refused: the 502 records of a 2D BC file (records of 5 integers: block, i, j, face, code).

    check_mdot.py <bc.txt> <mode> <mdot_ref> [<mdot_ref> <mdot_ref>]

Every 502 record (face 1, three cells) carries the mode fifth and mdot_ref first: one value for every record, or one
per record in the order of the file. Within 4e-15 relative: the roundings of the linear interpolation of an a-file at
the cell centre and of the product a*rhoGrain*SF, a dozen operations of at most 1.1e-16 each (0 is checked exactly).
"""
import sys


def main(path, mode, *mdot):
    want = [float(m) for m in mdot]
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    recs = []
    for k, ln in enumerate(lines):
        t = ln.split()
        if len(t) == 5 and t[4] == "502":
            recs.append((t[:4], [float(v) for v in lines[k + 1].replace(",", " ").split()]))
    if len(want) == 1:
        want = want * len(recs)
    bad = [f"record {c}: {v}, expected mdot_ref {w}, mode {mode}" for (c, v), w in zip(recs, want)
           if len(v) < 5 or v[4] != float(mode) or abs(v[0] - w) > 4e-15 * abs(w)]
    for b in bad[:5]:
        print("[FAIL]", b)
    if len(recs) != 3 or len(want) != 3 or bad:
        print(f"[FAIL] {len(recs)} records 502 (expected 3), {len(bad)} wrong")
        return 1
    print(f"502 on the three cells of face 1, mdot_ref {', '.join(mdot)}, mode {mode} [PASS]")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
