#!/usr/bin/env python3
"""Verify the manifold (type-501) records of a decomposed MOSE bc.txt.

  ./check-manifold.py <original bc.txt> <split bc.txt> <decomposition.map>

A 501 payload names a whole source block face, not a cell: MOSE's BC_Manifold
averages the state over the entire source face and scales the mass flux by the
entire target face, and MOSE aborts at start-up when the two blocks sit on
different ranks (abort_if_split). So, for every 501 record of the split file:

  * the target face of the new block is the parent's face entire
  * the source names the new block that inherited the original source face
    entire, with the same face index
  * the map puts the two new blocks on the same rank

The original file supplies the source the record had before the split; the map
supplies the parent, the index range and the rank of every new block.
"""
import sys
from collections import defaultdict

ONE_PROP = set([101, 103, 201, 420]) | set(range(301, 310)) | set(range(401, 409)) | {410}
ONE_PROP |= {421, 501, 502, 503, 504, 505, 506}


def read_map(path):
    """{new: (parent, lo, hi, rank)} and {parent: (ni, nj, nk)} from the index table."""
    pieces, ext = {}, {}
    for line in open(path):
        f = line.split()
        if len(f) < 13 or not f[0].isdigit():
            continue
        v = [int(x) for x in f[:13]]
        pieces[v[0]] = (v[1], (v[2], v[4], v[6]), (v[3], v[5], v[7]), v[12])
        e = ext.setdefault(v[1], [0, 0, 0])
        e[0] = max(e[0], v[3]); e[1] = max(e[1], v[5]); e[2] = max(e[2], v[7])
    return pieces, {b: tuple(e) for b, e in ext.items()}


def read_501(path):
    """{(b,i,j,k,f): (bs, fs)} for the type-501 records of a bc.txt."""
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
            n1, n2 = (int(x) for x in lines[il + 1].split())
            np_ = 1 + n1 + n2
        elif t in ONE_PROP:
            np_ = 1
            if t == 501:
                bs, fs = (int(x) for x in lines[il + 1].replace(',', ' ').split()[:2])
                recs[(b, i, j, k, f)] = (bs, fs)
        il += 1 + np_
    return recs


def face_dir(f):
    return (f + 1) // 2 - 1


def whole_face(piece, dims, f):
    """The piece holds the parent's face f entire."""
    parent, lo, hi, _ = piece
    d = face_dir(f)
    if f % 2 == 1 and lo[d] != 1:
        return False
    if f % 2 == 0 and hi[d] != dims[parent][d]:
        return False
    return all(lo[t] == 1 and hi[t] == dims[parent][t] for t in range(3) if t != d)


def main(orig_path, split_path, map_path):
    pieces, dims = read_map(map_path)
    orig = read_501(orig_path)
    split = read_501(split_path)
    print(f'{split_path}: {len(split)} manifold records ({len(orig)} in {orig_path})')

    err = 0
    if len(split) != len(orig):
        print(f'  [FAIL] {len(split)} type-501 records after the split, {len(orig)} before')
        err += 1

    # the new block that inherited each parent face entire
    face_piece = {}
    for p, piece in pieces.items():
        for f in range(1, 7):
            if whole_face(piece, dims, f):
                face_piece[(piece[0], f)] = p

    bad = 0
    for (p, i, j, k, f), (bs, fs) in split.items():
        parent, lo, hi, rank = pieces[p]
        key = (parent, lo[0] + i - 1, lo[1] + j - 1, lo[2] + k - 1, f)
        if key not in orig:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: parent cell {key} carried no manifold record')
            continue
        bs0, fs0 = orig[key]
        if not whole_face(pieces[p], dims, f):
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: the target face is cut across new blocks')
            continue
        want = face_piece.get((bs0, fs0))
        if want is None:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: source face {(bs0,fs0)} is cut across new blocks')
            continue
        if (bs, fs) != (want, fs0):
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)}: source {(bs,fs)}, expected {(want,fs0)} '
                      f'(parent face {(bs0,fs0)})')
            continue
        if pieces[bs][3] != rank:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] {(p,i,j,k,f)} on rank {rank} draws from block {bs} on rank '
                      f'{pieces[bs][3]}: MOSE aborts at start-up')
    if bad:
        print(f'  [FAIL] {bad} of {len(split)} manifold records wrong')
        err += 1
    elif split:
        print(f'  [ok]   all {len(split)} manifold records name a whole source face on the same rank')

    return err


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    sys.exit(1 if main(*sys.argv[1:4]) else 0)
