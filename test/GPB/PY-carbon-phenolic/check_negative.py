#!/usr/bin/env python3
"""PY-carbon-phenolic, D18: a solve that returns a negative mass fraction stops GPB, naming (p, T, species).

    check_negative.py <ATLAS root>        (run in an empty directory: importing pyrolysis.io creates fromATLAStoSolver/)

The table MX4926 of input.ini (gas-only, p = 1e5 Pa, T = 1500 and 2000 K) is built by builder._table with the solve
replaced by the true one plus a CO2 mass fraction of -1e-6 at 2000 K. Exit 0 when the builder refuses it (SystemExit 1,
its message on stdout), 1 when a table comes back.
"""
import os
import sys

import cantera as ct

ROOT = os.path.abspath(sys.argv[1])
os.environ.setdefault('ATLASDIR', ROOT)
sys.path.insert(0, os.path.join(ROOT, 'src', 'GPB'))
from ini.pyrolysis import PyrolysisDefinition   # noqa: E402
from pyrolysis import builder                   # noqa: E402
from pyrolysis import equilibrium as EQ         # noqa: E402

NAMES = ['CO', 'CO2', 'C2H2,acetylene', 'C2H4', 'H', 'H2', 'H2O', 'O', 'OH', 'O2']
db = {s.name: s for s in ct.Species.list_from_file(os.path.join(ROOT, 'database', 'thermo', 'nasa9.yaml'))}
phase = ct.Solution(thermo='ideal-gas', species=[db[n] for n in NAMES])
phase.name = 'CEA-species'                      # the name ideal_gas.build gives the species of a CEA-file run
d = PyrolysisDefinition(section='GPB-Pyrolysis1', name='MX4926', phase=None, elements=['C', 'H', 'O'],
                        massf=[0.60957, 0.10710, 0.28333], pressures=[1.0e5], temperatures=[1500.0, 2000.0],
                        treatment='gas-only')

true_solve = EQ.solve_gas_only


def faulty_solve(gas, seed, p, T, warm=None):
    y, x = true_solve(gas, seed, p, T, warm)
    if T == 2000.0:
        y = y.copy()
        y[gas.species_index('CO2')] = -1.0e-6
    return y, x


EQ.solve_gas_only = faulty_solve
try:
    builder._table(d, 'gas-', [phase])
except SystemExit as e:
    sys.exit(0 if e.code == 1 else 1)
print('[FAIL] a negative mass fraction was written')
sys.exit(1)
