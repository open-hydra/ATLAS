#!/usr/bin/env python3
"""Judge the quality of MDB decompositions from their maps alone.

Written by Marco Grossi (/data10/grossi/tmp/scaling/swbli/analyse_decomp.py,
2026-08) for the SWBLI campaign, where the question was whether MDB cuts a
block along a good axis: cutting the short axis makes pancakes whose halo
approaches the block volume, cutting the long axis keeps the exchanged surface
small. Extended here with the two numbers MDB itself scores a decomposition by
and a gate that compares two maps.

Per map:

  blocks    new blocks
  imbal%    max/mean - 1 over blocks (Marco's measure: a rank holding the
            largest block sets the pace)
  balance%  MOSE's and ICE's balance, ideal/max rank load after their LPT on
            cell counts (largest block first to the least loaded rank, ties in
            block order), recomputed here and checked against the map's rank
            column
  cutS/V    area of INTERNAL (cut) faces over volume, summed over blocks
  ghost%    MDB's ghost-cell overhead: two ghost layers on every cut side, as
            a percentage of the cells
  score     balance / (1 + w * ghost / 100), MDB's objective = halo (w from
            --halo-weight, 1 by default)
  cuts      cut faces by axis (i / j / k)
  interface how many cut faces have their neighbour on another rank

  ./analyse_decomp.py [--ranks R] [--halo-weight W] MAP...
  ./analyse_decomp.py --assert-better GREEDY.map SEARCHED.map...

--assert-better exits 1 unless every other map scores strictly higher than the
first (a gate for objective = halo: the searched cut must beat the greedy one on
MDB's own score). --ranks overrides the rank count read from the rank column.
"""

import argparse
import re
import sys
from collections import Counter

GC = 2   # MOSE_Global_m::gc: ghost layers on a cut side


def read_map(path):
    """[(new, parent, i0,i1, j0,j1, k0,k1, ni,nj,nk, cells, rank)]"""
    rows = []
    for line in open(path):
        if line.lstrip().startswith("#") or not line.strip():
            continue
        f = line.split()
        if len(f) < 13:
            continue          # the face-origin table
        rows.append(tuple(int(x) for x in f[:13]))
    return rows


def lpt(cells, nranks):
    """MOSE_Mod_MPI::partition_blocks: owner of every block and the max load."""
    order = sorted(range(len(cells)), key=lambda b: -cells[b])   # stable: ties keep block order
    load = [0] * nranks
    owner = [0] * len(cells)
    for b in order:
        r = load.index(min(load))
        owner[b] = r
        load[r] += cells[b]
    return owner, max(load)


def analyse(path, nranks=None, w=1.0):
    rows = read_map(path)
    if not rows:
        return None
    nb = len(rows)
    cells = [r[11] for r in rows]
    mean = sum(cells) / nb
    imbal = max(cells) / mean - 1.0

    if nranks is None:
        nranks = max(r[12] for r in rows) + 1
    owner, maxload = lpt(cells, nranks)
    balance = 100.0 * (sum(cells) / nranks) / maxload
    rank_ok = all(o == r[12] for o, r in zip(owner, rows))

    # A face is "cut" when it is not on the parent block's own boundary.  The
    # parent extent is recovered from the union of its children, which is exact
    # because MDB only subdivides.
    ext = {}
    for r in rows:
        p = r[1]
        e = ext.setdefault(p, [r[2], r[3], r[4], r[5], r[6], r[7]])
        e[0] = min(e[0], r[2]); e[1] = max(e[1], r[3])
        e[2] = min(e[2], r[4]); e[3] = max(e[3], r[5])
        e[4] = min(e[4], r[6]); e[5] = max(e[5], r[7])

    # (parent, lo, hi) of every block, to find the neighbour across a cut side
    def neighbour(p, i, j, k):
        for q, r in enumerate(rows):
            if r[1] == p and r[2] <= i <= r[3] and r[4] <= j <= r[5] and r[6] <= k <= r[7]:
                return q
        return None

    cut_area = 0
    ghost = 0
    vol = 0
    axis = Counter()
    interface = 0
    for q, r in enumerate(rows):
        p, i0, i1, j0, j1, k0, k1, ni, nj, nk = r[1], *r[2:8], *r[8:11]
        e = ext[p]
        vol += ni * nj * nk
        sides = []
        if i0 > e[0]:
            sides.append((nj * nk, "i", (i0 - 1, j0, k0)))
        if i1 < e[1]:
            sides.append((nj * nk, "i", (i1 + 1, j0, k0)))
        if j0 > e[2]:
            sides.append((ni * nk, "j", (i0, j0 - 1, k0)))
        if j1 < e[3]:
            sides.append((ni * nk, "j", (i0, j1 + 1, k0)))
        if k0 > e[4]:
            sides.append((ni * nj, "k", (i0, j0, k0 - 1)))
        if k1 < e[5]:
            sides.append((ni * nj, "k", (i0, j0, k1 + 1)))
        for area, ax, cell in sides:
            cut_area += area
            ghost += GC * area
            axis[ax] += 1
            n = neighbour(p, *cell)
            if n is not None and owner[n] != owner[q]:
                interface += 1

    ghost_pct = 100.0 * ghost / vol
    score = balance / (1.0 + w * ghost_pct / 100.0)
    return dict(nb=nb, nranks=nranks, imbal=imbal, balance=balance, rank_ok=rank_ok,
                sv=cut_area / vol, ghost=ghost_pct, score=score, axis=axis,
                interface=interface, dmin=min(cells), dmax=max(cells),
                shapes=Counter((r[8], r[9], r[10]) for r in rows))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("maps", nargs="+")
    ap.add_argument("--ranks", type=int, default=None)
    ap.add_argument("--halo-weight", type=float, default=1.0)
    ap.add_argument("--assert-better", action="store_true",
                    help="exit 1 unless every map after the first scores strictly higher")
    args = ap.parse_args()

    print("%-28s %6s %6s %8s %8s %8s %8s %7s %14s %9s" %
          ("map", "ranks", "blocks", "imbal%", "balance%", "cutS/V", "ghost%", "score",
           "cuts i/j/k", "interface"))
    results = []
    for path in args.maps:
        m = re.search(r"/R(\d+)/", path)
        tag = m.group(1) if m else path
        a = analyse(path, args.ranks, args.halo_weight)
        if not a:
            print("%-28s (no records)" % tag)
            continue
        ax = a["axis"]
        print("%-28s %6d %6d %8.1f %8.1f %8.4f %8.1f %7.1f %14s %9d" %
              (tag[-28:], a["nranks"], a["nb"], a["imbal"] * 100.0, a["balance"], a["sv"],
               a["ghost"], a["score"], "%d / %d / %d" % (ax["i"], ax["j"], ax["k"]),
               a["interface"]))
        if not a["rank_ok"]:
            print("  [warn] the rank column of %s is not what LPT on cell counts gives" % path)
        results.append((path, a))

    print("\nghost%% is MDB's own overhead (two ghost layers per cut side, GC = %d); score is its" % GC)
    print("objective = halo, balance / (1 + w * ghost/100), with w = %g. Higher is better." % args.halo_weight)

    if args.assert_better:
        if len(results) < 2:
            sys.exit("--assert-better needs a base map and at least one other")
        base_path, base = results[0]
        bad = [(p, a) for p, a in results[1:] if not a["score"] > base["score"]]
        for p, a in bad:
            print("[FAIL] %s scores %.3f, not above the base %s at %.3f" %
                  (p, a["score"], base_path, base["score"]))
        if bad:
            sys.exit(1)
        print("[ok]   every map scores above the base %s (%.3f)" % (base_path, base["score"]))


if __name__ == "__main__":
    main()
