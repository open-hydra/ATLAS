"""Pyrolysis-gas composition tables (BC 506): one <name>pyrolysis.dat per ideal-gas phase that a [GPB-Pyrolysis<n>]
names, one table block per section in ascending n. The table lists the species of the phase (phase.txt order) made of
the makeup's elements only; MOSE maps them by name."""
import sys

import numpy as np

from config import HG_SUBSTRING
from . import equilibrium as EQ
from . import io as PY_IO


def _refuse(section, text):
    print(f"[ERROR] section [{section}]: {text}")
    sys.exit(1)


def _target(d, gas_phases):
    """The (name, species_group) of the ideal-gas phase the section names; *gas_phases* = [(name, species_group)] with
    name '' (unnamed) or '<name>-' (thermo.py writes <name>phase.txt)."""
    if not gas_phases:
        _refuse(d.section, "no ideal-gas phase in this deck: the table follows the species of a [GPB-Phase*] of type "
                           "ideal-gas (or heavy-gas) built in the same run")
    if d.phase is None:
        if len(gas_phases) > 1:
            names = ', '.join(n[:-1] if n else '(unnamed)' for n, _ in gas_phases)
            _refuse(d.section, f"phase is not given and the deck builds {len(gas_phases)} ideal-gas phases ({names}): "
                               f"name one with phase = <name>")
        return gas_phases[0]
    for name, group in gas_phases:
        if name == d.phase + '-':
            return name, group
    names = ', '.join(n[:-1] if n else '(unnamed)' for n, _ in gas_phases)
    _refuse(d.section, f"phase = {d.phase} is not the name of an ideal-gas phase of this deck (ideal-gas phases: {names})")


def _species_of(group):
    """The Species objects of the phase in the order of its phase.txt (ideal_gas/thermo.py:24-33), without the
    pseudo-species, whose composition is not a chemical formula: a mixture (one line of phase.txt, thermo.py:29),
    the constant-cp species (composition 'H:<M/1.008>', ideal_gas/builder.py:415) and the heavy-gas copies of a
    condensed species (composition {'H': M/1.008}, ideal_gas/builder.py:458)."""
    out = []
    for sol in group:
        if 'mixture' in sol.name or sol.name == 'constant-cp species':
            continue
        out += [sol.species(k) for k in range(sol.n_species) if HG_SUBSTRING not in sol.species(k).name]
    return out


def _thermo_range_notes(d, species):
    """The rule of the ideal-gas tables (ideal_gas/builder.py:478-488): a WARNING when the grid starts below the
    polynomial range of a species, an [INFO] when it ends above it; the equilibrium then extrapolates its thermo."""
    lo = {sp.name: sp.thermo.min_temp for sp in species if sp.thermo.min_temp > d.temperatures[0]}
    hi = {sp.name: sp.thermo.max_temp for sp in species if sp.thermo.max_temp < d.temperatures[-1]}
    if lo:
        w = max(lo, key=lo.get)
        print(f"[WARNING] GPB: [{d.section}]: T-min = {d.temperatures[0]:g} K is below the polynomial range of {len(lo)} "
              f"species (up to {lo[w]:g} K for {w}): their thermo is extrapolated")
    if hi:
        print(f"[INFO] GPB: [{d.section}]: T-max = {d.temperatures[-1]:g} K is above the polynomial range of {len(hi)} "
              f"species (from {min(hi.values()):g} K): {', '.join(sorted(hi)[:10])}")


def _no_negative(d, names, p, T, y, xc=None):
    """D18: a mass fraction (or the condensed-carbon fraction X_C) that would be written below 0 (io.FLOOR: |v| < 1e-99
    is written as 0) stops GPB, naming (p, T, species); the FLINT reader refuses such a row too."""
    for name, v in zip(names, y):
        if v <= -PY_IO.FLOOR:
            _refuse(d.section, f"treatment = {d.treatment}: the equilibrium at p = {p:g} Pa, T = {T:g} K gives the "
                               f"mass fraction {v:.6e} of {name}, below 0: no table is written")
    if xc is not None and xc <= -PY_IO.FLOOR:
        _refuse(d.section, f"treatment = {d.treatment}: the equilibrium at p = {p:g} Pa, T = {T:g} K gives the "
                           f"condensed-carbon fraction X_C = {xc:.6e}, below 0: no table is written")


def _table(d, phase_name, group):
    species = [sp for sp in _species_of(group) if sp.composition and set(sp.composition) <= set(d.elements)]
    for e in d.elements:
        if not any(e in sp.composition for sp in species):
            _refuse(d.section, f"element {e} of the makeup has no carrier: no species of the gas list of phase "
                               f"{phase_name[:-1] or '(unnamed)'} is made of {', '.join(d.elements)} only and contains {e}")
    names = [sp.name for sp in species]
    print(f" - Pyrolysis-gas table: {d.name} ({d.treatment}, {len(d.pressures)} x {len(d.temperatures)} points, "
          f"{len(names)} species of {phase_name}phase.txt)")
    _thermo_range_notes(d, species)
    b = EQ.element_moles(d.elements, d.massf)
    rows = []
    if d.treatment == 'gas-only':
        gas = EQ.gas_only_solution(species)
        seed = EQ.feasible_seed(gas, d.elements, b)
        if seed is None:
            _refuse(d.section, f"treatment = gas-only: no mixture of the species {' '.join(names)} has the makeup's "
                               f"elements in its proportions (the gas list cannot carry it: add a carrier, e.g. "
                               f"C2H2, C2H4 or CH4 for the carbon, or use treatment = strip)")
        for p in d.pressures:
            warm = None
            for T in d.temperatures:
                try:
                    y, warm = EQ.solve_gas_only(gas, seed, p, T, warm)
                except EQ.NotConverged:
                    _refuse(d.section, f"treatment = gas-only: the equilibrium did not converge at p = {p:g} Pa, "
                                       f"T = {T:g} K (also from the previous point)")
                _no_negative(d, names, p, T, y)
                rows.append(y)
    else:
        strip = EQ.StripSolver(names, d.elements, b, {sp.name: sp.molecular_weight for sp in species}, d.section)
        xc_min, xc_max = 1.0, 0.0
        for p in d.pressures:
            warm = None
            for T in d.temperatures:
                try:
                    y, xc, warm = strip.solve(p, T, warm)
                except EQ.NotConverged:
                    _refuse(d.section, f"treatment = strip: the CEA equilibrium did not converge at p = {p:g} Pa, "
                                       f"T = {T:g} K (also from the previous point; outside the thermo range of a "
                                       f"species of the CEA database the solve does not converge)")
                _no_negative(d, names, p, T, y, xc)
                rows.append(y)
                xc_min, xc_max = min(xc_min, xc), max(xc_max, xc)
        print(f"   strip: condensed carbon removed from the equilibrium, X_C = {xc_min:.4f} ... {xc_max:.4f} of the "
              f"pyrolysis-gas mass")
    return {'name': d.name, 'treatment': d.treatment, 'elements': d.elements, 'massf': d.massf, 'species': names,
            'p': d.pressures, 'T': d.temperatures, 'rows': np.array(rows)}


def build(definitions, gas_phases):
    """*definitions*: the [GPB-Pyrolysis<n>] of the deck (ascending n); *gas_phases*: [(name, species_group)] of the
    ideal-gas phases GPB built in this run, in [GPB-Phase<n>] order."""
    print()
    print(' - Pyrolysis-gas tables')
    files = {}
    for d in definitions:
        name, group = _target(d, gas_phases)
        files.setdefault(name, []).append(_table(d, name, group))
    for name, tables in files.items():
        PY_IO.write_tables(name, tables)
