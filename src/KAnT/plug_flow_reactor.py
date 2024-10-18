import cantera as ct
import numpy as np
import matplotlib.pyplot as plt

# Define the gas mixture using a Cantera mechanism
gas = ct.Solution('gri30.yaml')

# Set the initial state: temperature (K), pressure (Pa), and composition (mole fractions)
gas.TPX = 1200, ct.one_atm, 'CH4:1.0, O2:2.0, N2:7.52'

# Define reactor length
length = 10.0  # Reactor length in meters

# Initial cross-sectional area (m^2)
initial_area = 1.0

# Define a function for area variation along the length
def area(z):
    """ Function to define the cross-sectional area as a function of distance z (m) """
    return initial_area * (1 + 0.5 * np.sin(2 * np.pi * z / length))  # Example: a sinusoidal variation

# Initial mass flow rate (assumed constant)
mass_flow_rate = gas.density * 100.0 * initial_area  # 1.0 m/s initial velocity

# Spatial step size in meters
dz = 0.01

# Storage for results
distance = []
temperature_profile = []
species_name = 'CO'
species_profile = []

# Set up the reactor
pfr = ct.IdealGasReactor(gas)
network = ct.ReactorNet([pfr])

# Start simulation over the reactor length
z = 0.0
while z < length:
    # Calculate area and velocity at the current position
    current_area = area(z)
    velocity = mass_flow_rate / (gas.density * current_area)
    
    # Compute the equivalent time step based on the new velocity and dz
    time_step = dz / velocity
    
    # Advance the reactor network
    network.advance(network.time + time_step)
    
    # Store results
    distance.append(z)
    temperature_profile.append(gas.T)
    species_profile.append(gas[species_name].X[0])
    
    # Move to the next spatial step
    z += dz

# Plot temperature profile
plt.figure()
plt.plot(distance, temperature_profile)
plt.xlabel('Distance (m)')
plt.ylabel('Temperature (K)')
plt.title('Temperature Profile in Plug Flow Reactor with Variable Area')
plt.grid(True)

# Plot species profile (e.g., CO)
plt.figure()
plt.plot(distance, species_profile)
plt.xlabel('Distance (m)')
plt.ylabel(f'Mole Fraction of {species_name}')
plt.title(f'{species_name} Profile in Plug Flow Reactor with Variable Area')
plt.grid(True)

plt.show()
