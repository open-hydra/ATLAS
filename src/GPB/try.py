import cantera as ct
import os, sys
import numpy as np
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

# Load the gas-phase mechanism from the YAML file
gas = ct.Solution('JLR-nasuti.yaml')  # Replace with your YAML file

temp = [100,1000,2000,3000]

for T_ref in temp:
    gas.TP = T_ref, ct.one_atm  # Set temperature and pressure

    # Get the reaction index for "H2 + 0.5 O2 <=> H2O"
    reaction_index = gas.reaction_equations().index('H2 + 0.5 O2 <=> H2O')

    # Forward Arrhenius parameters (known)
    A_f = 6.80e+15  # Forward pre-exponential factor in m^3/mol/s
    b_f = -1.0      # Forward temperature exponent
    E_a_f = 20128.78*ct.gas_constant  # Forward activation energy in J/mol

    # Calculate the forward rate constant at reference temperature
    kf = gas.forward_rate_constants[reaction_index]

    # Calculate the equilibrium constant at reference temperature
    Keq = gas.equilibrium_constants[reaction_index]

    # Calculate the reverse rate constant at reference temperature
    kb = kf / Keq

    # Calculate delta_H (enthalpy change of the reaction) at reference temperature
    delta_H = gas.delta_enthalpy[reaction_index]  # in J/mol

    # Calculate the reverse activation energy using E_a_b = E_a_f - delta_H
    print(delta_H,E_a_f)
    E_a_b = E_a_f - delta_H

    # Calculate the reverse pre-exponential factor A_b (constant with temperature)
    R = ct.gas_constant  # Gas constant in J/(mol*K)
    A_b = A_f / Keq * np.exp((E_a_f - E_a_b) / (R * T_ref))
    A_bb = kb/(pow(T_ref,-b_f)*np.exp(-E_a_b/(R*T_ref)))
    Aff = kf/(pow(T_ref,b_f)*np.exp(-E_a_f/(R*T_ref)))

    # Output the backward Arrhenius parameters
    print(f"Backward pre-exponential factor (A_bb): {A_bb:.3e} m^3/mol/s")
    print(f"Backward pre-exponential factor (A_b): {A_b:.3e} m^3/mol/s")
    print(f"Backward activation energy (E_a_b): {E_a_b / 1000:.2f} kJ/mol")  # Convert to kJ/mol
