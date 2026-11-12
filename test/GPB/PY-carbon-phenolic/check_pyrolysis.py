#!/usr/bin/env python3
"""PY-carbon-phenolic: the pyrolysis-gas tables of GPB held to identities and to an independent engine.

    check_pyrolysis.py <name>pyrolysis.dat <name>phase.txt

1. grammar of the table file (brief 3.2): counts, strictly ascending grids, np*nT rows of nsp values, condensed 0;
2. every row sums to 1 within 1e-10 (identity);
3. gas-only: the element mass fractions of every row equal the `elements` line within 1e-10 (identity; molar masses of
   phase.txt, compositions of nasa9.yaml, Cantera's atomic weights);
4. the other engine: a gas-only row against the cea binding at the same (p, T) [the table comes from Cantera], a strip
   row against Cantera with graphite as a phase of zero molar volume [the table comes from cea], the gas-only check on
   the standard state P_REF, the strip check on P_REF_STRIP; |dy| <= 1e-6 (measured agreement on the user's 418-point
   grid: 2.9e-8 gas-only, 8.6e-9 strip);
5. the numbers of brief section 4 at the points the grid holds, restated for P_REF (plan, DECISION D-A1), within half
   a unit of their third decimal.
"""
import os
import sys

import numpy as np
import cantera as ct

P_REF = 1.0e5            # DECISION D-A1: standard state of the gas-only table, 1.0e5 (branch B, CEA's) or 101325.0 (branch A)
P_REF_STRIP = 1.0e5      # the strip table comes from cea, on 1 bar in both D-A1 branches
TOL_ID = 1.0e-10
TOL_ENGINE = 1.0e-6
TOL_PRINTED = 0.5e-3 + 1.0e-12
# brief section 4 restated for P_REF = 1e5 (plan A0, spike_engines.out, columns ct1bar = cea): CO H2 C2H2 C2H4
EXPECTED_GAS = {(1e5, 2000.0): (0.496, 0.074, 0.429, 0.002), (1e5, 2500.0): (0.496, 0.072, 0.430, 0.000),
                (4e6, 1500.0): (0.496, 0.046, 0.076, 0.381), (4e6, 2000.0): (0.496, 0.070, 0.378, 0.056),
                (4e6, 2500.0): (0.496, 0.073, 0.424, 0.007), (4e6, 3000.0): (0.496, 0.072, 0.429, 0.002),
                (6.1e6, 2500.0): (0.496, 0.073, 0.420, 0.010)}
# X_C is not in the table; CO H2 H2O C2H2 of the renormalised gas
EXPECTED_STRIP = {(1e5, 2000.0): (0.821, 0.177, 0.000, 0.002), (4e6, 2000.0): (0.819, 0.177, 0.002, 0.002),
                  (4e6, 2500.0): (0.803, 0.171, 0.000, 0.024), (4e6, 3000.0): (0.732, 0.147, 0.000, 0.118)}
GAS_KEYS, STRIP_KEYS = ('CO', 'H2', 'C2H2,acetylene', 'C2H4'), ('CO', 'H2', 'H2O', 'C2H2,acetylene')

bad = 0


def fail(msg):
    global bad
    bad += 1
    print('[FAIL] ' + msg)


def parse(path):
    lines = [ln.strip() for ln in open(path).read().split('\n')]
    lines = [ln for ln in lines if ln and not ln.startswith('#')]
    it = iter(lines)

    def expect(word):
        t = next(it).split()
        if t[0] != word:
            raise ValueError(f"expected '{word}', read '{' '.join(t)}'")
        return t[1:]

    if expect('format') != ['1']:
        raise ValueError('format is not 1')
    tables = []
    for _ in range(int(expect('tables')[0])):
        t = {'name': expect('table')[0], 'treatment': expect('treatment')[0]}
        el = expect('elements')
        nel = int(el[0])
        t['elements'] = {el[1 + 2 * i]: float(el[2 + 2 * i]) for i in range(nel)}
        t['condensed'] = int(expect('condensed')[0])
        t['species'] = [next(it) for _ in range(int(expect('species')[0]))]
        n = int(expect('pressures')[0])
        vals = []
        while len(vals) < n:
            vals += [float(v) for v in next(it).split()]
        t['p'] = vals
        n = int(expect('temperatures')[0])
        vals = []
        while len(vals) < n:
            vals += [float(v) for v in next(it).split()]
        t['T'] = vals
        expect('data')
        t['rows'] = np.array([[float(v) for v in next(it).split()] for _ in range(len(t['p']) * len(t['T']))])
        if next(it) != 'end table':
            raise ValueError(f"table {t['name']}: no 'end table' after {len(t['rows'])} rows")
        tables.append(t)
    return tables


def main(table_path, phase_path):
    tables = parse(table_path)
    M = {ln.split()[0]: float(ln.split()[1]) for ln in open(phase_path).read().split('\n')[1:] if ln.strip()}
    db = {s.name: s for s in ct.Species.list_from_file(os.path.join(os.environ['ATLASDIR'], 'database', 'thermo', 'nasa9.yaml'))}
    for t in tables:
        name, sp, rows = t['name'], t['species'], t['rows']
        if t['condensed'] != 0 or t['treatment'] not in ('gas-only', 'strip'):
            fail(f"{name}: condensed {t['condensed']}, treatment {t['treatment']}")
        if any(b <= a for a, b in zip(t['p'], t['p'][1:])) or any(b <= a for a, b in zip(t['T'], t['T'][1:])) or len(t['T']) < 2:
            fail(f'{name}: grids not strictly ascending or fewer than two temperatures')
        if rows.shape[1] != len(sp):
            fail(f'{name}: rows of {rows.shape[1]} values for {len(sp)} species')
        if abs(sum(t['elements'].values()) - 1.0) > TOL_ID:
            fail(f"{name}: elements line sums to {sum(t['elements'].values())!r}")
        dsum = np.abs(rows.sum(axis=1) - 1.0).max()
        print(f'{name}: {len(t["p"])} x {len(t["T"])} rows, {len(sp)} species; max |sum(y) - 1| = {dsum:.2e}')
        if dsum > TOL_ID:
            fail(f'{name}: a row sums to 1 within {dsum:.2e} > {TOL_ID}')
        W = {e: ct.Element(e).weight for e in t['elements']}
        comp = np.array([[db[s].composition.get(e, 0.0) * W[e] / M[s] for s in sp] for e in t['elements']])
        if t['treatment'] == 'gas-only':
            dev = np.abs(rows @ comp.T - np.array(list(t['elements'].values()))).max()
            print(f'{name}: max |element mass fraction - makeup| = {dev:.2e}')
            if dev > TOL_ID:
                fail(f'{name}: elements of a row differ from the makeup by {dev:.2e} > {TOL_ID}')
        ref = other_engine(t, db, M)
        diff = np.abs(rows - ref).max()
        print(f'{name}: max |y - other engine| = {diff:.2e}')
        if diff > TOL_ENGINE:
            fail(f'{name}: the table differs from the other engine by {diff:.2e} > {TOL_ENGINE}')
        exp, keys = (EXPECTED_GAS, GAS_KEYS) if t['treatment'] == 'gas-only' else (EXPECTED_STRIP, STRIP_KEYS)
        worst, n = 0.0, 0
        for (p, T), vals in exp.items():
            if vals is None or p not in t['p'] or T not in t['T']:
                continue
            row = rows[t['p'].index(p) * len(t['T']) + t['T'].index(T)]
            for k, v in zip(keys, vals):
                worst = max(worst, abs(row[sp.index(k)] - v))
                n += 1
        print(f'{name}: brief section 4 restated, {n} values: max |y - printed| = {worst:.5f} (tolerance {TOL_PRINTED:.4g})')
        if n == 0 or worst > TOL_PRINTED:
            fail(f'{name}: section 4 numbers ({n} compared, worst {worst:.5f})')
    print('[PASS]' if bad == 0 else f'[FAIL] {bad} check(s)')
    return 1 if bad else 0


def other_engine(t, db, M):
    els, w = list(t['elements']), list(t['elements'].values())
    b = {e: x / ct.Element(e).weight for e, x in zip(els, w)}
    sp = t['species']
    out = []
    if t['treatment'] == 'gas-only':
        import cea
        reac = cea.Mixture([cea.Reactant('PYRO', formula={e.upper(): b[e] for e in els})])
        prod = cea.Mixture(sp)
        solver = cea.EqSolver(prod, reactants=reac)
        order = list(prod.species_names)
        for p in t['p']:
            for T in t['T']:
                sol = cea.EqSolution(solver)
                solver.solve(sol, cea.TP, T, p * 1.0e-5 * (1.0e5 / P_REF), np.array([1.0]))
                if not sol.converged:
                    raise RuntimeError(f'cea did not converge at {p} Pa, {T} K')
                m = {n: sol.nj[i] * M[n] for i, n in enumerate(order)}
                s = sum(m.values())
                out.append([m[n] / s for n in sp])
        return np.array(out)
    def pref(s):
        d = dict(s.input_data)
        th = dict(d['thermo'])
        th['reference-pressure'] = P_REF_STRIP
        d['thermo'] = th
        return ct.Species.from_dict(d)
    gas = ct.Solution(thermo='ideal-gas', species=[pref(db[n]) for n in sp])
    d = dict(pref(db['C(gr)']).input_data)
    d['equation-of-state'] = {'model': 'constant-volume', 'density': '1e12 g/cm^3'}   # no p*v term, as CEA
    gr = ct.Solution(thermo='fixed-stoichiometry', species=[ct.Species.from_dict(d)])
    seed = {'CO': b['O'], 'H2': b['H'] / 2.0}
    for p in t['p']:
        for T in t['T']:
            gas.TPX = T, p, seed
            gr.TP = T, p
            mix = ct.Mixture([(gas, b['O'] + b['H'] / 2.0), (gr, b['C'] - b['O'])])
            mix.T, mix.P = T, p
            mix.equilibrate('TP', solver='gibbs', max_steps=5000, rtol=1e-10)
            out.append(list(gas.Y))
    return np.array(out)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
