#!/usr/bin/env python3
"""Verify the type-103/104 (inter-phase) records of a coupled ATLAS case.

The invariant is exact reciprocity, and it does not depend on how either phase
was decomposed: if phase A has a 103 record on cell (bA,iA,jA,kA) face fA whose
donor is (bB,iB,jB,kB) face fB, then phase B must carry a 103 record on
(bB,iB,jB,kB) face fB whose donor is (bA,iA,jA,kA) face fA.

A donor remapped against the wrong phase's decomposition breaks this at once --
usually by naming a block the other phase does not have.

A type-104 record (inter-phase chimera) is not reciprocal cell by cell: its
donors are volume-weighted cells of the other phase. Each of them must lie
inside a block of the other phase (ghost layers allowed, as in check-bc.py).
"""
import sys, collections

def read_103(path):
    """-> {(b,i,j,k,f): (db,di,dj,dk,df)}, the total record count,
    [(b,i,j,k,f, (db,di,dj,dk))] for every type-104 donor and {b: [ni,nj,nk]}."""
    recs, total, xdon = {}, 0, []
    dims = collections.defaultdict(lambda: [0, 0, 0])
    with open(path) as fh:
        lines = fh.readlines()
    n = 0
    while n < len(lines):
        p = lines[n].split()
        # A header is exactly six integers: b i j k f type
        if len(p) == 6 and all(x.lstrip('-').isdigit() for x in p):
            total += 1
            h = tuple(int(x) for x in p[:5])
            d = dims[h[0]]
            d[0] = max(d[0], h[1]); d[1] = max(d[1], h[2]); d[2] = max(d[2], h[3])
            if int(p[5]) == 103:
                d = lines[n+1].split()
                recs[h] = tuple(int(x) for x in d[:5])
            elif int(p[5]) == 104:
                n1, n2 = (int(x) for x in lines[n+1].split())
                for c in range(n1 + n2):
                    d = lines[n+2+c].split()
                    xdon.append((h, tuple(int(x) for x in d[:4])))
                n += 1 + n1 + n2
        n += 1
    return recs, total, xdon, dims

def check_104(tag, xdon, dims_other):
    """Donors of this side's type-104 records that miss the other phase's blocks."""
    bad = []
    for key, (db, di, dj, dk) in xdon:
        if db not in dims_other:
            bad.append(f"{tag}{key} -> chimera donor {(db,di,dj,dk)}: block {db} does not "
                       f"exist in the other phase (has {sorted(dims_other)})")
            continue
        ni, nj, nk = dims_other[db]
        if not (-1 <= di <= ni + 2 and -1 <= dj <= nj + 2 and -1 <= dk <= nk + 2):
            bad.append(f"{tag}{key} -> chimera donor {(db,di,dj,dk)}: outside block {db} "
                       f"{(ni,nj,nk)} of the other phase")
    return bad

def main(fa, fb):
    A, ta, xa, dims_a = read_103(fa)
    B, tb, xb, dims_b = read_103(fb)
    print(f"  {fa}: {len(A)} type-103 of {ta} records, {len(xa)} type-104 donors")
    print(f"  {fb}: {len(B)} type-103 of {tb} records, {len(xb)} type-104 donors")

    bad = []
    if len(A) != len(B):
        bad.append(f"record counts differ: {len(A)} vs {len(B)}")

    blocks_b = {k[0] for k in B}
    blocks_a = {k[0] for k in A}

    for key, don in A.items():
        if don not in B:
            reason = ("donor block %d does not exist in the other phase (has %s)"
                      % (don[0], sorted(blocks_b))) if don[0] not in blocks_b \
                     else "no matching record on the other side"
            bad.append(f"A{key} -> {don}: {reason}")
            continue
        if B[don] != key:
            bad.append(f"A{key} -> {don}, but B{don} -> {B[don]} (not reciprocal)")
    for key, don in B.items():
        if don not in A:
            reason = ("donor block %d does not exist in the other phase (has %s)"
                      % (don[0], sorted(blocks_a))) if don[0] not in blocks_a \
                     else "no matching record on the other side"
            bad.append(f"B{key} -> {don}: {reason}")

    bad += check_104("A", xa, dims_b)
    bad += check_104("B", xb, dims_a)

    if bad:
        print(f"  FAIL: {len(bad)} problem(s); first 8:")
        for b in bad[:8]:
            print("    " + b)
        return 1
    print(f"  PASS: {len(A)} interface pairs, all reciprocal; "
          f"{len(xa) + len(xb)} chimera donors inside the other phase")
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
