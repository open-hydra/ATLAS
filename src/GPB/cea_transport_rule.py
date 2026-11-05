"""Viscosity and thermal conductivity of a species from its record of the CEA transport database
(database/transport/CEApolynomials.yaml), at the temperatures of a GPB table.

Every interval of a property gives ln p = A ln T + B/T + C/T^2 + D, with p in micropoise (viscosity) or in microwatt/(cm K)
(conductivity). Inside the intervals of a property a temperature takes the last interval that contains it. Outside, the record is
continued from its bounds, the lowest lower bound and the highest upper bound of the property (the first and the last interval are
taken by their bounds, not by their position in the list):

- below the lowest bound Tlo of the viscosity, the viscosity continues with its value and its logarithmic slope at Tlo,
  n = A - B/Tlo - 2C/Tlo^2 of the interval that GPB uses at Tlo:
    1/2 < n < 3/2:          mu(T) = mu(Tlo) (T/Tlo)^(3/2) (Tlo + S)/(T + S),  S = Tlo (n - 1/2)/(3/2 - n),
                            the Sutherland law through mu(Tlo) with the slope n at Tlo;
    0 < n <= 1/2, n >= 3/2: mu(T) = mu(Tlo) (T/Tlo)^n;
    n <= 0:                 mu(T) = mu(Tlo), with an information line when the table has rows below Tlo;
  mu is positive and continuous at Tlo; for n > 0 it also increases with T, has the slope n at Tlo on both sides and goes to zero
  with T (for 1/2 < n < 3/2, d ln mu/d ln T = 3/2 - T/(T + S) lies between 1/2 and 3/2);
- below the lowest bound Tk of the conductivity, the Prandtl number stays at its value at Tk:
    k(T) = k(Tk) mu(T) cp(T) / (mu(Tk) cp(Tk)),
  with mu as above and cp the specific heat of the species from its thermo record in the run (held at its value at the bound of its
  thermo range outside it, as thermo.py holds it for a species zone of thermo.dat): the Prandtl number mu cp / k of the species tables
  stays at its value at Tk;
- above the highest bound of a property, the property keeps its value at that bound.

A record stops GPB (RecordError, a message that names the file, the record, the property and the temperatures or the interval) only
where no value can be given: a table temperature between the lowest and the highest bound of a property that no interval contains, a
property without intervals, an interval used by the table whose coefficients are not four finite numbers, any interval of the property
whose temperature range is not a list of finite numbers (the lowest and the highest bound come from every interval), and a specific heat
that is not a positive finite number where the conductivity rule needs it.

The module imports neither Cantera nor the GPB configuration.
"""
import math

import numpy as np

from cea_transport_records import RecordError

UNIT = {'viscosity': 1.0e-07, 'conductivity': 1.0e-04}   # micropoise -> Pa s; microwatt/(cm K) -> W/(m K)


def ln_property(c, T):
    """ln p of an interval with coefficients c = [A, B, C, D] at T, in the order of evaluation of GPB."""
    return c[0] * np.log(T) + c[1] / T + c[2] / (T * T) + c[3]


def dln_property(c, T):
    """Logarithmic slope d ln p / d ln T = A - B/T - 2C/T^2 of an interval at T."""
    return c[0] - c[1] / T - 2.0 * c[2] / (T * T)


def _is_finite_number(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x)


def _bounds(interval):
    return min(interval['temperature_range']), max(interval['temperature_range'])


def _temperatures(values):
    """A compact list of table temperatures, e.g. '300-499 K (200 rows)'."""
    runs, start, prev = [], values[0], values[0]
    for t in values[1:]:
        if t != prev + 1:
            runs.append((start, prev))
            start = t
        prev = t
    runs.append((start, prev))
    text = ', '.join(f'{a:g}' if a == b else f'{a:g}-{b:g}' for a, b in runs[:3]) + (', ...' if len(runs) > 3 else '')
    return f"{text} K ({len(values)} row{'s' if len(values) > 1 else ''})"


class _Property:
    """The intervals of one property of a record, with the selection rules of the module docstring."""

    def __init__(self, record, prop, where):
        self.prop, self.where = prop, f"{where}, {prop}"
        intervals = record.get(prop)
        if not isinstance(intervals, list) or not intervals:
            raise RecordError(f"{self.where}: no intervals; every property of a record needs its temperature intervals")
        for it in intervals:
            rng = it.get('temperature_range') if isinstance(it, dict) else None
            if not isinstance(rng, list) or not rng or not all(_is_finite_number(x) for x in rng):
                raise RecordError(f"{self.where}: interval {rng if isinstance(it, dict) else it!r}: the temperature range must be "
                                  f"a list of finite numbers [Tlo, Thi]")
        self.intervals = intervals
        self.lo = min(_bounds(it)[0] for it in intervals)
        self.hi = max(_bounds(it)[1] for it in intervals)
        self.used = []

    def select(self, T):
        """The interval GPB uses at T in [lo, hi] (the last that contains T), or None in a gap."""
        hit = None
        for it in self.intervals:
            lo, hi = _bounds(it)
            if lo <= T <= hi:
                hit = it
        if hit is not None and not any(hit is u for u in self.used):
            self.used.append(hit)
        return hit

    def check_used(self):
        for it in self.used:
            c = it.get('coefficients')
            if not isinstance(c, list) or len(c) != 4 or not all(_is_finite_number(x) for x in c):
                n = len(c) if isinstance(c, list) else 'no list of'
                raise RecordError(f"{self.where}: interval {it['temperature_range']}: coefficients {c!r} ({n} values): every interval "
                                  f"has exactly four coefficients [A, B, C, D], finite numbers")

    def value(self, T):
        """The property in SI units at T in [lo, hi]; T above hi takes the value at hi (the caller handles T below lo)."""
        Tq = self.hi if T > self.hi else T
        it = self.select(Tq)
        return UNIT[self.prop] * np.exp(ln_property(it['coefficients'], Tq))


def cea_table(record, temperatures, cp, source):
    """Viscosity [Pa s] and conductivity [W/(m K)] of `record` at the table `temperatures` (increasing), and the information lines.

    cp(T) is the specific heat of the species at T, held at the bound of its thermo range outside it (any unit: only ratios enter).
    `source` is the database file named in the messages. Raise RecordError where the record or cp give no value (module docstring).
    """
    name = record.get('element')
    where = f"{source}: record {name!r}"
    mu_p, k_p = _Property(record, 'viscosity', where), _Property(record, 'conductivity', where)
    temperatures = [float(t) for t in temperatures]

    # the temperatures where each property is evaluated: the rows, and Tk for the viscosity when rows lie below Tk
    need_mu = list(temperatures)
    if temperatures and temperatures[0] < k_p.lo:
        need_mu.append(k_p.lo)
    for p, need in ((mu_p, need_mu), (k_p, temperatures)):
        gaps = sorted(t for t in set(need) if p.lo <= t <= p.hi and p.select(t) is None)
        if gaps:
            raise RecordError(f"{p.where}: no interval contains {_temperatures(gaps)} between the lowest bound {p.lo:g} K and the "
                              f"highest bound {p.hi:g} K: every table temperature in that range needs an interval")
        if any(t > p.hi for t in need):
            p.select(p.hi)
    below_mu = any(t < mu_p.lo for t in need_mu)
    if below_mu:
        mu_p.select(mu_p.lo)
    if temperatures and temperatures[0] < k_p.lo:
        k_p.select(k_p.lo)
    mu_p.check_used()
    k_p.check_used()

    info = []
    Tlo = mu_p.lo
    mu_lo, n, S = None, None, None
    if below_mu:
        c0 = mu_p.select(Tlo)['coefficients']
        mu_lo = UNIT['viscosity'] * np.exp(ln_property(c0, Tlo))
        n = float(dln_property(c0, Tlo))
        if n <= 0.0:
            info.append(f"transport = CEA: record {name!r}: the viscosity of the record does not increase with temperature at its "
                        f"lowest bound {Tlo:g} K (d ln mu/d ln T = {n:.3g}): below {Tlo:g} K the viscosity keeps its value at {Tlo:g} K")
        S = Tlo * (n - 0.5) / (1.5 - n) if 0.5 < n < 1.5 else None

    def viscosity(T):
        if T >= Tlo:
            return mu_p.value(T)
        if n <= 0.0:
            f = 1.0
        elif S is not None:
            f = (T / Tlo) ** 1.5 * (Tlo + S) / (T + S)
        else:
            f = (T / Tlo) ** n
        return mu_lo * f

    Tk = k_p.lo
    if temperatures and temperatures[0] < Tk:
        k_k, mu_k, cp_k = k_p.value(Tk), viscosity(Tk), cp(Tk)
        if not (_is_finite_number(cp_k) and cp_k > 0.0):
            raise RecordError(f"{where}: the specific heat of the species at {Tk:g} K is {cp_k!r}: the conductivity below {Tk:g} K "
                              f"keeps the Prandtl number of {Tk:g} K and needs a positive finite specific heat")

    mu, k = [], []
    for T in temperatures:
        m = viscosity(T)
        mu.append(m)
        if T >= Tk:
            k.append(k_p.value(T))
            continue
        cp_T = cp(T)
        if not (_is_finite_number(cp_T) and cp_T > 0.0):
            raise RecordError(f"{where}: the specific heat of the species at {T:g} K is {cp_T!r}: the conductivity below {Tk:g} K "
                              f"keeps the Prandtl number of {Tk:g} K and needs a positive finite specific heat")
        k.append(k_k * (m / mu_k) * (cp_T / cp_k))
    return mu, k, info
