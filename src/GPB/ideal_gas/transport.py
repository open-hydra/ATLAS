import numpy as np
import cantera as ct
from . import io as IG_IO
import os, sys
from config import TRANSPORT_DIR
from mixing_rules import chempp_wilke, cantera_wilke_mathur, simplified_law, CEA_polynomials

# Import required module
sys.path.append(TRANSPORT_DIR)
from Marano import Marano_f


def compute_properties(name, model, T_low, T_max, all_solutions, **kwargs):

    print(' -- Build transport properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    species_names = []
    viscosity = {}
    conductivity = {}

    # Loop over each solution
    for solution in all_solutions:

        solution.basis = 'mass'
        identity_matrix = np.eye(solution.n_species)
        
        species_names_aux = []
        viscosity_aux = {}
        conductivity_aux = {}
        for n in range(solution.n_species):
            # Loop over each species
            species_name = solution.species(n).name
            species_names_aux.append(species_name)

            viscosity_aux[species_name] = []
            conductivity_aux[species_name] = []

            for T in temperatures:
                mu, k = None, None
                species_found = False
                if (species_name=='C32H66'): #for now only exception
                  mu, k = Marano_f(T)
                elif (model == 'cantera'):
                    solution.TPY = T, ct.one_atm, identity_matrix[n]
                    mu = solution.viscosity
                    k = solution.thermal_conductivity
                elif (model=='CEA'):
                    for species in kwargs["database"]:
                        if species['element'] == solution.species(n).name:
                            mu, k = CEA_polynomials(T,species)
                elif (model=='constant'):
                    mu = kwargs['mil'][n]
                    k = kwargs['kl'][n]

                if mu is not None:
                    species_found = True
                    viscosity_aux[species_name].append(mu)
                    conductivity_aux[species_name].append(k)
                else:
                    if T < solution.species(n).thermo.min_temp or T > solution.species(n).thermo.max_temp:
                        if T < solution.species(n).thermo.min_temp:
                            Tdum = solution.species(n).thermo.min_temp
                        else:
                            Tdum = solution.species(n).thermo.max_temp
                        cp = solution.species(n).thermo.cp(Tdum)
                    else:
                        cp = solution.species(n).thermo.cp(T)
                    mu, k = simplified_law(T,solution.molecular_weights[n],cp/solution.molecular_weights[n])
                    viscosity_aux[species_name].append(mu)
                    conductivity_aux[species_name].append(k)

            if not species_found:
                    print(f"Warning: Transport model is not valid for species '{species_name}'.")
                    print(f"         CEA simplified law is applied!")

        if 'mixture' not in solution.name:
            for sp in species_names_aux:
                species_names.append(sp)
                viscosity[sp] = viscosity_aux[sp]
                conductivity[sp] = conductivity_aux[sp]
        else:
            if 'CEA' in solution.name or 'cte' in solution.name:
                mix_name = solution.name
            else:
                mix_name = solution.name[:-7]
            species_names.append(mix_name)
            for i, T in enumerate(temperatures):
                solution.TP = T, ct.one_atm
                if (model == 'cantera'):
                    mu = solution.viscosity
                    k = solution.thermal_conductivity
                else:
                    viscosities_at_temp = []
                    conductivities_at_temp = []
                    for species in species_names_aux:
                        viscosities_at_temp.append(viscosity_aux[species][i])
                        conductivities_at_temp.append(conductivity_aux[species][i])
                    mu, k  = chempp_wilke(solution.Y, viscosities_at_temp, conductivities_at_temp, solution.molecular_weights, solution.species_names)
                viscosity.setdefault(mix_name, []).append(mu)
                conductivity.setdefault(mix_name, []).append(k)


    IG_IO.write_transport_properties(name, T_low, T_max, species_names, viscosity, conductivity)
