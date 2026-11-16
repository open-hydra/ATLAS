"""[GPB-Pyrolysis<n>] sections: the pyrolysis-gas composition tables y_pg(p, T) (BC 506). Read by GPB only; every key
is checked here, before any phase is built."""
import sys
from dataclasses import dataclass
from typing import List, Optional

import cantera as ct
from PiNeR import get, check_section

TREATMENTS = ('gas-only', 'strip')
NAME_MAX = 64          # the width of the BCB field that reads the name (pyrolysis-gas, src/BCB/config.f90)
SUM_TOL = 1.0e-3       # the rule of the y<species> keys of BCB (docs/user-guide/bcb/bc-types.md): renormalised within
SUM_SILENT = 1.0e-12   # 1e-3 with a WARNING, silent within 1e-12, refused beyond 1e-3


@dataclass(frozen=True)
class PyrolysisDefinition:
    section: str
    name: str
    phase: Optional[str]        # name of the [GPB-Phase*] ideal-gas phase; None: the only ideal-gas phase of the deck
    elements: List[str]
    massf: List[float]          # sum exactly 1 (renormalised)
    pressures: List[float]      # Pa, strictly ascending, >= 1 level
    temperatures: List[float]   # K, strictly ascending, >= 2 levels
    treatment: str


def _refuse(section, text):
    print(f"[ERROR] section [{section}]: {text}")
    sys.exit(1)


def _raw(ini_file, section, key):
    """The value of *key* without an inline '; comment' (PiNeR keeps it); None when absent or empty."""
    raw = get(ini_file, section, key, str)
    if raw is None:
        return None
    raw = raw.split(';')[0].strip()
    return raw if raw else None


def _numbers(section, key, raw):
    try:
        return [float(t) for t in raw.split()]
    except ValueError:
        _refuse(section, f"{key} = {raw}: expected numbers separated by blanks")


def _pressures(ini_file, section):
    plist = _raw(ini_file, section, 'p')
    pmin, pmax, pn = (_raw(ini_file, section, k) for k in ('p-min', 'p-max', 'p-n'))
    spacing = _raw(ini_file, section, 'p-spacing')
    if plist is not None:
        if any(v is not None for v in (pmin, pmax, pn, spacing)):
            _refuse(section, "p is given with p-min/p-max/p-n/p-spacing: give the list p or the range, not both")
        p = _numbers(section, 'p', plist)
    else:
        if pmin is None or pmax is None or pn is None:
            _refuse(section, "no pressure levels: give p (a list, Pa) or p-min, p-max and p-n")
        lo, hi = _numbers(section, 'p-min', pmin), _numbers(section, 'p-max', pmax)
        n = _numbers(section, 'p-n', pn)
        if len(lo) != 1 or len(hi) != 1 or len(n) != 1 or not float(n[0]).is_integer() or n[0] < 1:
            _refuse(section, f"p-min = {pmin}, p-max = {pmax}, p-n = {pn}: one number each, p-n an integer >= 1")
        lo, hi, n = lo[0], hi[0], int(n[0])
        spacing = spacing or 'linear'
        if spacing not in ('linear', 'log'):
            _refuse(section, f"p-spacing = {spacing}: allowed linear, log")
        if lo <= 0.0:
            _refuse(section, f"p-min = {pmin}: a pressure above 0 Pa")
        if n == 1:
            if hi != lo:
                _refuse(section, f"p-n = 1 with p-max = {pmax} different from p-min = {pmin}")
            p = [lo]
        else:
            if not hi > lo:
                _refuse(section, f"p-max = {pmax} is not above p-min = {pmin}")
            if spacing == 'linear':
                p = [lo + i * (hi - lo) / (n - 1) for i in range(n)]
            else:
                p = [lo * (hi / lo) ** (i / (n - 1)) for i in range(n)]
            p[-1] = hi
    if p[0] <= 0.0:
        _refuse(section, f"p = {p[0]!r} Pa: the pressures must be above 0 Pa")
    if any(b <= a for a, b in zip(p, p[1:])):
        _refuse(section, "the pressures must be strictly ascending")
    return p


def _temperatures(ini_file, section):
    raw = _raw(ini_file, section, 'T')
    if raw is None:
        _refuse(section, "no temperature grid: give T = T-min T-max T-step (K)")
    v = _numbers(section, 'T', raw)
    if len(v) != 3:
        _refuse(section, f"T = {raw}: three numbers, T-min T-max T-step (K)")
    lo, hi, step = v
    if lo <= 0.0 or not hi > lo or not step > 0.0:
        _refuse(section, f"T = {raw}: T-min above 0 K, T-max above T-min, T-step above 0")
    n = (hi - lo) / step
    if abs(n - round(n)) > 1.0e-9 * max(1.0, n):
        _refuse(section, f"T = {raw}: (T-max - T-min)/T-step = {n:.12g} is not an integer")
    n = int(round(n))
    T = [lo + j * step for j in range(n + 1)]
    T[-1] = hi
    return T


def _makeup(ini_file, section):
    raw_el, raw_w = _raw(ini_file, section, 'elements'), _raw(ini_file, section, 'massf')
    if raw_el is None or raw_w is None:
        _refuse(section, "the makeup needs elements (symbols) and massf (their mass fractions)")
    elements = raw_el.split()
    w = _numbers(section, 'massf', raw_w)
    if len(w) != len(elements):
        _refuse(section, f"{len(elements)} elements and {len(w)} massf values")
    if len(set(elements)) != len(elements):
        _refuse(section, f"elements = {raw_el}: an element is given twice")
    for e in elements:
        try:
            ct.Element(e)
        except ct.CanteraError:
            _refuse(section, f"elements: '{e}' is not an element symbol (case-sensitive: C, H, O, N, Al, ...)")
    for e, x in zip(elements, w):
        if not 0.0 < x <= 1.0:
            _refuse(section, f"massf of {e} = {x!r}: a mass fraction in (0, 1] (leave out an element that is absent)")
    s = sum(w)
    if abs(s - 1.0) > SUM_TOL + SUM_SILENT:
        _refuse(section, f"massf = {raw_w}: the mass fractions sum to {s:.12g}, not 1 (renormalised only within 1e-3)")
    if abs(s - 1.0) > SUM_SILENT:
        print(f"[WARNING] section [{section}]: massf sum to {s:.12g}: renormalised to 1")
    return elements, [x / s for x in w]


def load_pyrolysis_definitions(ini_file):
    """Every [GPB-Pyrolysis<n>], n = 1, 2, ... up to the first missing one (the rule of [GPB-Phase<n>])."""
    out = []
    n = 0
    while True:
        n += 1
        section = f'GPB-Pyrolysis{n}'
        if not check_section(ini_file, section):
            break
        name = _raw(ini_file, section, 'name')
        if name is None:
            _refuse(section, "no name: the table name, which the BCB key pyrolysis-gas gives")
        if len(name.split()) != 1 or len(name) > NAME_MAX:
            _refuse(section, f"name = {name}: one word of at most {NAME_MAX} characters (no blanks)")
        if name.startswith('#'):
            _refuse(section, f"name = {name}: a name cannot start with '#' (the table file reads it as a comment, DEC-3)")
        if any(d.name == name for d in out):
            _refuse(section, f"name = {name}: another [GPB-Pyrolysis*] section has this name")
        treatment = _raw(ini_file, section, 'treatment') or 'gas-only'
        if treatment not in TREATMENTS:
            _refuse(section, f"treatment = {treatment}: allowed gas-only, strip")
        elements, massf = _makeup(ini_file, section)
        out.append(PyrolysisDefinition(section=section, name=name, phase=_raw(ini_file, section, 'phase'),
                                       elements=elements, massf=massf, pressures=_pressures(ini_file, section),
                                       temperatures=_temperatures(ini_file, section), treatment=treatment))
    return out
