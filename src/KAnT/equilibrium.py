from pint import UnitRegistry
import cantera as ct
import numpy as np
import os, sys
import re
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

# for convenience:
def to_si(quant):
    '''Converts a Pint Quantity to magnitude at base SI units.
    '''
    return quant.to_base_units().magnitude

def equilibrium(model, fuel_string, oxi_string, pressure, of):
    model += '.yaml'

    ureg = UnitRegistry()
    Q_ = ureg.Quantity

    temperature_f = Q_(float(fuel_string[0]), 'K')
    temperature_o = Q_(float(oxi_string[0]), 'K')
    pressure_chamber = Q_(pressure, 'bar')

    if 'CH4(L)' in fuel_string[1]:
        fuel = ct.Solution('reactants.yaml','CH4(L)')
        fuel.TP = to_si(temperature_f), to_si(pressure_chamber)
    elif 'H2(L)' in fuel_string[1]:
        fuel = ct.Solution('reactants.yaml','H2(L)')
        fuel.TP = to_si(temperature_f), to_si(pressure_chamber)
    else:
        fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
        fuel_dict = {species: float(value) for species, value in fuel_composition}
        fuel = ct.Solution(model)
        fuel.TPY = to_si(temperature_f), to_si(pressure_chamber), fuel_dict

    if 'O2(L)' in oxi_string[1]:
        oxi = ct.Solution('reactants.yaml','O2(L)')
        oxi.TP = to_si(temperature_f), to_si(pressure_chamber)
    else:
        oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
        oxi_dict = {species: float(value) for species, value in oxi_composition}
        oxi = ct.Solution(model)
        oxi.TPY = to_si(temperature_o), to_si(pressure_chamber), oxi_dict

    molar_ratio = of / (oxi.mean_molecular_weight / fuel.mean_molecular_weight)
    moles_oxi = molar_ratio / (1 + molar_ratio)
    moles_fuel = 1 - moles_oxi

    products = ct.Solution(model)

    # create a mixture of the reactants phases with the products model,
    # with the number of moles for fuel and oxidizer based on the O/F ratio
    mix = ct.Mixture([(oxi, moles_oxi), (fuel, moles_fuel), (products, 0)])

    # Solve for the equilibrium state, at constant enthalpy and pressure
    mix.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)

    #products()

    return products


def run_all(models, fuel_string, oxi_string, pressure, mixture_ratio):
   
    Ta = {}
    for model in models:
        Ta[model] = []
        for of in mixture_ratio:
            for p in pressure:
                cte_solution = equilibrium(model, fuel_string, oxi_string, p, of)
                Ta[model].append(cte_solution.T)

    return Ta

