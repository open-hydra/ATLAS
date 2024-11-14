import cantera as ct
import numpy as np
import yaml
import os
outpath = 'fromATLAStoSolver/'
try:
    os.mkdir(outpath)
except FileExistsError:
    print(f"Directory '{outpath}' already exists.")

# def fittatutto (reaction, temperatures,kb_values):
#     from scipy.optimize import curve_fit

#     A = reaction.rate.pre_exponential_factor
#     b = reaction.rate.temperature_exponent
#     Ea = reaction.rate.activation_energy  # This is in J/mol (SI units)

#     # Print the parameters
#     print(f"Pre-exponential factor (A): {A:.3e} m^3/mol/s")
#     print(f"Temperature exponent (b): {b}")
#     print(f"Activation energy (Ea): {Ea / 1000:.2f} kJ/mol")  # Convert J/mol to kJ/mol

#     # Gas constant in J/(mol*K)
#     R = ct.gas_constant

#     # Use logarithmic form to improve fitting stability
#     log_kb_values = np.log(kb_values)

#     # Define the Arrhenius equation in logarithmic form
#     def log_arrhenius(T, log_A_b, n_b, E_a_b):
#         return log_A_b + n_b * np.log(T) - E_a_b / (R * T)

#     # Initial guess for the Arrhenius parameters (log_A_b, n_b, E_a_b)
#     initial_guess = [np.log(1e12), -1.0, 50000]  # Rough initial guesses

#     # Increase the maximum function evaluations to help convergence
#     maxfev = 7000

#     # Add tolerances (ftol, xtol, gtol) for better control of the fit
#     tolerances = {
#         'ftol': 1e-15,  # Adjust this for the absolute error tolerance in the residual sum of squares
#         'xtol': 1e-15,  # Adjust this for the relative error tolerance in the solution
#         'gtol': 1e-15,  # Adjust this for the orthogonality tolerance
#     }

#     # Fit the curve to the data using the logarithmic form of the Arrhenius equation with adjusted tolerances
#     params, covariance = curve_fit(
#         log_arrhenius, temperatures, log_kb_values, 
#         p0=initial_guess, maxfev=maxfev, method='trf',
#         ftol=tolerances['ftol'], xtol=tolerances['xtol'], gtol=tolerances['gtol']
#     )

#     # Extract fitted parameters and convert log_A_b back to A_b
#     log_A_b_fitted, n_b_fitted, E_a_b_fitted = params
#     A_b_fitted = np.exp(log_A_b_fitted)  # Convert back to A_b from log(A_b)

#     # Print the fitted Arrhenius parameters
#     print(f"Fitted backward pre-exponential factor (A_b): {A_b_fitted:.3e} m^3/mol/s")
#     print(f"Fitted backward temperature exponent (n_b): {n_b_fitted:.3f}")
#     print(f"Fitted backward activation energy (E_a_b): {E_a_b_fitted / 1000:.3f} kJ/mol")
#     # Convert A_b from m^3/mol/s to cm^3/mol/s
#     A_b_fitted_cm = A_b_fitted * 1e6
#     # Convert E_a_b from kJ/mol to cal/mol
#     E_a_b_fitted_cal = (E_a_b_fitted / 1000) * 239.005736
#     # Print the converted values
#     print(f"Fitted backward pre-exponential factor (A_b): {A_b_fitted_cm:.3e} cm^3/mol/s")
#     print(f"Fitted backward temperature exponent (n_b): {n_b_fitted:.3f}")
#     print(f"Fitted backward activation energy (E_a_b): {E_a_b_fitted_cal:.3f} cal/mol")
#     # Convert activation energy to Kelvin (divide by R)
#     activation_energy_K = E_a_b_fitted / R
#     print(f"Fitted backward activation energy (E_a_b) in Kelvin: {activation_energy_K:.3f} K")
#     # Predicted backward rate constants using the fitted parameters
#     kb_fitted_values = np.exp(log_arrhenius(temperatures, log_A_b_fitted, n_b_fitted, E_a_b_fitted))
#     import matplotlib.pyplot as plt
#     # Plot the original vs fitted backward rate constants
#     #plt.plot(temperatures, kb_values, 'o', label='Original kb values')
#     #plt.plot(temperatures, kb_fitted_values, '-', label='Fitted kb values')
#     plt.plot(temperatures, (kb_fitted_values-kb_values)/kb_values*100, '-', label='Fitted kb values')
#     plt.xlabel('Temperature (K)')
#     plt.ylabel('kb (m^3/mol/s)')
#     plt.legend()
#     plt.title('Original vs Fitted Backward Rate Constants')
#     plt.show()



def read_yaml_file(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)

        # for element in data:
        #     print(f"Element: {element['element']}")
        #     print(f"Source: {element['source']}")
        #     print("Viscosity:")
        #     for v in element['viscosity']:
        #         print(f"  Temperature Range: {v['temperature_range']}")
        #         print(f"  Coefficients: {v['coefficients']}")
        #     print("Conductivity:")
        #     for c in element['conductivity']:
        #         print(f"  Temperature Range: {c['temperature_range']}")
        #         print(f"  Coefficients: {c['coefficients']}")
        #     print()

        return data



def write_thermo_properties(name, T_low, T_max, species_names, molecular_weights, mass_cp_values, enthalpy_values, entropy_values, mass_dcp_values):

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "-thermo-mw.txt"

    with open(filename, 'w') as f:
        for i, species_name in enumerate(species_names):
            f.write(f"{species_name} {molecular_weights[i]:.6f}\n")

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "-thermo.dat"

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    with open(filename, 'w') as f:
        f.write("TITLE = \"Mass Thermodynamic Properties\"\n")
        f.write("VARIABLES = \"Temperature\", \"Cp\", \"Enthalpy\", \"Entropy\", \"dCp\"\n")
        
        for species_name in species_names:
            f.write(f"ZONE T=\"{species_name}\"\n")
            f.write(f"I={len(temperatures)}, F=POINT\n")
            for i, T in enumerate(temperatures):
                dcp_mass = mass_dcp_values[species_name][i]
                cp_mass = mass_cp_values[species_name][i]
                h_mass = enthalpy_values[species_name][i]
                s_mass = entropy_values[species_name][i]
                f.write(f"{T} {cp_mass:.6f} {h_mass:.6f} {s_mass:.6f} {dcp_mass:.6f}\n")



def write_transport_properties(name, T_low, T_max, species_names, viscosity, conductivity):

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "-transport.dat"

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    with open(filename, 'w') as f:
        f.write("TITLE = \"Transport Properties\"\n")
        f.write("VARIABLES = \"Temperature\", \"Viscosity\", \"Conductivity\"\n")
        
        for species_name in species_names:
            f.write(f"ZONE T=\"{species_name}\"\n")
            f.write(f"I={len(temperatures)}, F=POINT\n")
            for i, T in enumerate(temperatures):
                f.write(f"{T} {viscosity[species_name][i]:.12f} {conductivity[species_name][i]:.12f} \n")



def write_chemistry_properties (name, T_low, T_max, phase, further_sp):

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    # Write the data to a file in Tecplot-readable format
    filename = name + "-chemistry-rate.dat"
    with open(filename, 'w') as f:
        f.write("TITLE = \"Chemistry Properties\"\n")
        f.write("VARIABLES = \"Temperature\", \"Kf\", \"Kb\"\n")

        # Print out the reaction rates for each reaction in the specified format
        for i in range(phase.n_reactions):
            f.write(f"ZONE T=Reaction{i+1}\n")
            f.write(f"I={len(temperatures)}, F=POINT\n")
            for T in temperatures:
                phase.TP = T, ct.one_atm
                forward_rate = phase.forward_rate_constants[i]
                reverse_rate = phase.reverse_rate_constants[i]
                f.write(f'{T:<12}  {forward_rate:.20E}    {reverse_rate:.20E}\n')


    filename_ = outpath + name + '-chemistry-stoich.txt'
    with open(filename_, mode='w') as file:
    
        # Write the header
        file.write(f"Reaction, Species, Reagent Coefficient, Product Coefficient, Efficiency\n")
    
        # Iterate over each reaction
        for i in range(phase.n_reactions):
            reaction = phase.reaction(i)
            reactants = reaction.reactants
            products = reaction.products

            # Iterate over all species to get their coefficients and efficiencies
            for n in range(phase.n_species):
                species_name = phase.species(n).name
                reactant_coeff = 0.0
                product_coeff = 0.0
                efficiency_coeff = 0.0
                for species_, coeff in reactants.items():
                    if species_name == species_:
                        reactant_coeff = coeff
                for species_, coeff in products.items():
                    if species_name == species_:
                        product_coeff = coeff
                    # Print third-body efficiencies if applicable
                    if 'three-body' in reaction.reaction_type or 'falloff' in reaction.reaction_type:
                        for species_, efficiency in reaction.third_body.efficiencies.items():
                            if species_name == species_:
                                efficiency_coeff = efficiency
                
                file.write(f'{i + 1} {species_name} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            for j, sp in enumerate(further_sp):
                reactant_coeff = 0.0
                product_coeff = 0.0
                efficiency_coeff = 0.0
                file.write(f'{i + 1} {sp} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            if 'three-body' in reaction.reaction_type or 'falloff' in reaction.reaction_type:
                reactant_coeff = 1.0; product_coeff = 1.0; efficiency_coeff = 0.0
            else:
                reactant_coeff = 0.0; product_coeff = 0.0; efficiency_coeff = 0.0
            file.write(f'{i + 1} {"M"} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')
