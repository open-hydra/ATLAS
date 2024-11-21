import cantera as ct
import numpy as np
import os, sys
import re
from phase_tools import update_thermo_model
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

hydrocarbons_phase_name = 'FFCM2'

def get_thermo_derivatives(gas):
    '''Gets thermo derivatives based on shifting equilibrium.
    '''
    # unknowns for system with no condensed species:
    # dpi_i_dlogT_P (# elements)
    # dlogn_dlogT_P
    # dpi_i_dlogP_T (# elements)
    # dlogn_dlogP_T
    # total unknowns: 2*n_elements + 2

    num_var = 2 * gas.n_elements + 2

    coeff_matrix = np.zeros((num_var, num_var))
    right_hand_side = np.zeros(num_var)

    tot_moles = 1.0 / gas.mean_molecular_weight
    moles = gas.X * tot_moles

    condensed = False

    # indices
    idx_dpi_dlogT_P = 0
    idx_dlogn_dlogT_P = idx_dpi_dlogT_P + gas.n_elements
    idx_dpi_dlogP_T = idx_dlogn_dlogT_P + 1
    idx_dlogn_dlogP_T = idx_dpi_dlogP_T + gas.n_elements

    # construct matrix of elemental stoichiometric coefficients
    stoich_coeffs = np.zeros((gas.n_elements, gas.n_species))
    for i, elem in enumerate(gas.element_names):
        for j, sp in enumerate(gas.species_names):
            stoich_coeffs[i,j] = gas.n_atoms(sp, elem)

    # equations for derivatives with respect to temperature
    # first n_elements equations
    for k in range(gas.n_elements):
        for i in range(gas.n_elements):
            coeff_matrix[k,i] = np.sum(stoich_coeffs[k,:] * stoich_coeffs[i,:] * moles)
        coeff_matrix[k, gas.n_elements] = np.sum(stoich_coeffs[k,:] * moles)
        right_hand_side[k] = -np.sum(stoich_coeffs[k,:] * moles * gas.standard_enthalpies_RT)

    # skip equation relevant to condensed species

    for i in range(gas.n_elements):
        coeff_matrix[gas.n_elements, i] = np.sum(stoich_coeffs[i, :] * moles)
    right_hand_side[gas.n_elements] = -np.sum(moles * gas.standard_enthalpies_RT)

    # equations for derivatives with respect to pressure

    for k in range(gas.n_elements):
        for i in range(gas.n_elements):
            coeff_matrix[gas.n_elements+1+k,gas.n_elements+1+i] = np.sum(stoich_coeffs[k,:] * stoich_coeffs[i,:] * moles)
        coeff_matrix[gas.n_elements+1+k, 2*gas.n_elements+1] = np.sum(stoich_coeffs[k,:] * moles)
        right_hand_side[gas.n_elements+1+k] = np.sum(stoich_coeffs[k,:] * moles)

    for i in range(gas.n_elements):
        coeff_matrix[2*gas.n_elements+1, gas.n_elements+1+i] = np.sum(stoich_coeffs[i, :] * moles)
    right_hand_side[2*gas.n_elements+1] = np.sum(moles)
    
    derivs = np.linalg.solve(coeff_matrix, right_hand_side)

    dpi_dlogT_P = derivs[idx_dpi_dlogT_P : idx_dpi_dlogT_P + gas.n_elements]
    dlogn_dlogT_P = derivs[idx_dlogn_dlogT_P]
    dpi_dlogP_T = derivs[idx_dpi_dlogP_T]
    dlogn_dlogP_T = derivs[idx_dlogn_dlogP_T]

    # dpi_dlogP_T is not used
    
    return dpi_dlogT_P, dlogn_dlogT_P, dlogn_dlogP_T


def get_thermo_properties(gas, dpi_dlogT_P, dlogn_dlogT_P, dlogn_dlogP_T):
    '''Calculates specific heats, volume derivatives, and specific heat ratio.
    
    Based on shifting equilibrium for mixtures.
    '''
    
    tot_moles = 1.0 / gas.mean_molecular_weight
    moles = gas.X * tot_moles
    
    # construct matrix of elemental stoichiometric coefficients
    stoich_coeffs = np.zeros((gas.n_elements, gas.n_species))
    for i, elem in enumerate(gas.element_names):
        for j, sp in enumerate(gas.species_names):
            stoich_coeffs[i,j] = gas.n_atoms(sp, elem)
    
    spec_heat_p = ct.gas_constant * (
        np.sum([dpi_dlogT_P[i] * 
                np.sum(stoich_coeffs[i,:] * moles * gas.standard_enthalpies_RT) 
                for i in range(gas.n_elements)
                ]) +
        np.sum(moles * gas.standard_enthalpies_RT) * dlogn_dlogT_P +
        np.sum(moles * gas.standard_cp_R) +
        np.sum(moles * gas.standard_enthalpies_RT**2)
        )
    
    dlogV_dlogT_P = 1 + dlogn_dlogT_P
    dlogV_dlogP_T = -1 + dlogn_dlogP_T
    
    spec_heat_v = (
        spec_heat_p + gas.P * gas.v / gas.T * dlogV_dlogT_P**2 / dlogV_dlogP_T
        )

    gamma = spec_heat_p / spec_heat_v
    gamma_s = -gamma/dlogV_dlogP_T
    
    return dlogV_dlogT_P, dlogV_dlogP_T, spec_heat_p, gamma_s



def equilibrium(thermo_model, fuel_string, oxi_string, pressure_string, of):
    from units import convert2si

    phase_name = hydrocarbons_phase_name

    pressure = float(pressure_string[0])
    if len(pressure_string)==1:
      pressure_unit = 'bar'
    else:
      pressure_unit = pressure_string[1]

    temperature_f = convert2si(float(fuel_string[0]), 'K')
    temperature_o = convert2si(float(oxi_string[0]), 'K')
    pressure_chamber = convert2si(pressure, pressure_unit)

    # Define the fuel phase considering lthe possible presence of iquid reactants
    liquid_fuel_names = ['H2(L)', 'CH4(L)']
    liquid_fuel_found = False
    for name in liquid_fuel_names:
        if name in fuel_string[1]:
            liquid_fuel_found = True
            species_list = ct.Species.list_from_file("nasa9.yaml")
            species = next(s for s in species_list if s.name == name)
            fuel = ct.Solution(thermo="ideal-gas", species=[species])
            fuel.TP = temperature_f, pressure_chamber
    if not liquid_fuel_found:
        fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
        fuel_dict = {species: float(value) for species, value in fuel_composition}
        fuel = update_thermo_model(phase_name+'.yaml',thermo_model)
        fuel.TPY = temperature_f, pressure_chamber, fuel_dict

    # Define the oxidizer phase considering the possible presence of liquid reactants
    liquid_oxi_names = ['O2(L)']
    liquid_oxi_found = False
    for name in liquid_oxi_names:
        if name in oxi_string[1]:
            liquid_oxi_found = True
            species_list = ct.Species.list_from_file("nasa9.yaml")
            species = next(s for s in species_list if s.name == name)
            oxi = ct.Solution(thermo="ideal-gas", species=[species])
            oxi.TP = temperature_o, pressure_chamber
    if not liquid_oxi_found:
        oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
        oxi_dict = {species: float(value) for species, value in oxi_composition}
        oxi = update_thermo_model(phase_name+'.yaml',thermo_model)
        oxi.TPY = temperature_o, pressure_chamber, oxi_dict

    molar_ratio = of / (oxi.mean_molecular_weight / fuel.mean_molecular_weight)
    moles_oxi = molar_ratio / (1 + molar_ratio)
    moles_fuel = 1 - moles_oxi

    products = update_thermo_model(phase_name+'.yaml',thermo_model)

    # create a mixture of the reactants phases with the products model,
    # with the number of moles for fuel and oxidizer based on the O/F ratio
    mix = ct.Mixture([(oxi, moles_oxi), (fuel, moles_fuel), (products, 0)])

    # Solve for the equilibrium state, at constant enthalpy and pressure
    mix.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)

    products()

    return products

# derivs = get_thermo_derivatives(products)

# dlogV_dlogT_P, dlogV_dlogP_T, cp, gamma_s = get_thermo_properties(
#     products, derivs[0], derivs[1], derivs[2]
#     )

# print(f'Cp = {cp: .2f} J/(K kg)')

# print(f'(d log V/d log P)_T = {dlogV_dlogP_T: .4f}')
# print(f'(d log V/d log T)_P = {dlogV_dlogT_P: .4f}')

# print(f'gamma_s = {gamma_s: .4f}')

# speed_sound = np.sqrt(ct.gas_constant * products.T * gamma_s / products.mean_molecular_weight)
# print(f'Speed of sound = {speed_sound: .1f} m/s')