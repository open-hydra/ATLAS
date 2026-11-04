#!/usr/bin/env python3
"""Check the CEA transport tables of GPB below and above the intervals of a record (src/GPB/cea_transport_rule.py) and the intervals
that ATLAS adds to database/transport/CEApolynomials.yaml (those with a `source` key of their own), without Cantera.

1. Every ATLAS interval increases strictly: the minimum of its logarithmic slope q(x) = A - B x - 2 C x^2, x = 1/T, over the interval
   is positive; the minimum of a polynomial of degree two is at an end or at the vertex x = -B/(4C), so three values decide it.
2. Every junction between two intervals of a property where one is an ATLAS interval is continuous in ln p and in slope within the
   error of the double precision evaluation: |d ln p| <= 13 eps (S_below + S_above) + 8 eps |A_below - A_above| |ln Tj| and
   |d slope| <= 13 eps (G_below + G_above), with S = |A ln T| + |B/T| + |C/T^2| + |D| and G = |A| + |B/T| + |2C/T^2| of each side;
   the second term of the first bound covers a logarithm of Tj that differs by up to 4 units in the last place from the one used to
   write the coefficients, and np.log(Tj) is checked here against a 40-digit logarithm (decimal). The coefficients of the ATLAS
   intervals are four finite floats.
3. The ATLAS intervals reproduce their references within THRESHOLD: Lemmon and Jacobsen (2004), dilute gas, Eq. (2) and (5) with their
   Tables I, II and IV (N2, O2, Ar), on a 1 K grid from the lowest ATLAS bound to 200 K plus the bound itself; Bich, Millat and Vogel
   (1990), Tables 5, 6 and 8 (He, Ne, Kr), at the points of bich1990_dilute_gas.csv.
4. Every record of the database, rows from 1 K to the lowest NASA bound with the specific heat of database/thermo/nasa9.yaml held at the
   bound of its range: positive and finite; strictly increasing after the .12f format of transport.dat, except where the viscosity of a
   record does not increase at its lowest bound (n <= 0), where the viscosity keeps the value of the bound and the rule returns its
   information line; the Prandtl number mu cp/k is constant below the lowest conductivity bound. No record of the database stops the rule
   on the default table, 1 K to 5000 K.
5. The rule on records built here: the three forms below the lowest viscosity bound against their formulas, with the value and the slope
   at the bound; the Prandtl number below the lowest conductivity bound with a specific heat that changes with T; different bounds for
   viscosity and conductivity; the records that stop GPB, each with its message; the malformed records handled without a stop.
Exit status 1 on any failure.   Usage: cea_transport_low_temperature_check.py <ATLAS directory>   (Python >= 3.6, numpy, PyYAML)
"""
import csv
import decimal
import math
import os
import sys

try:
    import numpy as np
    import yaml
except ImportError as e:
    sys.exit('cea_transport_low_temperature_check: %s (run with ATLAS_PYTHON = the ATLAS conda interpreter)' % e)

ATLAS = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('ATLASDIR', '')
sys.path.insert(0, os.path.join(ATLAS, 'src', 'GPB'))
from cea_transport_records import index_records, RecordError  # noqa: E402
from cea_transport_rule import cea_table, ln_property, dln_property  # noqa: E402

SOURCE = 'database/transport/CEApolynomials.yaml'
EPS = 2.0 ** -52
failures = []


def check(ok, text):
    print(('PASS ' if ok else 'FAIL ') + text)
    if not ok:
        failures.append(text)


def atlas_interval(it):
    return isinstance(it, dict) and 'source' in it


# ---- references ------------------------------------------------------------------------------------------------------------------
# Lemmon and Jacobsen, Int. J. Thermophys. 25, 21 (2004): Eq. (2), eta0 = 0.0266958 sqrt(M T)/(sigma^2 Omega(T*)) in uPa s, with
# ln Omega = sum b_i (ln T*)^i, T* = T/(eps/k) (Table II); Eq. (5), lambda0 = N1 eta0/(uPa s) + N2 tau^t2 + N3 tau^t3 in mW/(m K),
# tau = Tc/T. Table I gives M [g/mol], eps/k [K], sigma [nm], Tc [K]; Table IV gives N1, N2, t2, N3, t3.
LJ_B = (0.431, -0.4623, 0.08406, 0.005341, -0.00331)
LJ = {'N2': (28.01348, 98.94, 0.3656, 126.192, 1.511, 2.117, -1.0, -3.332, -0.7),
      'O2': (31.9988, 118.5, 0.3428, 154.581, 1.036, 6.283, -0.9, -4.262, -0.6),
      'Ar': (39.948, 143.2, 0.335, 150.687, 0.8158, -0.4320, -0.77, 0.0, -1.0)}


def lj_eta0(sp, T):
    M, ek, s = LJ[sp][:3]
    x = math.log(T / ek)
    return 0.0266958 * math.sqrt(M * T) / (s * s * math.exp(sum(b * x ** i for i, b in enumerate(LJ_B)))) * 1e-6   # Pa s


def lj_lambda0(sp, T):
    Tc, N1, N2, t2, N3, t3 = LJ[sp][3:]
    tau = Tc / T
    return (N1 * lj_eta0(sp, T) * 1e6 + N2 * tau ** t2 + N3 * tau ** t3) * 1e-3   # W/(m K)


def bich_points(sp):
    with open(os.path.join(ATLAS, 'test', 'tools', 'bich1990_dilute_gas.csv')) as f:
        rows = [r for r in csv.DictReader(line for line in f if not line.startswith('#')) if r['species'] == sp]
    return [(float(r['T_K']), float(r['viscosity_uPa_s']) * 1e-6, float(r['conductivity_mW_m_K']) * 1e-3) for r in rows]


# Largest relative deviation [%] of an ATLAS fit from its reference: the deviation measured when the fit was made, rounded up to 0.1 %.
# Each bound is at or below the uncertainty the reference declares (Lemmon and Jacobsen: viscosity 0.5 % for N2 and Ar, 5 % for O2
# below 200 K, conductivity 2 %; Bich, Millat and Vogel, Table 4: 1.0 % to 2.0 % at the lowest temperatures, 0.5 % from about 100 K),
# except where the NASA interval that the fit joins at 200 K deviates more from the reference there: Ar viscosity (NASA -0.55 % at
# 200 K), N2 conductivity (+1.92 %) and Kr conductivity (+0.82 %).
THRESHOLD = {('N2', 'viscosity'): 0.3, ('N2', 'conductivity'): 2.0, ('O2', 'viscosity'): 0.3, ('O2', 'conductivity'): 0.5,
             ('Ar', 'viscosity'): 0.7, ('Ar', 'conductivity'): 0.5, ('He', 'viscosity'): 0.3, ('He', 'conductivity'): 0.4,
             ('Ne', 'viscosity'): 0.2, ('Ne', 'conductivity'): 0.2, ('Kr', 'viscosity'): 0.2, ('Kr', 'conductivity'): 0.9}


# ---- thermo of nasa9.yaml (the default thermo database of GPB), read without Cantera ----------------------------------------------
class _NoBool(yaml.SafeLoader):
    """nasa9.yaml writes '- name: NO' without quotes, which YAML 1.1 reads as false: the loader without the boolean resolver."""


_NoBool.yaml_implicit_resolvers = {k: [(t, r) for t, r in v if t != 'tag:yaml.org,2002:bool']
                                   for k, v in yaml.SafeLoader.yaml_implicit_resolvers.items()}
# H2ONassini and H2OFrolov are the water polynomials under the names that the mechanism files Nassini.yaml and Frolov.yaml give to water
THERMO_NAME = {'H2ONassini': 'H2O', 'H2OFrolov': 'H2O'}


def nasa9_cp(thermo):
    """cp/R of a NASA9 record, held at the bound of its range outside it, as thermo.py holds cp."""
    Tr, data = thermo['temperature-ranges'], thermo['data']

    def cp(T):
        T = min(max(T, Tr[0]), Tr[-1])
        i = max(j for j in range(len(Tr) - 1) if Tr[j] <= T)
        a = data[min(i, len(data) - 1)]
        return a[0] / T ** 2 + a[1] / T + a[2] + a[3] * T + a[4] * T ** 2 + a[5] * T ** 3 + a[6] * T ** 4
    return cp


with open(os.path.join(ATLAS, SOURCE)) as f:
    records = yaml.safe_load(f)
index_records(records, SOURCE)
with open(os.path.join(ATLAS, 'database', 'thermo', 'nasa9.yaml')) as f:
    nasa9 = {s['name']: s['thermo'] for s in yaml.load(f, Loader=_NoBool)['species']}


def thermo_cp(r):
    for name in [THERMO_NAME.get(r['element'], r['element'])] + r.get('aliases', []):
        if name in nasa9:
            return nasa9_cp(nasa9[name])
    return None


# ---- 1 and 2: ATLAS intervals of the database -------------------------------------------------------------------------------------
def slope_min(c, T1, T2):
    A, B, C = c[0], c[1], c[2]
    xs = [1.0 / T2, 1.0 / T1]
    if C != 0.0 and xs[0] < -B / (4.0 * C) < xs[1]:
        xs.append(-B / (4.0 * C))
    return min(A - B * x - 2.0 * C * x * x for x in xs)


def ulp_of_log(T):
    decimal.getcontext().prec = 40
    exact = decimal.Decimal(T).ln()
    return abs(float((decimal.Decimal(float(np.log(T))) - exact) / decimal.Decimal(math.ulp(float(exact)))))


def sum_terms(c, T):
    return abs(c[0] * np.log(T)) + abs(c[1] / T) + abs(c[2] / (T * T)) + abs(c[3])


def sum_slope_terms(c, T):
    return abs(c[0]) + abs(c[1] / T) + abs(2.0 * c[2] / (T * T))


n_atlas = 0
for r in records:
    for prop in ('viscosity', 'conductivity'):
        ints = r[prop]
        for it in ints:
            if not atlas_interval(it):
                continue
            n_atlas += 1
            c, (T1, T2) = it['coefficients'], (min(it['temperature_range']), max(it['temperature_range']))
            check(len(c) == 4 and all(isinstance(x, float) and math.isfinite(x) for x in c),
                  f"{r['element']} {prop} [{T1:g}, {T2:g}]: four finite float coefficients")
            q = slope_min(c, T1, T2)
            check(q > 0.0, f"{r['element']} {prop} [{T1:g}, {T2:g}]: exact minimum of d ln p/d ln T {q:.4f} > 0")
        for a, b in zip(ints[:-1], ints[1:]):
            if not (atlas_interval(a) or atlas_interval(b)):
                continue
            Tj = max(a['temperature_range'])
            ca, cb = a['coefficients'], b['coefficients']
            dv, dg = abs(ln_property(ca, Tj) - ln_property(cb, Tj)), abs(dln_property(ca, Tj) - dln_property(cb, Tj))
            tv = 13 * EPS * (sum_terms(ca, Tj) + sum_terms(cb, Tj)) + 8 * EPS * abs(ca[0] - cb[0]) * abs(math.log(Tj))
            tg = 13 * EPS * (sum_slope_terms(ca, Tj) + sum_slope_terms(cb, Tj))
            check(min(b['temperature_range']) == Tj and dv <= tv and dg <= tg,
                  f"{r['element']} {prop} junction at {Tj:g} K: |d ln p| {dv:.1e} <= {tv:.1e}, |d slope| {dg:.1e} <= {tg:.1e}")
            u = ulp_of_log(Tj)
            check(u <= 4.0, f"np.log({Tj:g}) within {u:.2f} <= 4 units in the last place of the 40-digit logarithm")
pairs = {(r['element'], prop) for r in records for prop in ('viscosity', 'conductivity') if any(atlas_interval(it) for it in r[prop])}
check(n_atlas > 0 and pairs == set(THRESHOLD), f"{n_atlas} ATLAS intervals in {len(pairs)} properties, each with its reference below "
      f"(no reference for {sorted(pairs - set(THRESHOLD))}, no intervals for {sorted(set(THRESHOLD) - pairs)})")


# ---- 3: references ------------------------------------------------------------------------------------------------------------
byname = {r['element']: r for r in records}
constant_cp = lambda T: 1.0   # the rows checked here lie at or above the lowest bound of each property: cp does not enter
for (sp, prop), bound in sorted(THRESHOLD.items()):
    r = byname[sp]
    lo = min(min(it['temperature_range']) for it in r[prop])
    if sp in LJ:
        grid = sorted(set([lo] + [float(t) for t in range(math.ceil(lo), 201)]))
        ref = [lj_eta0(sp, t) if prop == 'viscosity' else lj_lambda0(sp, t) for t in grid]
    else:
        pts = [p for p in bich_points(sp) if lo - 1e-9 <= p[0] <= 200.0 + 1e-9]
        grid, ref = [p[0] for p in pts], [p[1] if prop == 'viscosity' else p[2] for p in pts]
    mu, k, _ = cea_table(r, grid, constant_cp, SOURCE)
    got = mu if prop == 'viscosity' else k
    dev = max(abs(g / f - 1.0) for g, f in zip(got, ref)) * 100.0
    check(len(grid) > 5 and dev <= bound, f"{sp} {prop} from {lo:g} K to 200 K ({len(grid)} points): largest deviation from the "
          f"reference {dev:.3f} % <= {bound} %")


# ---- 4: rows of every record ------------------------------------------------------------------------------------------------------
temps = [float(t) for t in range(1, 5001)]
for r in records:
    name = r['element']
    cp = thermo_cp(r)
    if cp is None:
        check(False, f"{name}: no NASA9 record in nasa9.yaml for the specific heat")
        continue
    try:
        mu, k, info = cea_table(r, temps, cp, SOURCE)
    except RecordError as e:
        check(False, f"{name}: the rule stops on the default table: {e}")
        continue
    nasa_lo = min(min(it['temperature_range']) for it in r['viscosity'] if not atlas_interval(it))
    mu_lo = min(min(it['temperature_range']) for it in r['viscosity'])
    k_lo = min(min(it['temperature_range']) for it in r['conductivity'])
    rows = int(nasa_lo)
    m12 = [float(f'{x:.12f}') for x in mu[:rows]]
    k12 = [float(f'{x:.12f}') for x in k[:rows]]
    finite = all(math.isfinite(x) and x > 0.0 for x in mu + k)
    n = dln_property(next(it for it in r['viscosity'] if min(it['temperature_range']) == mu_lo)['coefficients'], mu_lo)
    if n > 0.0:
        ok = all(a < b for a, b in zip(m12[:-1], m12[1:])) and all(a < b for a, b in zip(k12[:-1], k12[1:])) and not info
        what = 'strictly increasing'
    else:
        ok = all(x == mu[int(mu_lo) - 1] for x in mu[:int(mu_lo) - 1]) and len(info) == 1
        what = f'viscosity held at its {mu_lo:g} K value (d ln mu/d ln T = {n:.2f}), information line'
    pr = [mu[i] * cp(temps[i]) / k[i] for i in range(int(math.ceil(k_lo)) - 1)]
    pr_ok = not pr or (max(pr) - min(pr)) <= 1e-12 * max(pr)
    check(finite and ok and pr_ok, f"{name}: rows 1-{rows} K positive, finite, {what}; Prandtl number constant below {k_lo:g} K")


# ---- 5: the rule on records built here --------------------------------------------------------------------------------------------
def interval(lo, hi, c):
    return {'temperature_range': [lo, hi], 'coefficients': list(c)}


def record(visc, cond, name='X'):
    return {'element': name, 'viscosity': visc, 'conductivity': cond}


K1 = [interval(100.0, 1000.0, [0.7, 0.0, 0.0, 2.0])]
T5 = [10.0, 50.0, 99.0, 100.0, 300.0, 1000.0, 1200.0]
for n in (-0.5, 0.0, 0.3, 0.5 - 1e-6, 0.5, 0.5 + 1e-6, 1.0, 1.5 - 1e-6, 1.5, 1.5 + 1e-6, 2.0):
    mu, _, info = cea_table(record([interval(100.0, 1000.0, [n, 0.0, 0.0, 1.0])], K1), T5, constant_cp, SOURCE)
    mu100 = 1e-7 * math.exp(n * math.log(100.0) + 1.0)
    if n <= 0.0:
        f = lambda T: 1.0
        slope = 0.0
    elif 0.5 < n < 1.5:
        S = 100.0 * (n - 0.5) / (1.5 - n)
        f = lambda T: (T / 100.0) ** 1.5 * (100.0 + S) / (T + S)
        slope = 1.5 - 100.0 / (100.0 + S)
    else:
        f = lambda T: (T / 100.0) ** n
        slope = n
    ok = all(abs(mu[i] / (mu100 * f(T)) - 1.0) <= 1e-14 for i, T in enumerate(T5[:3]))
    ok = ok and abs(mu[3] / mu100 - 1.0) <= 1e-14 and abs(mu[6] / mu[5] - 1.0) == 0.0
    ok = ok and (abs(slope - n) <= 1e-12 if n > 0.0 else len(info) == 1)
    check(ok, f"n = {n:.7g}: below 100 K the {'bound' if n <= 0 else 'Sutherland law' if 0.5 < n < 1.5 else 'power law'}, value "
              f"at 100 K, slope {slope:.7g} at 100 K, value held above 1000 K")

# Prandtl number below the lowest conductivity bound with a specific heat that changes with T
cp_var = lambda T: 3.5 + 1e-3 * min(T, 300.0)
mu, k, _ = cea_table(record([interval(20.0, 1000.0, [0.8, -10.0, 100.0, 1.0])], [interval(80.0, 1000.0, [0.9, -30.0, 500.0, 2.0])]),
                     [5.0, 20.0, 50.0, 79.0, 80.0, 500.0], cp_var, SOURCE)
pr = [mu[i] * cp_var(T) / k[i] for i, T in enumerate([5.0, 20.0, 50.0, 79.0, 80.0])]
check(max(pr) - min(pr) <= 1e-12 * max(pr), f"Prandtl number constant from 5 K to 80 K with a changing cp: {min(pr):.10g}-{max(pr):.10g}")

# different bounds for viscosity and conductivity (lower and upper): every value from the bounds of its own property
cv, cc = [0.7, 0.0, 0.0, 1.0], [0.8, 0.0, 0.0, 2.0]
mu, k, _ = cea_table(record([interval(100.0, 1000.0, cv)], [interval(50.0, 800.0, cc)]), [40.0, 60.0, 900.0, 1100.0], constant_cp, SOURCE)
m_rule = lambda T: 1e-7 * math.exp(0.7 * math.log(100.0) + 1.0) * (T / 100.0) ** 1.5 * (100.0 + 100.0 * 0.2 / 0.8) / (T + 100.0 * 0.2 / 0.8)
k_at = lambda T: 1e-4 * math.exp(0.8 * math.log(T) + 2.0)
ok = abs(mu[1] / m_rule(60.0) - 1) < 1e-14 and abs(k[1] / k_at(60.0) - 1) < 1e-14 and abs(k[2] / k_at(800.0) - 1) < 1e-14
ok = ok and abs(mu[2] / (1e-7 * math.exp(0.7 * math.log(900.0) + 1.0)) - 1) < 1e-14
ok = ok and abs(k[0] / (k_at(50.0) * m_rule(40.0) / m_rule(50.0)) - 1) < 1e-14
check(ok, "different bounds for viscosity (100-1000 K) and conductivity (50-800 K): values from the bounds of each property")


def refused(text, rec, temps, expected, cp=constant_cp):
    try:
        cea_table(rec, temps, cp, SOURCE)
    except RecordError as e:
        check(expected in str(e) and str(e).startswith(f"{SOURCE}: record 'X'"), f"refused, {text}: {e}")
        return
    check(False, f"refused, {text}: no error")


GOOD = [interval(100.0, 1000.0, [0.7, 0.0, 0.0, 1.0])]
TABLE = [float(t) for t in range(1, 1001)]
refused('a table row in a gap of the viscosity', record([interval(100.0, 300.0, cv), interval(400.0, 1000.0, cv)], GOOD), TABLE,
        "viscosity: no interval contains 301-399 K (99 rows)")
refused('three coefficients', record(GOOD, [interval(100.0, 1000.0, [0.7, 0.0, 1.0])]), TABLE,
        "every interval has exactly four coefficients")
refused('five coefficients', record([interval(100.0, 1000.0, [0.7, 0.0, 0.0, 1.0, 5.0])], GOOD), TABLE, "every interval has exactly four")
refused('a coefficient .nan', record(GOOD, [interval(100.0, 1000.0, [0.7, float('nan'), 0.0, 1.0])]), TABLE, "finite numbers")
refused('a coefficient that is not a number', record([interval(100.0, 1000.0, ['a', 0.0, 0.0, 1.0])], GOOD), TABLE, "finite numbers")
refused('a bound that is not a number', record([{'temperature_range': ['a', 1000.0], 'coefficients': cv}], GOOD), TABLE,
        "the temperature range must be a list of finite numbers")
refused('no conductivity intervals', record(GOOD, []), TABLE, "conductivity: no intervals")
refused('a specific heat that is not positive', record(GOOD, GOOD), TABLE, "needs a positive finite specific heat", cp=lambda T: 0.0)


def same(text, rec, temps, ref_rec, tol=0.0):
    a, b = cea_table(rec, temps, constant_cp, SOURCE), cea_table(ref_rec, temps, constant_cp, SOURCE)
    ok = all(abs(x / y - 1.0) <= tol for x, y in zip(a[0] + a[1], b[0] + b[1])) and len(a[0]) == len(b[0])
    check(ok, f"no stop, {text}: the table of the record in order" + (f" (within {tol:g})" if tol else ""))


# two intervals continuous at 400 K, as the intervals of a record are: the order of the list matters only at the shared bound
C2 = [0.6, -10.0, 0.0, 0.7 * math.log(400.0) + 1.0 - (0.6 * math.log(400.0) - 10.0 / 400.0)]
ORD = record([interval(100.0, 400.0, cv), interval(400.0, 1000.0, C2)], GOOD)
same('bounds of an interval written high to low', record([{'temperature_range': [400.0, 100.0], 'coefficients': cv},
                                                          interval(400.0, 1000.0, C2)], GOOD), TABLE, ORD)
same('intervals out of order', record([interval(400.0, 1000.0, C2), interval(100.0, 400.0, cv)], GOOD), TABLE, ORD, tol=1e-14)
same('a gap above the last row of the table', record([interval(100.0, 300.0, cv), interval(400.0, 1000.0, cv)], GOOD),
     TABLE[:300], record([interval(100.0, 300.0, cv)], GOOD))
OVER = record([interval(100.0, 500.0, cv), interval(300.0, 1000.0, [0.6, -10.0, 0.0, 1.5])], GOOD)
mu, _, _ = cea_table(OVER, [200.0, 400.0], constant_cp, SOURCE)
check(abs(mu[1] / (1e-7 * math.exp(0.6 * math.log(400.0) - 10.0 / 400.0 + 1.5)) - 1) < 1e-14 and
      abs(mu[0] / (1e-7 * math.exp(0.7 * math.log(200.0) + 1.0)) - 1) < 1e-14,
      "no stop, two overlapping intervals: the last that contains T")

print(f"{len(failures)} failures")
sys.exit(1 if failures else 0)
