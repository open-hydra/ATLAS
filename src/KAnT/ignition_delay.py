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

def ignition_delay(states, initial_temp, delta_temp=300.0):
    """
    This function computes the ignition delay based on when the temperature
    increases by a specified amount (default is 300 K) from the initial temperature.

    Parameters:
        states (ct.SolutionArray): The array of states with time evolution.
        initial_temp (float): The initial temperature in Kelvin.
        delta_temp (float): The temperature increase to define ignition (default is 300 K).

    Returns:
        float: The ignition delay time.
    """
    target_temp = initial_temp + delta_temp

    # Find the first time the temperature exceeds the target temperature
    for i, temp in enumerate(states.T):
        if temp >= target_temp:
            return states.t[i]  # Return the corresponding time
    
    # If no ignition occurred within the time limits, return NaN
    return np.nan


def run_all(models, reactor_type, fuel_string, oxi_string, pressures, mixture_ratio, temperatures):

    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string[1])
    fuel_dict = {species: float(value) for species, value in fuel_composition}

    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string[1])
    oxi_dict = {species: float(value) for species, value in oxi_composition}

    ignition_times = {}
    ignition_temperatures = {}

    for model in models:
        print(' -- Processing: ',model)

        new_mechanism = add_species('N2',ct.Solution(model+'.yaml'),'nasa9')
        new_mechanism = add_species('Ar',new_mechanism,'nasa9')
        ignition_times[model] = []
        ignition_temperatures[model] = []

        # Loop over temperatures
        for temperature in temperatures:
            for pressure in pressures:
                pressure_chamber = convert2si(pressure, 'bar')
                for mr in mixture_ratio:

                    setup_mixture(new_mechanism, fuel_dict, oxi_dict, mr)
                    #new_mechanism.X = 'H2:10.4, CL2:10.4, Ar:79.2'
                    new_mechanism.TP = temperature, pressure_chamber
                    #print(new_mechanism.species_names)
                    #print(new_mechanism.Y)
                    #exit()

                    if reactor_type=='HP':
                      r = ct.IdealGasConstPressureReactor(contents=new_mechanism, name="Batch Reactor")
                    else:
                      r = ct.IdealGasReactor(contents=new_mechanism, name="Batch Reactor")
                    reactor_network = ct.ReactorNet([r])
                    # Set the ODE tollerances and max time step
                    rtol = 1.e-7
                    atol = 1.e-7
                    reactor_network.rtol, reactor_network.atol = rtol, atol
                    reactor_network.max_time_step = 1e-5

                    # use the above list to create a DataFrame
                    time_history = ct.SolutionArray(new_mechanism, extra="t")

                    # This is a starting estimate. If you do not get an ignition within this time, increase it
                    estimated_ignition_delay_time = 0.1
                    t = 0
                    initial_temp = new_mechanism.T

                    counter = 1
                    while t < estimated_ignition_delay_time:
                        t = reactor_network.step()
                        if not counter % 10:
                            time_history.append(r.thermo.state, t=t)
                        counter += 1

                    try:
                        tau = ignition_delay(time_history, initial_temp)
                        ignition_times[model].append(tau)
                        ignition_temperatures[model].append(temperature)
                    except:
                        ignition_times[model].append(np.nan)
                        ignition_temperatures[model].append(np.nan)
                        continue

    return ignition_times
