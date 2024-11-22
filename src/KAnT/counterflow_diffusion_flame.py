import cantera as ct
import os, sys
import re
from units import convert2si
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

def counterflow(model, fuel_string, oxi_string, pressure, of, mtot, width):

    # Input parameters
    tin_f = convert2si(float(fuel_string[0]), 'K')
    tin_o = convert2si(float(oxi_string[0]), 'K')
    p = convert2si(pressure, 'bar')
    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
    oxi_dict = {species: float(value) for species, value in oxi_composition}
    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
    fuel_dict = {species: float(value) for species, value in fuel_composition}
    mdot_o = mtot*of/(1+of)
    mdot_f = mtot-mdot_o

    loglevel = 0  # amount of diagnostic output (0 to 5)

    gas = ct.Solution(model+'.yaml')
    #gas = add_species(species_name,old_phase,source):
    gas.TP = 300.0, p

    # Create an object representing the counterflow flame configuration,
    # which consists of a fuel inlet on the left, the flow in the middle,
    # and the oxidizer inlet on the right.
    f = ct.CounterflowDiffusionFlame(gas, width=width)

    # Set the state of the two inlets
    f.fuel_inlet.mdot = mdot_f
    f.fuel_inlet.Y = fuel_dict
    f.fuel_inlet.T = tin_f

    f.oxidizer_inlet.mdot = mdot_o
    f.oxidizer_inlet.Y = oxi_dict
    f.oxidizer_inlet.T = tin_o

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
        print(' -- Processing: ',model)
        x_, T_ = counterflow(model, fuel_string, oxi_string, pressure, of, mdot, width)
        x[model] = x_
        T[model] = T_

    return x, T