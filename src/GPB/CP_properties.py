import numpy as np
import cantera as ct
import CP_IO

def compute_properties(type, name, T_low, T_max, all_materials):

    print(' -- Build properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    mass_cp = {}
    enthalpy = {}
    density = {}
    conductivity = {}
    materials = []

    # Loop over each material
    for mat in all_materials:

        if mat.type=='cantera':

            n = 0
            species_name = mat.solution.species(n).name
            materials.append(species_name)

            mass_cp[species_name] = []
            enthalpy[species_name] = []
            density[species_name] = []

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

        elif mat.type == 'fixed':

            materials.append(mat.name)

            mass_cp[mat.name] = np.ones(len(temperatures)) * mat.specific_heat
            enthalpy[mat.name] = mass_cp[mat.name] * temperatures
            density[mat.name] = np.ones(len(temperatures)) * mat.density
            conductivity[mat.name] = np.ones(len(temperatures)) * mat.thermal_conductivity

    CP_IO.write_properties(type, name, T_low, T_max, materials, mass_cp, density, enthalpy, conductivity)
