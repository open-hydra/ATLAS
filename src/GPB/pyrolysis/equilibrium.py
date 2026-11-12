"""Equilibrium of the pyrolysis gas at (p, T) for a given elemental makeup (brief D13 as measured, plan A0):
gas-only with Cantera on the species objects of the ideal-gas phase GPB built (the thermo of its thermo.dat);
strip with the cea binding (graphite allowed, then removed and the gas renormalised).
Mass fractions are on the molar masses of <name>-phase.txt (Cantera's), so that the elements of a gas-only row
equal the makeup to round-off."""
import sys
import warnings

import numpy as np
import cantera as ct

# Standard-state pressure given to the NASA-9 species for the gas-only solve [Pa]. database/thermo/nasa9.yaml carries no
# reference-pressure, so Cantera takes 1 atm, while CEA (whose thermo.inp the file comes from) evaluates the same
# coefficients at 1 bar (lib/cea/source/equilibrium.f90:938). DECISION D-A1 of the plan: 1.0e5 (branch B) or None
# (branch A: the file as it is).
NASA9_REFERENCE_PRESSURE = 1.0e5


class NotConverged(Exception):
    pass


def _nnls(A, b, tol):
    """Lawson-Hanson non-negative least squares: x >= 0 minimising |A x - b|."""
    n = A.shape[1]
    x = np.zeros(n)
    passive = np.zeros(n, dtype=bool)
    w = A.T @ (b - A @ x)
    for _ in range(3 * n + 10):
        if passive.all() or np.where(passive, -np.inf, w).max() <= tol:
            break
        passive[int(np.argmax(np.where(passive, -np.inf, w)))] = True
        while True:
            z = np.zeros(n)
            z[passive] = np.linalg.lstsq(A[:, passive], b, rcond=None)[0]
            if (z[passive] > tol).all():
                x = z
                break
            neg = passive & (z <= tol)
            denom = x[neg] - z[neg]
            alpha = np.min(np.where(denom > 0.0, x[neg] / np.where(denom > 0.0, denom, 1.0), 0.0))
            x = x + alpha * (z - x)
            passive &= x > tol
        w = A.T @ (b - A @ x)
    return x


def element_moles(elements, massf):
    """kmol of each element per kg of pyrolysis gas, on Cantera's atomic weights (those of phase.txt)."""
    return np.array([w / ct.Element(e).weight for e, w in zip(elements, massf)])


def gas_only_solution(species):
    """An ideal-gas Solution of *species* (Cantera Species objects, phase.txt order); NASA-9 species take
    NASA9_REFERENCE_PRESSURE."""
    out = []
    for sp in species:
        if NASA9_REFERENCE_PRESSURE is not None and isinstance(sp.thermo, ct.Nasa9PolyMultiTempRegion):
            d = dict(sp.input_data)
            th = dict(d['thermo'])
            th['reference-pressure'] = NASA9_REFERENCE_PRESSURE
            d['thermo'] = th
            sp = ct.Species.from_dict(d)
        out.append(sp)
    return ct.Solution(thermo='ideal-gas', species=out)


def feasible_seed(gas, elements, b):
    """Mole numbers n >= 0 of the gas species with exactly the element moles b (None when the species cannot carry
    the makeup, e.g. more carbon than CO and CO2 can hold with the makeup's oxygen and no hydrocarbon)."""
    A = np.array([[gas.n_atoms(k, e) for k in range(gas.n_species)] for e in elements], dtype=float)
    n = _nnls(A, b, 1.0e-14 * b.max())
    if np.abs(A @ n - b).max() > 1.0e-10 * b.max():
        return None
    return n


def solve_gas_only(gas, seed, p, T, warm=None):
    """Mass fractions (phase.txt order) of the equilibrium at (p [Pa], T [K]); one retry from *warm* (the mole
    fractions of the previous converged point); NotConverged after that."""
    for start in (seed, warm):
        if start is None:
            continue
        try:
            gas.TPX = T, p, start
            gas.equilibrate('TP')
            return gas.Y.copy(), gas.X.copy()
        except ct.CanteraError:
            continue
    raise NotConverged()


class StripSolver:
    """cea: products = the table species + C(gr) (when the makeup has carbon); reactant = one pseudo-molecule with the
    makeup's element moles."""

    def __init__(self, names, elements, b, molar_masses, section):
        import cea
        self.cea = cea
        self.names = list(names)
        products = self.names + (['C(gr)'] if 'C' in elements else [])
        try:
            self.reac = cea.Mixture([cea.Reactant('PYROLYSIS-GAS', formula={e.upper(): x for e, x in zip(elements, b)})])
            self.prod = cea.Mixture(products)
        except RuntimeError as e:
            missing = str(e).split('Species not found in ThermoDB:')[-1].strip() if 'ThermoDB' in str(e) else str(e)
            print(f"[ERROR] section [{section}]: treatment = strip: species {missing} of the gas list is not in the CEA "
                  f"database (lib/cea thermo.lib): the strip treatment needs every C/H/O... species of the table under its CEA name")
            sys.exit(1)
        # insert C(gr): CEA starts with graphite present; without it a gas list with no hydrocarbon converges at no point
        # (0 of 418 on the user's grid, 418 of 418 with it; the same equilibrium within 1.4e-8 where both converge)
        self.solver = cea.EqSolver(self.prod, reactants=self.reac, insert=['C(gr)'] if 'C' in elements else [])
        self.order = list(self.prod.species_names)
        self.M = dict(molar_masses)
        self.M['C(gr)'] = ct.Element('C').weight

    def solve(self, p, T, warm=None):
        """(gas mass fractions in the table order, X_C, nj for a warm start); one retry from *warm* (the nj of the
        previous converged point); NotConverged after that."""
        for start in ([None] if warm is None else [None, warm]):
            if start is None:
                sol = self.cea.EqSolution(self.solver)
            else:
                sol = self.cea.EqSolution(self.solver, T_init=float(T), nj_init=start)
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', RuntimeWarning)   # cea warns 'EqSolver.solve: CEA_NOT_CONVERGED'
                self.solver.solve(sol, self.cea.TP, float(T), float(p) * 1.0e-5, np.array([1.0]))
            if sol.converged:
                nj = np.array(sol.nj, dtype=float)
                mass = {n: nj[i] * self.M[n] for i, n in enumerate(self.order)}
                mc = mass.get('C(gr)', 0.0)
                mg = sum(v for n, v in mass.items() if n != 'C(gr)')
                return np.array([mass[n] / mg for n in self.names]), mc / (mg + mc), nj
        raise NotConverged()
