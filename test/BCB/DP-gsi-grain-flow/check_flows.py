#!/usr/bin/env python3
"""DP-gsi-grain-flow: the gas flow of a grain shared with the dispersed phases entering through it.

    check_flows.py <gas-bc.txt> <drop-bc.txt> <ash-bc.txt>

One block of 50 x 20 cells and one layer (IG-ablation's mesh). gas-bc.txt: 502 on faces 3 and 4, whose second
field a is 0.0052 x (1 - krho_tot): 0.8 on face 3 (drop 0.2), 0.63 on face 4 (drop 0.2, ash 0.05 + 0.1 + 0.02).
drop-bc.txt (one copy of the table): 401 with krho 0.2 on faces 3 and 4. ash-bc.txt (three copies: alumina's two
populations, then water's): 300 on face 3, 401 on face 4 with krho 0.05, 0.1, 0.02 in copies 1, 2, 3. Faces 1
and 2 are symmetries (300) and faces 5 and 6 null (0) in every file.
"""
import sys

A = 0.0052
NCELL = 2 * 20 + 2 * 50 + 2 * 1000          # the boundary cells of one copy of the table


def records(path, payload):
    """(i, j, k, f, code, payload lines) of every record of a one-block file."""
    out = []
    with open(path) as fh:
        lines = [ln for ln in fh.read().splitlines() if ln.strip()]
    n = 0
    while n < len(lines):
        b, i, j, k, f, code = (int(v) for v in lines[n].split())
        np = payload.get(code, 0)
        out.append((i, j, k, f, code, lines[n + 1:n + 1 + np]))
        n += 1 + np
    return out


def fields(line):
    return line.replace(",", " ").split()


def main(gas_path, drop_path, ash_path):
    bad = []
    gas = records(gas_path, {502: 1})
    drop = records(drop_path, {401: 1})
    ash = records(ash_path, {401: 1})
    if len(gas) != NCELL or len(drop) != NCELL or len(ash) != 3 * NCELL:
        return print(f"[FAIL] records: gas {len(gas)}, drop {len(drop)}, ash {len(ash)} "
                     f"(expected {NCELL}, {NCELL}, {3 * NCELL})") or 1

    for (i, j, k, f, code, pay) in gas:
        want = {1: 300, 2: 300, 3: 502, 4: 502}.get(f, 0)
        if code != want:
            bad.append(f"gas face {f} i={i} j={j}: {code}, expected {want}")
        elif code == 502:
            a = float(fields(pay[0])[1])
            ref = A * (1.0 - 0.2) if f == 3 else A * (1.0 - (0.2 + 0.05 + 0.1 + 0.02))
            if abs(a - ref) > 1e-12 * ref:
                bad.append(f"gas face {f} i={i}: a = {a!r}, expected {ref!r}")

    def check_dp(name, recs, copy, krho_face3, krho_face4):
        for (i, j, k, f, code, pay) in recs:
            if f in (1, 2):
                want, krho = 300, None
            elif f == 3:
                want, krho = (401, krho_face3) if krho_face3 is not None else (300, None)
            elif f == 4:
                want, krho = 401, krho_face4
            else:
                want, krho = 0, None
            if code != want:
                bad.append(f"{name} copy {copy} face {f} i={i}: {code}, expected {want}")
            elif code == 401 and float(fields(pay[0])[0]) != krho:
                bad.append(f"{name} copy {copy} face {f} i={i}: krho {fields(pay[0])[0]}, expected {krho}")

    check_dp("drop", drop, 1, 0.2, 0.2)
    for c, krho in enumerate((0.05, 0.1, 0.02)):
        check_dp("ash", ash[c * NCELL:(c + 1) * NCELL], c + 1, None, krho)

    for b in bad[:20]:
        print("[FAIL] " + b)
    if bad:
        print(f"[FAIL] {len(bad)} record(s)")
        return 1
    print("gas a: face 3 = 0.0052 x 0.8, face 4 = 0.0052 x 0.63 (50 cells each); drop 401 on faces 3-4; "
          "ash 300 on face 3, 401 on face 4 with krho 0.05 / 0.1 / 0.02 in its three copies [PASS]")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
