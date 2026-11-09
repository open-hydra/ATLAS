#!/usr/bin/env python3
"""DP-chimera-pure2D: the chimera search on a pure-2D mesh gives, facelet by facelet, the payload of DP-chimera.

mesh.tec is the first node plane of DP-chimera's planar slab (make_mesh.py): ATLAS reads it as a pure-2D mesh,
stored inside as a single layer of unit depth, writes headers of five integers `b i j f code` and searches four
faces. A volume fraction is a ratio of volumes of the same receiver, so the depth cancels: every 102 facelet must
carry the donors and fractions of the same facelet of DP-chimera, a single-layer mesh read on another path. Walked
record by record (a header, then for 102 its donor-count line `c1 c2` and c1 + c2 donor lines `b i j k w`; 200
and 300 carry no payload in these decks), the files must give
  (a) 350 headers of five integers (2 (Ny + Nx) per block, CELLS below);
  (b) on every facelet (b, i, j, f) the code of DP-chimera's record (b, i, j, 1, f): 275 x 300, 75 x 102
      (DP-chimera's records of faces 5 and 6 have no counterpart);
  (c) on every 102 facelet the donor-count line and the donors (b, i, j, k) of DP-chimera, and every volume
      fraction within 1e-6 of DP-chimera's, absolute or relative (the rule of numdiff.awk).
  python3 check_pure2d.py <bc.txt> <DP-chimera reference bc.txt>
Python >= 3.6, standard library only.
"""
import sys
from collections import Counter

CELLS = {1: (50, 30), 2: (25, 70)}   # cells of the two blocks in the plane (DP-chimera/mesh.tec)
TOL = 1e-6


def is_int(token):
    return token.lstrip("+-").isdigit()


def stop(message):
    print("FAIL " + message)
    sys.exit(1)


def records(path, nint):
    """{header indices: (code, donor-count pair, [(b, i, j, k, w)])} of a file whose headers hold nint integers."""
    with open(path) as f:
        lines = f.read().splitlines()
    out, n = {}, 0
    while n < len(lines):
        tok = lines[n].split()
        if len(tok) != nint or not all(is_int(t) for t in tok):
            stop("%s line %d is not a header of %d integers: '%s'" % (path, n + 1, nint, lines[n]))
        key, code = tuple(int(t) for t in tok[:-1]), int(tok[-1])
        if key in out:
            stop("%s line %d: header %s written twice" % (path, n + 1, key))
        count, donors = None, []
        if code == 102:
            count = lines[n + 1].split() if n + 1 < len(lines) else []
            if len(count) != 2 or not all(is_int(t) for t in count):
                stop("%s line %d: the 102 header is not followed by a donor-count line `c1 c2`" % (path, n + 1))
            count = (int(count[0]), int(count[1]))
            for m in range(n + 2, n + 2 + sum(count)):
                donor = lines[m].split() if m < len(lines) else []
                if len(donor) != 5 or not all(is_int(t) for t in donor[:4]) or is_int(donor[4]):
                    stop("%s line %d is not a donor line `b i j k w` of the 102 record at line %d" % (path, m + 1, n + 1))
                donors.append(tuple(int(t) for t in donor[:4]) + (float(donor[4].replace("D", "E")),))
            n += 2 + sum(count)
        elif code in (200, 300):
            n += 1
        else:
            stop("%s line %d: code %d, not one of 102, 200, 300" % (path, n + 1, code))
        out[key] = (code, count, donors)
    return out


def main():
    produced, reference = sys.argv[1:3]
    pure = records(produced, 5)
    slab = records(reference, 6)
    bad = 0

    def check(ok, label):
        nonlocal bad
        print(("PASS " if ok else "FAIL ") + label)
        bad += 0 if ok else 1

    per_block = Counter(b for b, _, _, _ in pure)
    expected = {b: 2 * (nx + ny) for b, (nx, ny) in CELLS.items()}
    check(dict(per_block) == expected, "(a) %d headers of five integers, per block %s (expected %s)"
          % (len(pure), dict(sorted(per_block.items())), expected))

    codes, missing, differ = Counter(), [], []
    for (b, i, j, f), (code, _, _) in sorted(pure.items()):
        twin = slab.get((b, i, j, 1, f))
        if twin is None:
            missing.append((b, i, j, f))
        elif twin[0] != code:
            differ.append(((b, i, j, f), code, twin[0]))
        codes[code] += 1
    in_plane = sum(1 for (b, i, j, k, f) in slab if f <= 4)
    check(not missing and not differ and in_plane == len(pure),
          "(b) every facelet has DP-chimera's code: %s; %d of DP-chimera's %d in-plane records matched%s"
          % (", ".join("%d x %d" % (n, c) for c, n in sorted(codes.items())), len(pure) - len(missing), in_plane,
             "" if not (missing or differ) else "; missing %s, different %s" % (missing[:3], differ[:3])))

    worst_abs = worst_rel = 0.0
    nfrac, bad_donors, bad_fracs = 0, [], []
    for key, (code, count, donors) in sorted(pure.items()):
        if code != 102:
            continue
        b, i, j, f = key
        twin = slab.get((b, i, j, 1, f))
        if twin is None or twin[0] != 102 or twin[1] != count or [d[:4] for d in twin[2]] != [d[:4] for d in donors]:
            bad_donors.append(key)
            continue
        for d, t in zip(donors, twin[2]):
            diff, scale = abs(d[4] - t[4]), max(abs(d[4]), abs(t[4]))
            nfrac += 1
            worst_abs = max(worst_abs, diff)
            worst_rel = max(worst_rel, diff / scale if scale > 0 else 0.0)
            if not (diff <= TOL or diff <= TOL * scale):
                bad_fracs.append((key, d[:4], d[4], t[4]))
    check(not bad_donors, "(c) on %d facelets coded 102 the donor counts and donors (b, i, j, k) of DP-chimera%s"
          % (codes[102], "" if not bad_donors else "; different on %s" % bad_donors[:3]))
    check(nfrac > 0 and not bad_fracs, "(c) %d volume fractions within %g of DP-chimera's (worst %.3e absolute, %.3e "
          "relative)%s" % (nfrac, TOL, worst_abs, worst_rel, "" if not bad_fracs else "; outside: %s" % bad_fracs[:3]))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
