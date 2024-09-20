import cantera as ct
import numpy as np
import sys, os
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

##############################################################################
# Function to compute equilibrium at a given equivalence ratio

def compute_equilibrium(mech, pressure, T, OF, OFs):

    # Define the gas object for the fuel and oxidizer mixture
    gas = ct.Solution(mech)

    # Define the base fuel and oxidizer
    fuel = 'CH4:1'
    oxidizer = 'O2:1'  # Air composition
    
    # Set the initial state of the gas
    gas.TP = T, pressure
    
    # Set the composition of the mixture
    gas.set_equivalence_ratio(OF/OFs, fuel, oxidizer)
    
    # Compute the equilibrium state of the mixture
    gas.equilibrate('HP', solver='gibbs', max_steps=1000)

    return gas

##############################################################################
# Program

mech = ['gri30.yaml','TSR-13.yaml','TSR-11.yaml','JLR-frassoldati.yaml','JL.yaml','WD.yaml']

Temperature = 300
pressure = 120 * 101325.0


styles = {
    'gri30.yaml': {'label': 'GRI3.0','linestyle': '-', 'marker': 'o', 'color': 'b', 'markersize': 6},
    'TSR-13.yaml': {'label': 'TSR-13','linestyle': '--', 'marker': 'd', 'color': 'r', 'markersize': 6},
    'TSR-11.yaml': {'label': 'TSR-11','linestyle': '--', 'marker': 's', 'color': 'r', 'markersize': 6},
    'JLR-frassoldati.yaml': {'label': 'Frassoldati','linestyle': '-.', 'marker': 'd', 'color': 'g', 'markersize': 6},
    'JL.yaml': {'label': 'JL','linestyle': ':', 'marker': '^', 'color': 'm', 'markersize': 6},
    'WD.yaml': {'label': 'WD','linestyle': '-', 'marker': '<', 'color': 'k', 'markersize': 6}
}

out_species = ['O2', 'CH4', 'H2O', 'CO', 'CO2']

# Equivalence ratio range
npoints = 100
OF = np.linspace(0.1, 15, npoints)

# Create arrays to hold the data
tad = np.zeros((len(mech), npoints))
yeq = np.zeros((len(mech), len(out_species), npoints))

for m in range(len(mech)):
    for i in range(npoints):
        gas = compute_equilibrium(mech=mech[m], pressure=pressure, OF=OF[i], T=Temperature, OFs=4)
        tad[m,i] = gas.T
        print('At phi = {0:12.4g}, Tad = {1:12.4g}'.format(OF[i], tad[m,i]))
        yeq[m, :, i] = gas[out_species].Y

##############################################################################
# OUTPUT

# Write output CSV file for importing into Excel
# csv_file = 'adiabatic.csv'
# with open(csv_file, 'w', newline='') as outfile:
#     writer = csv.writer(outfile)
#     writer.writerow(['phi', 'T (K)'] + out_species)
#     for i in range(npoints):
#         writer.writerow([OF[i], tad[i]] + list(xeq[:, i]))
# print('Output written to {0}'.format(csv_file))

if '--plot' in sys.argv:
    import matplotlib.pyplot as plt

    # # The mass fractions of selected species
    # for i, cas in enumerate(out_species):
    #     if cas in ['O2', 'CO2', 'H2O']:
    #         plt.plot(OF, yeq[i, :], label=cas)

    # plt.xlabel('Equivalence ratio')
    # plt.ylabel('Mass fractions')
    # plt.legend(loc='best')
    # plt.show()
    #plt.savefig('plot.png', bbox_inches='tight')

    # The adiabatic flame temperature
    for m in range(len(mech)):
        cas = mech[m]
        plt.plot(OF/4, tad[m,:],
             label=styles[cas]['label'],
             linestyle=styles[cas]['linestyle'], 
             marker=styles[cas]['marker'], 
             color=styles[cas]['color'], 
             markersize=styles[cas]['markersize'])
    plt.xlabel('Equivalence ratio')
    plt.ylabel('Adiabatic flame temperature [K]')
    plt.legend(loc='best')
    plt.show()
    #plt.savefig('plot.png', bbox_inches='tight')
