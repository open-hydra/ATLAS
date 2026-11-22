#!/usr/bin/env python3
"""manifold-groups: the 501 records of bc.txt per (block, face), independently of the reference file.

    check_manifold.py <bc.txt>

Expected: every cell of the five manifold faces carries one 501 record whose payload is the group id, the role of the
face and the five parameters of the group, the same on every record of the group; no other cell carries a 501.
  group 1 [merge]: block 2 face 2 and block 3 face 2 outlets (role 1), block 1 face 1 inlet (role 2); K 0, rf 1,
                   mdot-ratio 1, p0-ratio 1, dh0 0
  group 2 [turn]:  block 1 face 2 outlet, block 3 face 1 inlet; K 0.5, rf 0.8, mdot-ratio 0.5, p0-ratio 0.9, dh0 1.5e5
The reals are compared exactly: ATLAS writes them ES24.16 from the values of the deck.
"""
import sys

ONE_PROP = {101, 103, 201, 420, 410, 421} | set(range(301, 310)) | set(range(401, 409)) | set(range(501, 507))

EXPECTED = {  # (block, face): (gid, role, K, rf, mdot-ratio, p0-ratio, dh0)
    (1, 1): (1, 2, 0.0, 1.0, 1.0, 1.0, 0.0),
    (2, 2): (1, 1, 0.0, 1.0, 1.0, 1.0, 0.0),
    (3, 2): (1, 1, 0.0, 1.0, 1.0, 1.0, 0.0),
    (1, 2): (2, 1, 0.5, 0.8, 0.5, 0.9, 1.5e5),
    (3, 1): (2, 2, 0.5, 0.8, 0.5, 0.9, 1.5e5),
}
CELLS = {(1, 1): 64, (1, 2): 64, (2, 2): 64, (3, 1): 64, (3, 2): 64}   # 8 x 8 faces


def records(path):
    """(b, i, j, k, f, code, payload lines) of every record."""
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    out, n = [], 0
    while n < len(lines):
        b, i, j, k, f, code = (int(v) for v in lines[n].split())
        if code in (102, 104):
            n1, n2 = (int(v) for v in lines[n + 1].split()[:2])
            np_ = 1 + n1 + n2
        else:
            np_ = 1 if code in ONE_PROP else 0
        out.append((b, i, j, k, f, code, lines[n + 1:n + 1 + np_]))
        n += 1 + np_
    return out


def main(path):
    bad, count = 0, {}
    for b, i, j, k, f, code, payload in records(path):
        if (b, f) in EXPECTED:
            if code != 501:
                print(f"[FAIL] block {b} face {f} cell ({i},{j},{k}): code {code}, expected 501")
                bad += 1
                continue
            got = [float(v) for v in payload[0].replace(",", " ").split()]
            want = list(EXPECTED[(b, f)])
            if got != want:
                print(f"[FAIL] block {b} face {f} cell ({i},{j},{k}): payload {got}, expected {want}")
                bad += 1
            count[(b, f)] = count.get((b, f), 0) + 1
        elif code == 501:
            print(f"[FAIL] block {b} face {f} cell ({i},{j},{k}): a 501 record on a face no manifold lists")
            bad += 1
    for key, n in sorted(CELLS.items()):
        if count.get(key, 0) != n:
            print(f"[FAIL] block {key[0]} face {key[1]}: {count.get(key, 0)} manifold records, expected {n}")
            bad += 1
        else:
            print(f"block {key[0]} face {key[1]}: {n} records, group {EXPECTED[key][0]}, role {EXPECTED[key][1]}")
    print("[PASS]" if bad == 0 else f"[FAIL] {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
