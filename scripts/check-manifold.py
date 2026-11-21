#!/usr/bin/env python3
"""Verify the manifold (type-501) records of a decomposed MOSE bc.txt.

  ./check-manifold.py <original bc.txt> <split bc.txt> <decomposition.map>

A 501 payload names no block or cell: it is the group id, the role of the face
(1 outlet, 2 inlet) and the parameters of the group (K, rf, mdot-ratio,
p0-ratio, dh0), and the solvers sum over the faces of a group wherever the
split puts them. So the split changes nothing in the record: for every 501
record of the split file the parent cell carried a 501 record with the same
payload, and the two files hold the same number of them. A cut through a
manifold face, or its two sides on two ranks, are fine; the script reports
how many pieces and ranks each group's faces ended on.

The map supplies the parent, the index range and the rank of every new block.
"""
import sys
from collections import defaultdict

ONE_PROP = set([101, 103, 201, 420]) | set(range(301, 310)) | set(range(401, 409)) | {410}
ONE_PROP |= {421, 501, 502, 503, 504, 505, 506}


def read_map(path):
    """{new: (parent, lo, hi, rank)} from the index table."""
    pieces = {}
    for line in open(path):
        f = line.split()
        if len(f) < 13 or not f[0].isdigit():
            continue
        v = [int(x) for x in f[:13]]
        pieces[v[0]] = (v[1], (v[2], v[4], v[6]), (v[3], v[5], v[7]), v[12])
    return pieces


def read_501(path):
    """{(b,i,j,k,f): payload} for the type-501 records of a bc.txt, the payload as a tuple of floats."""
    recs = {}
    with open(path) as fh:
        lines = fh.read().split('\n')
    il, n = 0, len(lines)
    while il < n:
        s = lines[il].split()
        if not s:
            il += 1
            continue
        b, i, j, k, f, t = (int(x) for x in s[:6])
        np_ = 0
        if t in (102, 104):
            n1, n2 = (int(x) for x in lines[il + 1].split()[:2])
            np_ = 1 + n1 + n2
        elif t in ONE_PROP:
            np_ = 1
            if t == 501:
                recs[(b, i, j, k, f)] = tuple(float(x) for x in lines[il + 1].replace(',', ' ').split())
        il += 1 + np_
    return recs


def main(orig_path, split_path, map_path):
    pieces = read_map(map_path)
    orig = read_501(orig_path)
    split = read_501(split_path)
    print(f'{split_path}: {len(split)} manifold records ({len(orig)} in {orig_path})')

    err = 0
    if len(split) != len(orig):
        print(f'  [FAIL] {len(split)} type-501 records after the split, {len(orig)} before')
        err += 1

    bad = 0
    where = defaultdict(set)   # (gid, role) -> {(new block, rank)}
    for (p, i, j, k, f), payload in split.items():
        parent, lo, hi, rank = pieces[p]
        key = (parent, lo[0] + i - 1, lo[1] + j - 1, lo[2] + k - 1, f)
        if key not in orig:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: parent cell {key} carried no manifold record')
            continue
        if payload != orig[key]:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: payload {payload}, the parent cell had {orig[key]}')
            continue
        if len(payload) != 7:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: {len(payload)} payload fields, expected 7 (gid role K rf mdot-ratio p0-ratio dh0)')
            continue
        where[(int(payload[0]), int(payload[1]))].add((p, rank))
    if bad:
        print(f'  [FAIL] {bad} of {len(split)} manifold records wrong')
        err += 1
    elif split:
        print(f'  [ok]   all {len(split)} manifold records copied verbatim from their parent cells')
        for (gid, role), blocks in sorted(where.items()):
            ranks = sorted({r for _, r in blocks})
            print(f'         group {gid} {"outlet" if role == 1 else "inlet "} faces: new blocks '
                  f'{sorted(b for b, _ in blocks)}, ranks {ranks}')

    return err


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    sys.exit(1 if main(*sys.argv[1:]) else 0)
