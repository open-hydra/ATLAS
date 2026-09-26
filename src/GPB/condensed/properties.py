import numpy as np
import cantera as ct
from . import io as CP_IO
import sys
from config import THERMO_DIR

# Import required module
sys.path.append(THERMO_DIR)
from sp_custom import compute_properties_from_database

T_REF = 298.15   # [K] datum temperature of the optional [GPB-Phase*] h0 (enthalpy-of-formation convention)
P_REF_DB = 1.0e5 # [Pa] standard state of the NASA Glenn and Burcat polynomials (1 bar). Not
                 # sp.thermo.reference_pressure: these YAML files carry none, so Cantera reports 101325 Pa


def resolve_psat_pair(section, material, pair, species, thermo_file):
    """(liquid, vapour) Species of a material's p_sat pair, looked up in the loaded database only. Refused
    unless both names are in it, both are NASA7/NASA9 fits and both have the same elemental composition
    (which cannot tell isomers apart: psat_from_pair prints the implied boiling point for that)."""
    liquid, vapour = pair
    what = f"[ERROR] [{section}] material {material}, psat-liquid '{liquid}' / psat-vapour '{vapour}'"
    for sp_name in (liquid, vapour):
        if sp_name not in species:
            raise SystemExit(f"{what}: no species '{sp_name}' in {thermo_file}")
    liq, vap = species[liquid], species[vapour]
    for sp in (liq, vap):
        model = sp.input_data.get('thermo', {}).get('model')
        if model not in ('NASA7', 'NASA9'):
            raise SystemExit(f"{what}: '{sp.name}' is a {model} entry of {thermo_file}, not a NASA7/NASA9 fit")
    comp = [{e: n for e, n in sp.composition.items() if n != 0} for sp in (liq, vap)]
    if comp[0] != comp[1]:
        raise SystemExit(f"{what}: different elemental compositions {comp[0]} and {comp[1]}")
    return liq, vap


def psat_from_pair(liq, vap, temperatures, material):
    """p_sat(T) [Pa] on the table nodes from the Gibbs-energy difference of a liquid/vapour pair,
    ln p_sat = ln P_REF_DB - (g_vap - g_liq)/(R T), inside the temperature range the two fits share; outside it
    the Clausius-Clapeyron line through the nearer end of that range, with dh = h_vap - h_liq taken there."""
    R = ct.gas_constant   # [J/kmol/K]: sp.thermo.h is in J/kmol, sp.thermo.s in J/kmol/K
    T_lo = max(liq.thermo.min_temp, vap.thermo.min_temp)
    T_hi = min(liq.thermo.max_temp, vap.thermo.max_temp)
    what = f"[ERROR] material {material}, psat pair {liq.name}/{vap.name}"
    if not T_lo < T_hi:
        raise SystemExit(f"{what}: the two fits share no temperature range")

    def ln_psat(T):
        Te = min(max(T, T_lo), T_hi)   # the fits are evaluated inside their common range only
        dh = vap.thermo.h(Te) - liq.thermo.h(Te)
        dg = dh - Te * (vap.thermo.s(Te) - liq.thermo.s(Te))
        return np.log(P_REF_DB) - dg / (R * Te) - dh / R * (1.0 / T - 1.0 / Te), dh, Te

    ln_p = np.empty(len(temperatures))
    for i, T in enumerate(temperatures):
        ln_p[i], dh, Te = ln_psat(T)
        if not dh > 0.0:
            raise SystemExit(f"{what}: h_vap - h_liq = {dh / vap.molecular_weight / 1e3:.6g} kJ/kg at {Te:g} K, "
                             "not a vaporisation enthalpy")

    # implied normal boiling point: printed, the one symptom of a wrong isomer
    lo, hi = min(temperatures[0], T_lo), max(temperatures[-1], T_hi)
    ln_atm = np.log(ct.one_atm)
    if ln_psat(lo)[0] > ln_atm or ln_psat(hi)[0] < ln_atm:
        boiling = f"no normal boiling point in {lo:g}-{hi:g} K"
    else:
        for _ in range(60):
            mid = 0.5 * (lo + hi)
            lo, hi = (mid, hi) if ln_psat(mid)[0] < ln_atm else (lo, mid)
        T_nb = 0.5 * (lo + hi)
        boiling = (f"normal boiling point {T_nb:.2f} K, h_vap - h_liq there "
                   f"{ln_psat(T_nb)[1] / vap.molecular_weight / 1e3:.1f} kJ/kg")
    outside = int(np.count_nonzero((temperatures < T_lo) | (temperatures > T_hi)))
    print(f' -- Psat of {material}: {liq.name}/{vap.name}, common range {T_lo:g}-{T_hi:g} K'
          + (f' ({outside} nodes outside it follow Clausius-Clapeyron)' if outside else '') + f', {boiling}')
    return np.exp(ln_p)


def compute_properties(type, name, T_low, T_max, all_materials):

    print(' -- Build properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    mass_cp = {}
    enthalpy = {}
    density = {}
    conductivity = {}
    energy = {}
    psat = {}        # only the paired materials; the others get zeros once one is paired
    materials = []
    datum = set()   # 'absolute' | 'relative' per material; the file carries ONE datum (io.py names the column)

    # Loop over each material
    for mat in all_materials:

        if mat.type=='cantera':

            n = 0
            species_name = mat.solution.species(n).name
            materials.append(species_name)

            mass_cp[species_name] = []
            enthalpy[species_name] = []
            density[species_name] = []
            conductivity[species_name] = []   # the solid layout (io.py) indexes these two for EVERY branch
            energy[species_name] = []
            datum.add('absolute')             # cantera h includes the formation enthalpy

            Tp = temperatures[0]
            mat.solution.TP = Tp, ct.one_atm

            solution = mat.solution
            mat.solution.basis = 'mass'

            for T in temperatures:
                if T < solution.species(n).thermo.min_temp or T > solution.species(n).thermo.max_temp:
                    if T < solution.species(n).thermo.min_temp:
                        Tdum = solution.species(n).thermo.min_temp
                    else:
                        Tdum = solution.species(n).thermo.max_temp
                    solution.TP = Tdum, ct.one_atm
                    cp = solution.cp
                    h = solution.h + solution.cp * (T - Tdum)
                else:
                    solution.TP = T, ct.one_atm
                    cp = solution.cp
                    h = solution.h
                mass_cp[species_name].append(cp)
                enthalpy[species_name].append(h)
                density[species_name].append(mat.density)
                conductivity[species_name].append(mat.thermal_conductivity)
                energy[species_name].append(mat.density * h)   # volumetric, like rho*cp*T of the fixed branch

        elif mat.type == 'fixed':

            materials.append(mat.name)

            mass_cp[mat.name] = np.ones(len(temperatures)) * mat.specific_heat
            if mat.h0 is None:
                enthalpy[mat.name] = mass_cp[mat.name] * temperatures
                datum.add('relative')
            else:
                # absolute datum: h(T) = cp*T + (h0 - cp*T_REF), so that h(T_REF) = h0
                enthalpy[mat.name] = mass_cp[mat.name] * temperatures + (mat.h0 - mat.specific_heat * T_REF)
                datum.add('absolute')
            density[mat.name] = np.ones(len(temperatures)) * mat.density
            conductivity[mat.name] = np.ones(len(temperatures)) * mat.thermal_conductivity
            energy[mat.name] = density[mat.name] * mass_cp[mat.name] * temperatures

        elif mat.type == 'SP-database':

            materials.append(mat.name)
            mass_cp[mat.name], density[mat.name], conductivity[mat.name], energy[mat.name] = compute_properties_from_database(mat.name,temperatures)
            enthalpy[mat.name] = energy[mat.name] / density[mat.name]   # dispersed layout needs it; e(Tmin) = 0 -> relative
            datum.add('relative')

        if mat.psat_pair is not None:
            psat[materials[-1]] = psat_from_pair(*mat.psat_pair, temperatures, materials[-1])

    if len(datum) > 1:
        raise SystemExit("[ERROR] condensed materials mix absolute and relative enthalpy data in one phase: "
                         "give h0 for every fixed-cp material or for none")
    enthalpy_absolute = (datum == {'absolute'})
    print(' -- Enthalpy column datum:', 'absolute (Enthalpy_abs)' if enthalpy_absolute else 'relative cp*T (Enthalpy)')
    if psat:
        psat = {m: psat.get(m, np.zeros(len(temperatures))) for m in materials}
    CP_IO.write_properties(type, name, T_low, T_max, materials, mass_cp, density, enthalpy, conductivity, energy,
                           enthalpy_absolute=enthalpy_absolute, psat=psat or None)
