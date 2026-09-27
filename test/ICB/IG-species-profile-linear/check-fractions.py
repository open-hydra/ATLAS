#!/usr/bin/env python3
"""Analytic check of IG-species-profile-linear (python >= 3.6, standard library only).

The zone of input.ini gives yH2 and yN2 as two-row tables along x and yO2 as a constant:

    yH2 = 0.1 + 0.4 x      (yH2.dat: 0.1 at x = 0, 0.5 at x = 1)
    yO2 = 0.25
    yN2 = 0.65 - 0.4 x     (yN2.dat: 0.65 at x = 0, 0.25 at x = 1)

so that the three mass fractions sum to 1 at every x. The zones of the block are ranged along y and
the profiles run along x; the columns of mesh.tec are unevenly spaced. For every cell of
fromATLAStoSolver/ic.tec, with the centre x of the cell taken from mesh.tec (mean of its four nodes),
this script checks:

  - the mass fractions rho_s / sum(rho) of H2, O2 and N2 against the law above (absolute 1e-12),
    and that the law itself sums to 1;
  - that the density of the cell follows its own composition: sum(rho) * sum_s(y_s / W_s) equals
    p / (Runi T) and is therefore the same in every cell (relative 1e-12; the value of the gas
    constant is not used);
  - p = 100000 and zero velocities.

Nothing is compared with an earlier output of ATLAS. Exit status 0 when every check passes."""
import os
import re
import sys

LAW = {'H2': lambda x: 0.1 + 0.4 * x,
       'O2': lambda x: 0.25,
       'N2': lambda x: 0.65 - 0.4 * x}
P = 100000.0
TOL = 1e-12


def read_tec(path):
    """Tecplot ASCII, one zone, BLOCK packing: variable names, (I, J, K), all numbers in file order."""
    names, dims, nums = None, None, []
    for line in open(path):
        s = line.strip()
        if not s or s.upper().startswith('TITLE'):
            continue
        if s.upper().startswith('VARIABLES'):
            names = [a or b for a, b in re.findall(r'"([^"]*)"|(\S+)', s.split('=', 1)[1])]
            continue
        if s.upper().startswith('ZONE'):
            dims = [int(re.search(r'\b%s\s*=\s*(\d+)' % a, s).group(1)) for a in 'IJK']
            continue
        nums.extend(float(t) for t in s.replace(',', ' ').split())
    return names, dims, nums


def fail(msg):
    print('IG-species-profile-linear: FAIL: ' + msg)
    sys.exit(1)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    rows = [l.split() for l in open(os.path.join(here, 'phase.txt')) if l.strip()][1:]
    species = [(r[0], float(r[1])) for r in rows]
    if sorted(s for s, _ in species) != sorted(LAW):
        fail('phase.txt declares %s, the law is written for %s' % ([s for s, _ in species], sorted(LAW)))

    _, (I, J, K), mesh = read_tec(os.path.join(here, 'mesh.tec'))
    if K != 1:
        fail('mesh.tec is expected to be a pure 2-D block (K = 1), found K = %d' % K)
    nn = I * J
    xm = mesh[:nn]
    ci, cj = I - 1, J - 1
    ncell = ci * cj

    record = os.path.join(here, 'fromATLAStoSolver', 'ic.tec')
    if not os.path.isfile(record):
        fail('no %s' % record)
    names, dims, vals = read_tec(record)
    if dims != [I, J, K]:
        fail('the record has I, J, K = %s, the mesh %s' % (dims, [I, J, K]))
    nvar = len(names) - 2                      # x, y nodal; the rest cell-centred
    ns = len(species)
    if nvar != ns + 3:
        fail('%d cell-centred variables %s, expected %d (one density per species, u, v, p)'
             % (nvar, names[2:], ns + 3))
    if len(vals) != 2 * nn + nvar * ncell:
        fail('%d numbers in the record, expected %d' % (len(vals), 2 * nn + nvar * ncell))
    for n in range(2 * nn):
        if abs(vals[n] - mesh[n]) > TOL:
            fail('node %d of the record is not the node of mesh.tec (%r, %r)' % (n, vals[n], mesh[n]))
    band = [vals[2 * nn + v * ncell: 2 * nn + (v + 1) * ncell] for v in range(nvar)]

    worst_y, rhoR, xcs = 0.0, [], []
    for j in range(cj):
        for i in range(ci):
            c = i + ci * j
            xc = (xm[i + I * j] + xm[i + 1 + I * j] + xm[i + I * (j + 1)] + xm[i + 1 + I * (j + 1)]) / 4.0
            xcs.append(xc)
            exact = [LAW[s](xc) for s, _ in species]
            if abs(sum(exact) - 1.0) > 1e-14:
                fail('the law sums to %r at x = %r' % (sum(exact), xc))
            rho_s = [band[s][c] for s in range(ns)]
            rho = sum(rho_s)
            if not rho > 0.0:
                fail('cell (%d,%d): density %r' % (i + 1, j + 1, rho))
            for s, (name, _) in enumerate(species):
                d = abs(rho_s[s] / rho - exact[s])
                worst_y = max(worst_y, d)
                if d > TOL:
                    fail('cell (%d,%d), x = %r: y%s = %r, the law gives %r'
                         % (i + 1, j + 1, xc, name, rho_s[s] / rho, exact[s]))
            rhoR.append(rho * sum(exact[s] / w for s, (_, w) in enumerate(species)))
            u, v, p = band[ns][c], band[ns + 1][c], band[ns + 2][c]
            if abs(u) > TOL or abs(v) > TOL or abs(p - P) > TOL * P:
                fail('cell (%d,%d): u, v, p = %r, %r, %r; expected 0, 0, %r' % (i + 1, j + 1, u, v, p, P))
    if max(xcs) - min(xcs) < 0.5:
        fail('the cell centres span %r along x: the profile would not be exercised' % (max(xcs) - min(xcs)))
    spread = (max(rhoR) - min(rhoR)) / max(rhoR)
    if spread > TOL:
        fail('sum(rho) * sum(y/W) varies by %.3e between cells: the density does not follow the composition'
             ' of its own cell' % spread)
    print('IG-species-profile-linear: %d cells, yH2 from %.4f to %.4f, max |y - law| = %.2e, '
          'spread of sum(rho) * sum(y/W) = %.2e: OK'
          % (ncell, LAW['H2'](min(xcs)), LAW['H2'](max(xcs)), worst_y, spread))
    return 0


if __name__ == '__main__':
    sys.exit(main())
