#!/usr/bin/env python3
"""DP-gsi-manifold: the codes of the two BC files per face, and per range of i on faces 3 and 4.

    check_codes.py <gas-bc.txt> <drop-bc.txt>

The mesh is one block of 50 x 20 cells and one layer (IG-ablation's): face 1 (i = 1) the manifold [man]
drawing on face 2, face 2 a symmetry, face 3 (j = 1) the grain with drop's keys for i 1-25 and without them for
i 26-50, face 4 (j = 20) melting i 1-12, pyrolysis 13-25, surface reactions 26-37, both 38-50; faces 5 and 6
(the layer's planes) are null. Expected:
  gas-bc.txt   501 (payload: block 1, face 2), 300, 502 on all of face 3, 503/504/505/506 on face 4, 0; the 502
               record's second field, the propellant mass flux a*rhoGrain*SF = 0.0052 x 1750 x 1, times 1 - 0.2 on
               the grain with drop's keys
  drop-bc.txt  300 on faces 1, 2 and 4 and on the grain without drop's keys, 401 on the grain with them
               (krho 0.2, kV 0.9, normal direction, kT 1.0, rp 1e-5 from drop-dp 2e-5, sigmap 0, Dirac,
               ds 0), 0 on faces 5 and 6; no payload but the 401's.
"""
import sys

PAYLOAD_GAS = {501: 1, 502: 1, 503: 1, 504: 1, 505: 1, 506: 1}
PAYLOAD_DP = {401: 1, 402: 1, 403: 1}


def records(path, payload):
    """(i, j, k, f, code, payload lines) of every record of a one-block file."""
    out = []
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    n = 0
    while n < len(lines):
        b, i, j, k, f, code = (int(v) for v in lines[n].split())
        if b != 1:
            raise ValueError(f"{path}: record of block {b}")
        np = payload.get(code, 0)
        out.append((i, j, k, f, code, lines[n + 1:n + 1 + np]))
        n += 1 + np
    return out


def expected_gas(i, f):
    if f == 1:
        return 501
    if f == 2:
        return 300
    if f == 3:
        return 502
    if f == 4:
        return 503 if i <= 12 else 504 if i <= 25 else 505 if i <= 37 else 506
    return 0


def expected_dp(i, f):
    if f == 3 and i <= 25:
        return 401
    return 0 if f in (5, 6) else 300


def main(gas_path, dp_path):
    bad = 0
    gas, dp = records(gas_path, PAYLOAD_GAS), records(dp_path, PAYLOAD_DP)
    if [r[:4] for r in gas] != [r[:4] for r in dp]:
        print("[FAIL] the two files do not list the same cells in the same order")
        return 1
    count = {}
    for (i, j, k, f, cg, pg), (_, _, _, _, cd, pd) in zip(gas, dp):
        if cg != expected_gas(i, f) or cd != expected_dp(i, f):
            print(f"[FAIL] cell i={i} j={j} k={k} face {f}: gas {cg}, drop {cd}, "
                  f"expected {expected_gas(i, f)}, {expected_dp(i, f)}")
            bad += 1
        if cg == 502:
            a = float(pg[0].replace(",", " ").split()[1])
            want = 0.0052 * 1750.0 * (1.0 - 0.2) if i <= 25 else 0.0052 * 1750.0
            if abs(a - want) > 1e-12 * want:
                print(f"[FAIL] 502 at i={i}: a*rhoGrain*SF = {a!r}, expected {want!r}")
                bad += 1
        if cg == 501 and [int(v) for v in pg[0].replace(",", " ").split()] != [1, 2]:
            print(f"[FAIL] manifold payload {pg}")
            bad += 1
        if cd == 401:
            t = pd[0].replace(",", " ").split()
            want = [0.2, 0.9, "normal", "normal", 1.0, 1.0e-5, 0.0, "Dirac", 0.0]
            got = [v if v in ("normal", "Dirac") else float(v) for v in t]
            if got != want:
                print(f"[FAIL] 401 payload at i={i}: {t}")
                bad += 1
        count[(f, cg, cd)] = count.get((f, cg, cd), 0) + 1
    for key in sorted(count):
        print("face %d  gas %3d  drop %3d  : %4d cells" % (key + (count[key],)))
    print("[PASS]" if bad == 0 else f"[FAIL] {bad} cell(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
