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


def compute_binary_diffusion(name, T_low, T_max, all_solutions):
    """
    Build the binary diffusion coefficient table D_ij(T) for the multicomponent
    diffusion model and write it to diffusion.dat.

    Binary diffusion coefficients are a kinetic-theory pair property (composition
    independent), so a single mixture-averaged Cantera solution holding all real
    species in phase.txt order is sampled over the temperature grid. Only the unique
    upper-triangular pairs (i<j) are stored, since D_ij = D_ji.
    """
    print(' -- Build binary diffusion coefficients')

    # Gather the real (non-mixture) species in phase.txt order, from their parent
    # solutions. Mixture pseudo-species are frozen mixtures, not real species, so a
    # binary diffusion coefficient is undefined for them.
    species_objs = []
    species_names = []
    has_mixture = False
    for solution in all_solutions:
        if 'mixture' in solution.name:
            has_mixture = True
            continue
        for n in range(solution.n_species):
            species_objs.append(solution.species(n))
            species_names.append(solution.species(n).name)

    if has_mixture:
        print("    Warning: mixture pseudo-species present; diffusion.dat is only "
              "defined for real species and will be skipped.")
        return

    ns = len(species_names)
    if ns < 2:
        return   # single species: no pairs, nothing to write

    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)
    npair = ns * (ns - 1) // 2
    Dij = np.zeros((npair, len(temperatures)))

    # Reference pressure at which the binary coefficients are tabulated (D ~ 1/p).
    pref = ct.one_atm

    try:
        # Combined mixture-averaged phase exposing binary_diff_coeffs for every pair.
        # NB: use the `transport_model=` kwarg; the `transport=` form does not stick
        # when building from bare Species objects (model silently falls back to 'none').
        combined = ct.Solution(thermo='ideal-gas', species=species_objs,
                               transport_model='mixture-averaged')
        for ti, T in enumerate(temperatures):
            combined.TP = T, pref
            D = combined.binary_diff_coeffs        # (ns, ns) matrix, m^2/s
            p = 0
            for i in range(ns):
                for j in range(i + 1, ns):
                    Dij[p, ti] = D[i, j]
                    p += 1
    except Exception as e:
        print(f"    Warning: binary diffusion coefficients unavailable "
              f"(missing transport data?): {e}. diffusion.dat skipped.")
        return

    # Cantera's binary-diffusion polynomial fits can extrapolate to non-physical
    # negative values at very low temperature (below ~40 K, never reached in a real
    # run). Clamp each pair's low-T tail to its smallest positive value so the table
    # stays strictly positive, consistent with the viscosity/conductivity tables.
    for p in range(npair):
        positive = Dij[p][Dij[p] > 0.0]
        if positive.size:
            Dij[p][Dij[p] <= 0.0] = positive.min()

    IG_IO.write_diffusion_properties(name, T_low, T_max, species_names, Dij, pref)
