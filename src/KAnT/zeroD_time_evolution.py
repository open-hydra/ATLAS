import numpy as np
import cantera as ct
import sys, os, re
from units import convert2si
from phase_tools import *
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

#################################################################################

def run_all(models, reactor_type, fuel_string, oxi_string, pressures, mixture_ratio, temperatures, tend, nstep):

    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
    fuel_dict = {species: float(value) for species, value in fuel_composition}

    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
    oxi_dict = {species: float(value) for species, value in oxi_composition}

    Tout = {}
    pout = {}

    for model in models:
        print(' -- Processing: ',model)

        new_mechanism = add_species('N2',ct.Solution(model+'.yaml'),'nasa9')
        new_mechanism = add_species('Ar',new_mechanism,'nasa9')
        Tout[model] = []
        pout[model] = []

        # Loop over temperatures
        for temperature in temperatures:
            for pressure in pressures:
                press = convert2si(pressure, 'bar')
                for mr in mixture_ratio:

                    tout = []

                    setup_mixture(new_mechanism, fuel_dict, oxi_dict, mr)
                    new_mechanism.TP = temperature, press

                    if reactor_type=='HP':
                      r = ct.IdealGasConstPressureReactor(contents=new_mechanism, name="Batch Reactor")
                    else:
                      r = ct.IdealGasReactor(contents=new_mechanism, name="Batch Reactor")
                    reactor_network = ct.ReactorNet([r])
                    # Set the ODE tollerances and max time step
                    rtol = 1.e-7
                    atol = 1.e-7
                    reactor_network.rtol, reactor_network.atol = rtol, atol
                    #reactor_network.max_time_step = 1e-5

                    time = 0.0
                    tout.append(time)
                    Tout[model].append(r.thermo.T)
                    pout[model].append(r.thermo.P)

                    for _ in range(nstep):
                        time += tend/nstep
                        reactor_network.advance(time)

                        tout.append(time)
                        Tout[model].append(r.thermo.T)
                        pout[model].append(r.thermo.P)

    tout = np.array(tout)

    return tout, pout, Tout
