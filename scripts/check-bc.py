#!/usr/bin/env python3
"""Self-consistency checker for a MOSE bc.txt.

  * every boundary cell of every block appears exactly once
  * connection/periodic records are reciprocal
  * chimera donors point inside a real block (ghost layers allowed)
"""
import sys
from collections import defaultdict

ONE_PROP = set([101, 103, 201, 420]) | set(range(301, 310)) | set(range(401, 409)) | {410}
ONE_PROP |= {501, 502}


def parse(path):
    recs = {}          # (b,i,j,k,f) -> (type, propline)
    chim = []          # (b,i,j,k,f, [(db,di,dj,dk)])
    dims = defaultdict(lambda: [0, 0, 0])
    with open(path) as fh:
        lines = fh.read().split('\n')
    n = len(lines)
    il = 0
    nrec = 0
    while il < n:
        s = lines[il].split()
        if not s:
            il += 1
            continue
        b, i, j, k, f, t = (int(x) for x in s[:6])
        nrec += 1
        d = dims[b]
        d[0] = max(d[0], i); d[1] = max(d[1], j); d[2] = max(d[2], k)
        prop = None
        np_ = 0
        if t == 102:
            n1, n2 = (int(x) for x in lines[il + 1].split())
            np_ = 1 + n1 + n2
            donors = []
            for c in range(n1 + n2):
                p = lines[il + 2 + c].split()
                donors.append(tuple(int(x) for x in p[:4]))
            chim.append((b, i, j, k, f, donors))
        elif t in ONE_PROP:
            np_ = 1
            prop = lines[il + 1]
        recs[(b, i, j, k, f)] = (t, prop)
        il += 1 + np_
    return recs, chim, dims, nrec


def main(path):
    recs, chim, dims, nrec = parse(path)
    print(f'{path}: {nrec} records, {len(dims)} blocks')

    err = 0

    # completeness
    expected = 0
    for b, (ni, nj, nk) in dims.items():
        expected += 2 * (nj * nk + ni * nk + ni * nj)
    if expected != nrec:
        print(f'  [FAIL] expected {expected} boundary cells, found {nrec}')
        err += 1
    else:
        print(f'  [ok]   record count matches block dimensions ({expected})')

    # reciprocity
    bad = 0
    nconn = 0
    for (b, i, j, k, f), (t, prop) in recs.items():
        if t not in (101, 103, 201):
            continue
        nconn += 1
        v = [int(x) for x in prop.split()[:5]]
        key = tuple(v)
        other = recs.get(key)
        if other is None:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(b,i,j,k,f)} type {t} -> {key}: no such boundary cell')
            continue
        ot, oprop = other
        if ot not in (101, 103, 201):
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(b,i,j,k,f)} -> {key} is type {ot}, not a connection')
            continue
        back = tuple(int(x) for x in oprop.split()[:5])
        if back != (b, i, j, k, f):
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(b,i,j,k,f)} -> {key} -> {back} (not reciprocal)')
    if bad:
        print(f'  [FAIL] {bad} of {nconn} connection records are not reciprocal')
        err += 1
    else:
        print(f'  [ok]   all {nconn} connection records reciprocal')

    # chimera donors
    badc = 0
    ndon = 0
    for (b, i, j, k, f, donors) in chim:
        for (db, di, dj, dk) in donors:
            ndon += 1
            if db not in dims:
                badc += 1
                continue
            ni, nj, nk = dims[db]
            if not (-1 <= di <= ni + 2 and -1 <= dj <= nj + 2 and -1 <= dk <= nk + 2):
                badc += 1
                if badc < 4:
                    print(f'  [FAIL] chimera donor {(db,di,dj,dk)} outside block {db} {(ni,nj,nk)}')
    if chim:
        if badc:
            print(f'  [FAIL] {badc} of {ndon} chimera donors out of range')
            err += 1
        else:
            print(f'  [ok]   all {ndon} chimera donors inside their block')

    return err


if __name__ == '__main__':
    rc = 0
    for p in sys.argv[1:]:
        rc += main(p)
    sys.exit(1 if rc else 0)
