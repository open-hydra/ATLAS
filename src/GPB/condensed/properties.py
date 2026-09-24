import numpy as np
import cantera as ct
from . import io as CP_IO
import sys
from config import THERMO_DIR

# Import required module
sys.path.append(THERMO_DIR)
from sp_custom import compute_properties_from_database

T_REF = 298.15   # [K] datum temperature of the optional [GPB-Phase*] h0 (enthalpy-of-formation convention)

def compute_properties(type, name, T_low, T_max, all_materials):

    print(' -- Build properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    mass_cp = {}
    enthalpy = {}
    density = {}
    conductivity = {}
    energy = {}
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

    if len(datum) > 1:
        raise SystemExit("[ERROR] condensed materials mix absolute and relative enthalpy data in one phase: "
                         "give h0 for every fixed-cp material or for none")
    enthalpy_absolute = (datum == {'absolute'})
    print(' -- Enthalpy column datum:', 'absolute (Enthalpy_abs)' if enthalpy_absolute else 'relative cp*T (Enthalpy)')
    CP_IO.write_properties(type, name, T_low, T_max, materials, mass_cp, density, enthalpy, conductivity, energy,
                           enthalpy_absolute=enthalpy_absolute)
