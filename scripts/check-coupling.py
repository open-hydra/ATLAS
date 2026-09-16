#!/usr/bin/env python3
"""Verify the type-103 (fluid-solid interface) records of a coupled ATLAS case.

The invariant is exact reciprocity, and it does not depend on how either phase
was decomposed: if phase A has a 103 record on cell (bA,iA,jA,kA) face fA whose
donor is (bB,iB,jB,kB) face fB, then phase B must carry a 103 record on
(bB,iB,jB,kB) face fB whose donor is (bA,iA,jA,kA) face fA.

A donor remapped against the wrong phase's decomposition breaks this at once --
usually by naming a block the other phase does not have.
"""
import sys, collections

def read_103(path):
    """-> {(b,i,j,k,f): (db,di,dj,dk,df)} plus the total record count."""
    recs, total = {}, 0
    with open(path) as fh:
        lines = fh.readlines()
    n = 0
    while n < len(lines):
        p = lines[n].split()
        # A header is exactly six integers: b i j k f type
        if len(p) == 6 and all(x.lstrip('-').isdigit() for x in p):
            total += 1
            if int(p[5]) == 103:
                d = lines[n+1].split()
                recs[tuple(int(x) for x in p[:5])] = tuple(int(x) for x in d[:5])
        n += 1
    return recs, total

def main(fa, fb):
    A, ta = read_103(fa)
    B, tb = read_103(fb)
    print(f"  {fa}: {len(A)} type-103 of {ta} records")
    print(f"  {fb}: {len(B)} type-103 of {tb} records")

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

    if bad:
        print(f"  FAIL: {len(bad)} problem(s); first 8:")
        for b in bad[:8]:
            print("    " + b)
        return 1
    print(f"  PASS: {len(A)} interface pairs, all reciprocal")
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
