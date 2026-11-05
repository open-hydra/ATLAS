#!/usr/bin/env python3
"""DP-mixture-401: the 401 records of three dispersed phases sharing inlets (headers: block, i, j, k, face, code).

    check_mix.py <partE-bc.txt> <partL-bc.txt> <partG-bc.txt>

Block 3 face 1 ([injCH4]): partE 401 with 0.2/(1 - 0.5), partL 401 with 0.3/(1 - 0.5), both with G = 7.0 last
(10 fields); partG 402 with gp 7.0 and no G (9 fields). Block 2 face 1 ([injOX], no key): 401 with 0 and G 0 in the
three files. Field 1 within 1e-15 relative (the order of the sum krho_tot and the division), G exactly.
"""
import sys


def records(path):
    lines = [ln for ln in open(path).read().splitlines() if ln.strip()]
    out = []
    for i, ln in enumerate(lines):
        t = ln.split()
        if 4 <= len(t) <= 6 and all(x.lstrip('-').isdigit() for x in t):
            code = int(t[-1])
            pay = lines[i + 1].replace(',', ' ').split() if code in (401, 402, 403) else None
            out.append((int(t[0]), int(t[-2]), code, pay))
    return out


def main(e_path, l_path, g_path):
    want_ch4 = {'partE': (401, 0.2 / (1.0 - 0.5), 7.0), 'partL': (401, 0.3 / (1.0 - 0.5), 7.0),
                'partG': (402, 7.0, None)}
    bad, n = [], {}
    for name, path in (('partE', e_path), ('partL', l_path), ('partG', g_path)):
        for b, f, code, pay in records(path):
            if f != 1 or b not in (2, 3):
                continue
            code_w, v1, g = want_ch4[name] if b == 3 else (401, 0.0, 0.0)
            n[(name, b)] = n.get((name, b), 0) + 1
            ok = code == code_w and pay is not None and abs(float(pay[0]) - v1) <= 1e-15 * v1
            ok = ok and (len(pay) == 9 if g is None else len(pay) == 10 and float(pay[-1]) == g)
            if not ok:
                bad.append(f'{name} block {b} face 1: code {code}, {pay}; expected {code_w}, {v1!r}, G {g}')
    for x in bad[:8]:
        print('[FAIL]', x)
    if bad or len(n) != 6 or min(n.values()) == 0:
        print(f'[FAIL] {len(bad)} record(s); cells per (phase, block): {n}')
        return 1
    print(f'injCH4: partE 0.4, partL 0.6 with G 7.0, partG 402 gp 7.0; injOX: 401 0, G 0; cells {n} [PASS]')
    return 0


if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:4]))
