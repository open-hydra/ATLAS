#!/usr/bin/env python3
"""Verify an MDB decomposition against the grid it was built from.

MDB's split is meant to be exact: the node planes on a cut are duplicated into
both neighbours, cell data is partitioned without duplication, and nothing is
interpolated -- so every value of the split file must be a value of the original
file, at the place the decomposition map says it came from.

  ./check-split.py <original grid> <split grid> <decomposition.map>

  * one zone per map record, with the dimensions the map records
  * cells conserved: no cell lost, none duplicated
  * nodal variables equal the parent's nodes over [lo-1 : hi]
  * cell-centred variables equal the parent's cells over [lo : hi]

Tecplot ASCII (DATAPACKING=BLOCK) only; the binary path is the same code in
MDB, so checking one format checks both.
"""
import re
import sys


def _is_number(tok):
    try:
        float(tok)
        return True
    except ValueError:
        return False


def read_tec(path):
    """[{ni,nj,nk (nodes), loc[v], data[v]}] for an ordered BLOCK-packed file."""
    with open(path) as fh:
        lines = fh.read().split('\n')

    nvar = 0
    for line in lines:
        if 'VARIABLES' in line.upper():
            names = line.split('=', 1)[1]
            nvar = len(names.replace('"', ' ').replace(',', ' ').split())
            break
    if nvar == 0:
        sys.exit(f'{path}: no VARIABLES line')

    zones = []
    il, n = 0, len(lines)
    while il < n:
        if 'ZONE' not in lines[il].upper():
            il += 1
            continue

        # The header may be spread over several lines; it ends at the first
        # line whose first token is a number.
        header = lines[il]
        il += 1
        while il < n:
            tok = lines[il].split()
            if not tok or _is_number(tok[0]):
                break
            header += ' ' + lines[il]
            il += 1

        dims = []
        for key in ('I', 'J', 'K'):
            m = re.search(r'\b%s\s*=\s*(\d+)' % key, header)
            dims.append(int(m.group(1)) if m else 1)
        ni, nj, nk = dims

        loc = ['NODAL'] * nvar
        for m in re.finditer(r'\[\s*(\d+)\s*(?:-\s*(\d+))?\s*\]\s*=\s*(\w+)', header):
            lo = int(m.group(1))
            hi = int(m.group(2) or m.group(1))
            for v in range(lo, hi + 1):
                if 1 <= v <= nvar:
                    loc[v - 1] = m.group(3).upper()

        npoint = ni * nj * nk
        ncell = max(ni - 1, 1) * max(nj - 1, 1) * max(nk - 1, 1)
        want = sum(npoint if l == 'NODAL' else ncell for l in loc)

        vals = []
        while il < n and len(vals) < want:
            vals.extend(float(t) for t in lines[il].split())
            il += 1
        if len(vals) != want:
            sys.exit(f'{path}: zone {len(zones)+1} has {len(vals)} values, expected {want}')

        data, off = [], 0
        for v in range(nvar):
            size = npoint if loc[v] == 'NODAL' else ncell
            data.append(vals[off:off + size])
            off += size

        zones.append(dict(ni=ni, nj=nj, nk=nk, loc=loc, data=data))

    return zones


def read_map(path):
    """[(parent, lo(3), hi(3))] in new-block order, from the index table."""
    rows = []
    for line in open(path):
        f = line.split()
        if len(f) < 12 or not all(_is_number(x) for x in f[:12]):
            continue          # comment, blank, or the face-origin table
        v = [int(x) for x in f[:12]]
        rows.append((v[1], (v[2], v[4], v[6]), (v[3], v[5], v[7])))
    return rows


def at(arr, i, j, k, ni, nj):
    """value of a BLOCK-packed array at 0-based (i,j,k), i fastest."""
    return arr[i + ni * (j + nj * k)]


def main(orig_path, split_path, map_path):
    orig = read_tec(orig_path)
    split = read_tec(split_path)
    pieces = read_map(map_path)
    print(f'{split_path}: {len(split)} blocks from {len(orig)} in {orig_path}')

    err = 0

    if len(split) != len(pieces):
        print(f'  [FAIL] {len(split)} zones but {len(pieces)} records in {map_path}')
        return 1

    # ---- dimensions -------------------------------------------------------
    bad = 0
    for p, (b, lo, hi) in enumerate(pieces):
        z = split[p]
        want = tuple(hi[d] - lo[d] + 2 for d in range(3))
        if (z['ni'], z['nj'], z['nk']) != want:
            bad += 1
            if bad < 4:
                print(f'  [FAIL] block {p+1}: {(z["ni"], z["nj"], z["nk"])} nodes, '
                      f'map says {want}')
    if bad:
        print(f'  [FAIL] {bad} blocks do not have the dimensions of their map record')
        err += 1
    else:
        print(f'  [ok]   all {len(split)} blocks have the dimensions of their map record')

    # ---- cell conservation ------------------------------------------------
    ncell_orig = sum(max(z['ni'] - 1, 1) * max(z['nj'] - 1, 1) * max(z['nk'] - 1, 1)
                     for z in orig)
    ncell_split = sum(max(z['ni'] - 1, 1) * max(z['nj'] - 1, 1) * max(z['nk'] - 1, 1)
                      for z in split)
    if ncell_orig != ncell_split:
        print(f'  [FAIL] {ncell_split} cells after the split, {ncell_orig} before')
        err += 1
    else:
        print(f'  [ok]   {ncell_split} cells conserved')

    # every parent cell covered exactly once
    covered = {}
    for b, lo, hi in pieces:
        for k in range(lo[2], hi[2] + 1):
            for j in range(lo[1], hi[1] + 1):
                for i in range(lo[0], hi[0] + 1):
                    key = (b, i, j, k)
                    covered[key] = covered.get(key, 0) + 1
    dup = sum(1 for c in covered.values() if c > 1)
    if dup or len(covered) != ncell_orig:
        print(f'  [FAIL] {dup} cells claimed twice, {ncell_orig - len(covered)} not claimed')
        err += 1
    else:
        print(f'  [ok]   every parent cell claimed by exactly one block')

    if err:
        return err

    # ---- values -----------------------------------------------------------
    nvar = len(split[0]['data'])
    worst = 0.0
    bad = 0
    for p, (b, lo, hi) in enumerate(pieces):
        z, o = split[p], orig[b - 1]
        # cells lo..hi are bounded by nodes lo-1..hi, so both the nodal and the
        # cell-centred arrays of the piece start at the same 0-based offset
        i0, j0, k0 = lo[0] - 1, lo[1] - 1, lo[2] - 1
        for v in range(nvar):
            nodal = z['loc'][v] == 'NODAL'
            ei = z['ni'] if nodal else z['ni'] - 1
            ej = z['nj'] if nodal else z['nj'] - 1
            ek = z['nk'] if nodal else z['nk'] - 1
            oi = o['ni'] if nodal else o['ni'] - 1
            oj = o['nj'] if nodal else o['nj'] - 1
            for k in range(ek):
                for j in range(ej):
                    for i in range(ei):
                        a = at(z['data'][v], i, j, k, ei, ej)
                        c = at(o['data'][v], i0 + i, j0 + j, k0 + k, oi, oj)
                        if a != c:
                            bad += 1
                            worst = max(worst, abs(a - c))
                            if bad < 4:
                                print(f'  [FAIL] block {p+1} var {v+1} at {(i,j,k)}: '
                                      f'{a!r} != {c!r} of parent {b}')
    if bad:
        print(f'  [FAIL] {bad} values differ from the parent grid (max |diff| {worst:g})')
        err += 1
    else:
        print(f'  [ok]   all {nvar} variables identical to the parent grid')

    return err


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    sys.exit(1 if main(*sys.argv[1:4]) else 0)
