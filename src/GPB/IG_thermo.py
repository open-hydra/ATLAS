import numpy as np
import cantera as ct
import IG_IO as IG_IO, IO_Legacy

def compute_properties(name,T_low, T_max, all_solutions):

    print(' -- Build thermo properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    species_names = []
    molecular_weights = []
    mass_cp_values = {}
    mass_dcp_values = {}
    enthalpy_values = {}
    entropy_values = {}

    # Loop over each solution
    for solution in all_solutions:

        solution.basis = 'mass'
        identity_matrix = np.eye(solution.n_species)

        if 'mixture' not in solution.name:
            # Loop over each species
            for n in range(solution.n_species):
                species_name = solution.species(n).name
                species_names.append(species_name)

                mass_cp_values[species_name] = []
                mass_dcp_values[species_name] = []
                enthalpy_values[species_name] = []
                entropy_values[species_name] = []
                Tp = temperatures[0]
                solution.TPY = Tp, ct.one_atm, identity_matrix[n]
                cpp = solution.cp

                for T in temperatures:
                    if T < solution.species(n).thermo.min_temp or T > solution.species(n).thermo.max_temp:
                        if T < solution.species(n).thermo.min_temp:
                            Tdum = solution.species(n).thermo.min_temp
                        else:
                            Tdum = solution.species(n).thermo.max_temp
                        solution.TPY = Tdum, ct.one_atm, identity_matrix[n]
                        cp = solution.cp
                        h = solution.h + solution.cp * (T - Tdum)
                        s = solution.s + cp * np.log(T / Tdum)
                    else:
                        solution.TPY = T, ct.one_atm, identity_matrix[n]
                        cp = solution.cp
                        h = solution.h
                        s = solution.s
                    if T==Tp:
                        dcp = 0.0
                    else:
                        dcp = (cp-cpp)/(T-Tp)
                    cpp = cp; Tp = T
                    if np.isnan(s): s = 0.0
                    mass_dcp_values[species_name].append(dcp)
                    mass_cp_values[species_name].append(cp)
                    enthalpy_values[species_name].append(h)
                    entropy_values[species_name].append(s)
                molecular_weights.append(solution.molecular_weights[solution.species_index(species_name)])

        else:
            # Just one inert mixture
            if 'CEA' in solution.name or 'cte' in solution.name:
                print('jbe')
                mix_name = solution.name
            else:
                mix_name = solution.name[:-7]
            species_names.append(mix_name)
            mass_dcp_values[mix_name] = []
            mass_cp_values[mix_name] = []
            enthalpy_values[mix_name] = []
            entropy_values[mix_name] = []
            Tp = temperatures[0]
            solution.TP = Tp, ct.one_atm
            cpp = solution.cp
            min_temps = [sp.thermo.min_temp for sp in solution.species()]  # List of min temps for all species
            max_temps = [sp.thermo.max_temp for sp in solution.species()]  # List of max temps for all species
            for T in temperatures:
                if T < max(min_temps) or T > min(max_temps):
                    if T < max(min_temps):
                        Tdum = max(min_temps)
                    else:
                        Tdum = min(max_temps)
                    solution.TP = Tdum, ct.one_atm
                    cp = solution.cp
                    h = solution.h + solution.cp * (T - Tdum)
                    s = solution.s + cp * np.log(T / Tdum)
                else:
                    solution.TP = T, ct.one_atm
                    cp = solution.cp
                    h = solution.h
                    s = solution.s
                if T==Tp:
                    dcp = 0.0
                else:
                    dcp = (cp-cpp)/(T-Tp)
                cpp = cp; Tp = T
                if np.isnan(s): s = 0.0
                mass_dcp_values[mix_name].append(dcp)
                mass_cp_values[mix_name].append(cp)
                enthalpy_values[mix_name].append(h)
                entropy_values[mix_name].append(s)
            molecular_weights.append(solution.mean_molecular_weight)

    IG_IO.write_thermo_properties(name,T_low, T_max, species_names, molecular_weights, mass_cp_values, enthalpy_values, entropy_values, mass_dcp_values)
    #IO_Legacy.write_thermo_properties(T_low, T_max, species_names, molecular_weights, mass_cp_values, enthalpy_values, entropy_values, mass_dcp_values)