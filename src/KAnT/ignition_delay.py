from pint import UnitRegistry
import numpy as np
import cantera as ct
import sys, os, re
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

#################################################################################

# for convenience:
def to_si(quant):
    '''Converts a Pint Quantity to magnitude at base SI units.
    '''
    return quant.to_base_units().magnitude

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
    if 'Ar' not in original_mechanism.species_names:
        Ar_species = next((species for species in nasa_gas if species.name == 'Ar'), None)
        if Ar_species:
            new_species.append(Ar_species)

    # Create a new Solution with the combined species list and the original reactions
    new_mechanism = ct.Solution(thermo='ideal-gas', kinetics='gas', species=new_species, reactions=original_mechanism.reactions())
    new_mechanism.name = original_mechanism.name

    return new_mechanism


def setup_mixture(gas, fuel_comp, oxi_comp, mr):
    """
    Set the gas state according to the mixture ratio and component compositions.

    Parameters:
        gas (ct.Solution): Cantera gas object.
        fuel_comp (dict): Fuel composition as a dictionary, e.g., {'CH4': 1.0}.
        oxi_comp (dict): Oxidizer composition as a dictionary, e.g., {'O2': 0.21, 'N2': 0.79}.
        mr (float): Mixture ratio (fuel to oxidizer).
        
    Returns:
        None: Gas composition is set directly in the `gas` object.
    """

    # Normalize the fuel and oxidizer compositions (in case they don't sum to 1)
    total_fuel = sum(fuel_comp.values())
    total_oxi = sum(oxi_comp.values())
    
    if mr == 0:
        total_fuel = total_fuel + total_oxi
        total_oxi = total_fuel
    normalized_fuel_comp = {species: frac / total_fuel for species, frac in fuel_comp.items()}
    normalized_oxi_comp = {species: frac / total_oxi for species, frac in oxi_comp.items()}

    # Combined mixture composition
    combined_comp = {}
    
    for species, frac in normalized_fuel_comp.items():
        combined_comp[species] = frac/(1+mr)
    
    for species, frac in normalized_oxi_comp.items():
        if species in combined_comp:
            if mr==0:
                combined_comp[species] += frac
            else:
                combined_comp[species] += frac*mr/(1+mr)  # If species is in both, sum the fractions
        else:
            if mr==0:
                combined_comp[species] = frac
            else:
                combined_comp[species] = frac*mr/(1+mr) # Oxidizer-only species
    
    # Set the gas composition
    gas.Y = combined_comp


def run_all(models, fuel_string, oxi_string, pressures, mixture_ratio, temperatures):

    ureg = UnitRegistry()
    Q_ = ureg.Quantity

    fuel_composition = re.findall(r'{(.*?):(.*?)}', fuel_string)
    fuel_dict = {species: float(value) for species, value in fuel_composition}

    oxi_composition = re.findall(r'{(.*?):(.*?)}', oxi_string)
    oxi_dict = {species: float(value) for species, value in oxi_composition}

    ignition_times = {}
    ignition_temperatures = {}

    for model in models:

        new_mechanism = define_model(model)
        ignition_times[model] = []
        ignition_temperatures[model] = []

        # Loop over temperatures
        for temperature in temperatures:
            for pressure in pressures:
                pressure_chamber = Q_(pressure, 'bar')
                for mr in mixture_ratio:

                    setup_mixture(new_mechanism, fuel_dict, oxi_dict, mr)
                    #new_mechanism.X = 'CH4:0.120, O2:0.185, N2:0.695'
                    new_mechanism.TP = temperature, to_si(pressure_chamber)
                    #print(new_mechanism.Y)
                    #exit()

                    r = ct.IdealGasReactor(contents=new_mechanism, name="Batch Reactor")
                    reactor_network = ct.ReactorNet([r])
                    # Set the maximum step size
                    # rtol = 1.e-1
                    # atol = 1.e-1
                    # reactor_network.rtol, reactor_network.atol = rtol, atol
                    #reactor_network.max_time_step = 1e-5

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
