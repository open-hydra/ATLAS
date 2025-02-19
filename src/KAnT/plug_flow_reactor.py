import cantera as ct
import numpy as np
import matplotlib.pyplot as plt
import os, sys
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

T = {}; y = {}; meth = {}

models = ['TSR-GP-24.yaml','TSR-CDF-13.yaml','coria.yaml','ZK.yaml','JLR-nasuti-ct.yaml','JLR-frassoldati-ct.yaml']

for model in models:

    # Define initial gas states for fuel (methane) and oxidizer
    fuel_gas = ct.Solution(model)
    fuel_gas.TPX = 545, 140*ct.one_atm, 'CH4:1.0'

    oxidizer_gas = ct.Solution(model)
    oxidizer_gas.TPX = 3500, 140*ct.one_atm, 'O2:0.013665853353367602, H2O:0.424505918181108666, CO:0.267129606823931831, CO2:0.241378707163126927, H2:0.00984026955481566781, H:0.000925043960154194825, O:0.00377335330710388281, OH:0.0387812285889810038'

    mdot = 0.2*100000000000 # kg/(m2 s)

    # Reactor parameters
    radius = 1.0
    area = np.pi*radius*radius
    #oxidizer_fraction_per_segment = mdot/segments  # Fraction of oxidizer added per segment
    velocity = 10.0  # m/s (flow velocity)
    length = 5.0  # Total length of reactor in meters
    time = length/velocity

    nx = 1600  # Number of cells along the length
    dx = length / nx

    # Initialize lists for results
    distance = []
    temperature_profile = []
    o2_profile = []
    ch4_profile = []
    species_name = 'H2O'
    species_profile = []

    # Start the plug flow reactor simulation segment by segment
    z = 0.0  # Initial position along reactor length
    t = mo = 0.0
    new_density = fuel_gas.density
    while t<time:

        portata = new_density*velocity*area
        # Calculate residence time per segment
        residence_time = dx / velocity
        
        # Initialize a reactor object for time integration
        reactor = ct.IdealGasConstPressureReactor(fuel_gas)
        reactor_net = ct.ReactorNet([reactor])

        # Advance the reactor for the segment's residence time
        reactor_net.advance(residence_time)

        new_mass = reactor.density*dx*area + mdot*dx*2*np.pi*radius*residence_time
        new_density = new_mass/dx/area
        lateral_fraction = mdot*dx*2*np.pi*radius*residence_time/new_density
        new_Y = ((1 - lateral_fraction) * fuel_gas.Y + lateral_fraction * oxidizer_gas.Y)

        # Gradually mix oxidizer into the fuel_gas composition
        #new_Y = ((1 - oxidizer_fraction_per_segment) * fuel_gas.Y 
        #         + oxidizer_fraction_per_segment * oxidizer_gas.Y)
        fuel_gas.TPY = reactor.T, reactor.thermo.P, new_Y  # Set updated T and P
        #velocity = portata/new_density/area

        # Store results for each segment
        distance.append(z)
        temperature_profile.append(fuel_gas.T)
        o2_profile.append(fuel_gas['O2'].X[0])
        ch4_profile.append(fuel_gas['CH4'].X[0])
        species_profile.append(fuel_gas[species_name].X[0])

        # Print progress
        print(f"Distance {z:.2f} m, Time {t:.2f}: vel = {velocity:.6f}")
        
        # Move to the next segment
        z += dx
        t += residence_time
        mo += mdot*dx*2*np.pi*radius*residence_time

    T[model] = temperature_profile
    y[model] = species_profile
    meth[model] = ch4_profile

# Plot results
plt.figure()
for model in models:
    plt.plot(distance, T[model], label=model)
plt.xlabel('Distance (m)')
plt.ylabel('Temperature (K)')
plt.title('Temperature Profile with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.figure()
for model in models:
    plt.plot(distance, meth[model], label=model)
plt.xlabel('Distance (m)')
plt.ylabel('Mole Fraction')
plt.title('O2 and CH4 Profiles with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.figure()
for model in models:
    plt.plot(distance, y[model], label=model)
plt.xlabel('Distance (m)')
plt.ylabel(f'Mole Fraction of {species_name}')
plt.title(f'{species_name} Profile with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.show()
