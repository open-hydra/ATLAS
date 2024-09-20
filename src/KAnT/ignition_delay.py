import numpy as np
import cantera as ct
import sys, os
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

styles = {
    'gri30.yaml': {'label': 'GRI3.0','linestyle': '-', 'marker': 'o', 'color': 'b', 'markersize': 6},
    'aramco20.yaml': {'label': 'AramcoMech 2.0','linestyle': '-.', 'marker': '<', 'color': 'g', 'markersize': 6},
    'aramco30.yaml': {'label': 'AramcoMech 3.0','linestyle': '-.', 'marker': 'd', 'color': 'g', 'markersize': 6},
    'USCII.yaml': {'label': 'USC-Mech II','linestyle': '--', 'marker': 'o', 'color': 'r', 'markersize': 6},
    'TSR-13.yaml': {'label': 'TSR-13','linestyle': '--', 'marker': 'd', 'color': 'r', 'markersize': 6},
    'TSR-11.yaml': {'label': 'TSR-11','linestyle': '--', 'marker': 's', 'color': 'r', 'markersize': 6},
    'hashemi.yaml': {'label': 'Hashemi','linestyle': ':', 'marker': '^', 'color': 'm', 'markersize': 6},
    'WD.yaml': {'label': 'WD','linestyle': '-', 'marker': '<', 'color': 'k', 'markersize': 6}
}

#################################################################################

def ignition_delay(states, species):
    """
    This function computes the ignition delay from the occurence of the
    peak in species' concentration.
    """
    i_ign = states(species).Y.argmax()
    return states.t[i_ign]

# Input
temperatures = np.linspace(1050, 1350, 11)
mechanisms = ['WD.yaml','gri30.yaml','hashemi.yaml','TSR-13.yaml','aramco30.yaml']
pressure = 100.0

# Loop over mechanisms
for m in range(len(mechanisms)):

    gas = ct.Solution(mechanisms[m])

    ignition_times = []
    ignition_temperatures = []

    # Loop over temperatures
    for temperature in temperatures:

        # Gas state
        gas.TPX = temperature, pressure*ct.one_atm, "CH4:0.04,O2:0.08,Ar:0.88"

        r = ct.IdealGasReactor(contents=gas, name="Batch Reactor")
        reactor_network = ct.ReactorNet([r])

        # use the above list to create a DataFrame
        time_history = ct.SolutionArray(gas, extra="t")

        reference_species = "co"

        # This is a starting estimate. If you do not get an ignition within this time, increase it
        estimated_ignition_delay_time = 0.1
        t = 0

        counter = 1
        while t < estimated_ignition_delay_time:
            t = reactor_network.step()
            if not counter % 10:
                # We will save only every 10th value. Otherwise, this takes too long
                # Note that the species concentrations are mass fractions
                time_history.append(r.thermo.state, t=t)
            counter += 1

            # if len(temperatures)==1 and len(mechanisms)==1:
            #     if '--plot' in sys.argv[1:]:
            #         import matplotlib.pyplot as plt
            #         plt.clf()
            #         plt.subplot(2, 2, 1)
            #         plt.plot(times, data[:,0])
            #         plt.xlabel('Time (ms)')
            #         plt.ylabel('Temperature, K')
            #         plt.subplot(2, 2, 2)
            #         plt.plot(times, data[:,1])
            #         plt.xlabel('Time (ms)')
            #         plt.ylabel('T derivative, K/s')
            #         plt.subplot(2, 2, 3)
            #         plt.plot(times, data[:,2])
            #         plt.xlabel('Time (ms)')
            #         plt.ylabel('CO2 Mass Fraction')
            #         plt.subplot(2, 2, 4)
            #         plt.plot(times,data[:,3])
            #         plt.xlabel('Time (ms)')
            #         plt.ylabel('CH4 Mass Fraction')
            #         plt.tight_layout()
            #         plt.show()
            # else:
            #     print("To view a plot of these results, run this script with the option --plot")

        # We will use the 'oh' species to compute the ignition delay
        tau = ignition_delay(time_history, reference_species)

        print(f"Computed Ignition Delay: {tau:.3e} seconds")

        try:
            ignition_times.append(tau)
            ignition_temperatures.append(temperature)
        except:
            continue

    if '--plot' in sys.argv[1:]:
        import matplotlib.pyplot as plt
        cas = mechanisms[m]
        reciprocal_temperatures = [1000 / temp for temp in ignition_temperatures]
        micro_times = [1e+6 * time for time in ignition_times]
        plt.plot(reciprocal_temperatures, micro_times,
             label=styles[cas]['label'],
             linestyle=styles[cas]['linestyle'], 
             marker=styles[cas]['marker'], 
             color=styles[cas]['color'], 
             markersize=styles[cas]['markersize'])

# Plot the results
if '--plot' in sys.argv[1:]:
    plt.ylabel('Ignition Delay Time, ms')
    plt.xlabel('1000/Temperature, K-1')
    plt.legend(loc='best')
    plt.yscale('log')
    plt.show()
else:
    print("To view a plot of these results, run this script with the option --plot")
