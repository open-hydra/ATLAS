import numpy as np
import cantera as ct
import IG_IO as IG_IO
import os, sys

# Ensure the environment variable is set
ATLASDIR = os.environ.get("ATLASDIR")
if ATLASDIR is None:
    print("ERROR: ATLASDIR environment variable is not set.")
    sys.exit(1)


# Import required module
lib = os.path.join(ATLASDIR, "database/Transport/")
sys.path.append(lib)
from Marano import Marano_f


def chempp_wilke(y, mu, k, trueM, names):
    """
    As chempp':
    viscosity    -> Wilke
    conductivity -> Wilke with Phi computed via viscosity
    
    Parameters:
    y (list or numpy array): Mass fractions of species.
    mu (list or numpy array): Viscosities of species (Pa.s or equivalent units).
    k (list or numpy array): Thermal conductivities of species (W/m.K).
    M (list or numpy array): Molecular weights of species (kg/mol or g/mol, but consistent units).
    names (list): Names of the species.
    
    Returns:
    tuple: Mixture viscosity (Pa.s) and mixture thermal conductivity (W/m.K).
    """
    
    n = len(y)
    M = trueM.copy()
    for i in range(n):
        if '-HG' in names[i]: M[i] *= 1e+5
    
    # Calculate the mixture viscosity
    mu_mixture = 0.0
    for i in range(n):
        sum_phi = 0.0
        for j in range(n):
            M_ratio = (M[j] / M[i])**0.25
            ratio = abs((mu[i] / mu[j]))**0.5
            term = (1 + ratio * M_ratio)**2
            phi = term / (np.sqrt(8) * (1 + M[i] / M[j])**0.5)
            sum_phi += y[j]/M[j] * phi
        mu_mixture += y[i]/M[i] * mu[i] / sum_phi
    
    # Calculate the mixture thermal conductivity
    k_mixture = 0.0
    for i in range(n):
        sum_phi = 0.0
        for j in range(n):
            M_ratio = (M[j] / M[i])**0.25
            ratio = abs((mu[i] / mu[j]))**0.5 #abs((k[i] / k[j]))**0.5
            term = (1 + ratio * M_ratio)**2
            phi = term / (np.sqrt(8) * (1 + M[i] / M[j])**0.5)
            sum_phi += y[j]/M[j] * phi
        k_mixture +=  y[i]/M[i] * k[i] / sum_phi
    
    return mu_mixture, k_mixture


def cantera_wilke_mathur(y, mu, k, trueM, names):
    """
    As Cantera 'mixture-averaged':
    viscosity    -> Wilke
    conductivity -> Mathur
    
    Parameters:
    y (list or numpy array): Mass fractions of species.
    mu (list or numpy array): Viscosities of species (Pa.s or equivalent units).
    k (list or numpy array): Thermal conductivities of species (W/m.K).
    M (list or numpy array): Molecular weights of species (kg/mol or g/mol, but consistent units).
    names (list): Names of the species.
    
    Returns:
    tuple: Mixture viscosity (Pa.s) and mixture thermal conductivity (W/m.K).
    """
    
    n = len(y)
    M = trueM.copy()
    for i in range(n):
        if '-HG' in names[i]: M[i] *= 1e+5
    
    # Calculate the mixture viscosity
    mu_mixture = 0.0
    for i in range(n):
        sum_phi = 0.0
        for j in range(n):
            M_ratio = (M[j] / M[i])**0.25
            ratio = abs((mu[i] / mu[j]))**0.5
            term = (1 + ratio * M_ratio)**2
            phi = term / (np.sqrt(8) * (1 + M[i] / M[j])**0.5)
            sum_phi += y[j]/M[j] * phi
        mu_mixture += y[i]/M[i] * mu[i] / sum_phi
    
    # Calculate the mixture thermal conductivity
    term1 = 0.0
    term2 = 0.0
    S = np.sum(y/M)
    for i in range(n):
        x = y[i] / M[i] / S
        term1 += x * k[i]
        term2 += x / k [i]
    k_mixture =  0.5*( term1 + 1 / term2 )
    
    return mu_mixture, k_mixture


# Formule contenute in chempp, strutturalmente simili a quelle contenute in cantera.
# Per la conducibilita chempp usa cv_rot=0
    # visc = 5.0/16.0 * sqrt(Pi * mw[k] * Boltzmann * t / Avogadro) /
    #        (om22 * Pi * m_sigma[k]*m_sigma[k]);
    #
    # double f_int = mw[k]/(GasConstant * t) * diffcoeff/visc;
    # double cv_rot = m_crot[k];
    # double A_factor = 2.5 - f_int;
    # double fz_tstar = 1.0 + pow(Pi, 1.5) / sqrt(tstar) * (0.5 + 1.0 / tstar) +
    #     (0.25 * Pi * Pi + 2) / tstar;
    # double B_factor = m_zrot[k] * fz_298 / fz_tstar + 2.0/Pi * (5.0/3.0 * cv_rot + f_int);
    # double c1 = 2.0/Pi * A_factor/B_factor;
    # double cv_int = cp_R - 2.5 - cv_rot;
    # double f_rot = f_int * (1.0 + c1);
    # double f_trans = 2.5 * (1.0 - c1 * cv_rot/1.5);
    # double cond = (visc/mw[k])*GasConstant*(f_trans * 1.5
    #                                     + f_rot * cv_rot + f_int * cv_int);
def simplified_law(T,wm,cp):
  omega = max(np.log(50.0 * wm**4.6 / T**1.4),1.0)
  mu = 26.6957937 * np.sqrt(wm * T) / omega
  cpadim = cp * wm / ct.gas_constant
  k = mu * ct.gas_constant * (0.00375 + 0.00132 * (cpadim - 2.5)) / wm
  mu *= 1.0e-07
  k *= 1.0e-04
  if (k<0):
    print(T,wm,omega,cp,ct.gas_constant)
    exit(1)
  return mu, k


def CEA_polynomials(T,database):

    for v in database['viscosity']:
        if np.min(v['temperature_range']) <= T <= np.max(v['temperature_range']):
            VC = v['coefficients']

    for c in database['conductivity']:
        if np.min(c['temperature_range']) <= T <= np.max(c['temperature_range']):
            CC = c['coefficients']

    if T < np.min(database['viscosity'][0]['temperature_range']):
        T = np.min(database['viscosity'][0]['temperature_range'])
        VC = database['viscosity'][0]['coefficients']
        CC = database['conductivity'][0]['coefficients']

    if T > np.max(database['viscosity'][len(database['viscosity'])-1]['temperature_range']):
        T = np.max(database['viscosity'][len(database['viscosity'])-1]['temperature_range'])
        VC = database['viscosity'][len(database['viscosity'])-1]['coefficients']
        CC = database['conductivity'][len(database['conductivity'])-1]['coefficients']

    mu = VC[0] * np.log(T) + VC[1] / T + VC[2] / (T * T) + VC[3]
    mu = 1.0e-07 * np.exp(mu)
    k = CC[0] * np.log(T) + CC[1] / T + CC[2] / (T * T) + CC[3]
    k = 1.0e-04 * np.exp(k) # 1e-4 derives from the conversion \muW/cm*K -> W/m*k

    return mu, k


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
