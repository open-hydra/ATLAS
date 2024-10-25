import cantera as ct
import matplotlib.pyplot as plt
from pint import UnitRegistry
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


def define_model(model):
    # Load the original chemical mechanism
    original_mechanism = ct.Solution(model+'.yaml')
    # List of original species
    original_species = original_mechanism.species()
    new_species = original_species.copy()

    nasa_gas = ct.Species.list_from_file('nasa_gas.yaml')

    # Find and add N2 species from nasa_gas if missing
    if 'N2' not in original_mechanism.species_names:
        N2_species = next((species for species in nasa_gas if species.name == 'N2'), None)
        if N2_species:
            new_species.append(N2_species)

    # Find and add Ar species from nasa_gas if missing
    if 'AR' not in original_mechanism.species_names:
        Ar_species = next((species for species in nasa_gas if species.name == 'AR'), None)
        if Ar_species:
            new_species.append(Ar_species)

    # Create a new Solution with the combined species list and the original reactions
    new_mechanism = ct.Solution(thermo='ideal-gas', species=new_species, kinetics='gas', reactions=original_mechanism.reactions())
    new_mechanism.transport_model = original_mechanism.transport_model
    new_mechanism.name = original_mechanism.name

    return new_mechanism


def counterflow(model, fuel_string, oxi_string, pressure, of, mtot, width):

    ureg = UnitRegistry()
    Q_ = ureg.Quantity

    # Input parameters
    tin_f = Q_(float(fuel_string[0]), 'K')
    tin_o = Q_(float(oxi_string[0]), 'K')
    p = Q_(pressure, 'bar')
    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
    oxi_dict = {species: float(value) for species, value in oxi_composition}
    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
    fuel_dict = {species: float(value) for species, value in fuel_composition}
    mdot_o = mtot*of/(1+of)
    mdot_f = mtot-mdot_o

    loglevel = 0  # amount of diagnostic output (0 to 5)

    gas = define_model(model)
    gas.TP = 300.0, to_si(p)

    # Create an object representing the counterflow flame configuration,
    # which consists of a fuel inlet on the left, the flow in the middle,
    # and the oxidizer inlet on the right.
    f = ct.CounterflowDiffusionFlame(gas, width=width)

    # Set the state of the two inlets
    f.fuel_inlet.mdot = mdot_f
    f.fuel_inlet.Y = fuel_dict
    f.fuel_inlet.T = to_si(tin_f)

    f.oxidizer_inlet.mdot = mdot_o
    f.oxidizer_inlet.Y = oxi_dict
    f.oxidizer_inlet.T = to_si(tin_o)

    # Set the boundary emissivities
    f.boundary_emissivities = 0.0, 0.0
    # Turn radiation on
    f.radiation_enabled = True

    f.set_refine_criteria(ratio=2, slope=0.2, curve=0.3, prune=0.04)

    # Solve the problem
    f.solve(loglevel, auto=True)

    # output = "diffusion_flame.yaml"
    # output.unlink(missing_ok=True)
    # f.save(output)
    # # write the velocity, temperature, and mass fractions to a CSV file
    # f.save('diffusion_flame.csv', basis="mass", overwrite=True)

    #f.show_stats(0)
    return f.flame.grid, f.T


def run_all(models, fuel_string, oxi_string, pressure, of, mdot, width):
   
    x = {}; T = {}
    for model in models:
        x[model] = []; T[model] = []
        print(model)
        x_, T_ = counterflow(model, fuel_string, oxi_string, pressure, of, mdot, width)
        x[model] = x_
        T[model] = T_

    return x, T