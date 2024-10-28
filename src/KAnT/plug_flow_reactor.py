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

model = 'coria.yaml'

# Define initial gas states for fuel (methane) and oxidizer
fuel_gas = ct.Solution(model)
fuel_gas.TPX = 1400, ct.one_atm, 'CH4:1.0'

oxidizer_gas = ct.Solution(model)
oxidizer_gas.TPX = 300, ct.one_atm, 'O2:1.0'

mdot = 0.2 # kg/(m2 s)

# Reactor parameters
length = 10  # Total length of reactor in meters
time = 10.0
radius = 1.0
area = np.pi*radius*radius
nx = 1600  # Number of cells along the length
dx = length / nx
#oxidizer_fraction_per_segment = mdot/segments  # Fraction of oxidizer added per segment
velocity = 1.0  # m/s (flow velocity)

# Initialize lists for results
distance = []
temperature_profile = []
o2_profile = []
ch4_profile = []
species_name = 'CO'
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
    velocity = portata/new_density/area

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
    print(mo)

# Plot results
plt.figure()
plt.plot(distance, temperature_profile, label='Temperature')
plt.xlabel('Distance (m)')
plt.ylabel('Temperature (K)')
plt.title('Temperature Profile with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.figure()
plt.plot(distance, o2_profile, label='O2 Mole Fraction', color='blue')
plt.plot(distance, ch4_profile, label='CH4 Mole Fraction', color='orange')
plt.xlabel('Distance (m)')
plt.ylabel('Mole Fraction')
plt.title('O2 and CH4 Profiles with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.figure()
plt.plot(distance, species_profile, label=f'{species_name} Mole Fraction', color='red')
plt.xlabel('Distance (m)')
plt.ylabel(f'Mole Fraction of {species_name}')
plt.title(f'{species_name} Profile with Gradual Oxidizer Injection')
plt.grid(True)
plt.legend()

plt.show()
