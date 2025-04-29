import cantera as ct
import os, sys
import re
from phase_tools import update_thermo_model
from units import convert2si
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

thermo_model = None

def single_case(model, reactor_type, fuel_string, oxi_string, pressure, of):

    temperature_f = convert2si(float(fuel_string[0]), 'K')
    temperature_o = convert2si(float(oxi_string[0]), 'K')
    pressure_chamber = convert2si(pressure, 'bar')

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
        fuel = update_thermo_model(model,thermo_model)
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
        oxi = update_thermo_model(model,thermo_model)
        oxi.TPY = temperature_o, pressure_chamber, oxi_dict

    molar_ratio = of / (oxi.mean_molecular_weight / fuel.mean_molecular_weight)
    moles_oxi = molar_ratio / (1 + molar_ratio)
    moles_fuel = 1 - moles_oxi

    products = update_thermo_model(model,thermo_model)

    # create a mixture of the reactants phases with the products model,
    # with the number of moles for fuel and oxidizer based on the O/F ratio
    mix = ct.Mixture([(fuel, moles_fuel), (oxi, moles_oxi), (products, 0)])

    # Solve for the equilibrium state, at constant enthalpy and pressure
    mix.equilibrate(reactor_type, solver='vcs')

    return products


def run_all(models, reactor_type, fuel_string, oxi_string, pressure, mixture_ratio):
   
    solutions = {}
    for model in models:
        print(' -- Processing: ',model)
        solutions[model] = []
        for of in mixture_ratio:
            for p in pressure:
                cte_solution = single_case(model+'.yaml', reactor_type, fuel_string, oxi_string, p, of)
                solutions[model].append(cte_solution)

    return solutions

