import cantera as ct
import numpy as np

def write_thermo_properties(T_low, T_max, species_names, molecular_weights, mass_cp_values, enthalpy_values, entropy_values, mass_dcp_values):

    # Write the data to a file in Tecplot-readable format
    filename = "species.data"

    with open(filename, 'w') as f:
        f.write(f"{len(species_names)}\n")
        for species_name in species_names:
            f.write(f"{species_name}\n")

    # Write the data to a file in Tecplot-readable format
    filename = "wm.dat"

    with open(filename, 'w') as f:
        for i, species_name in enumerate(species_names):
            f.write(f"{molecular_weights[i]:.6f}\n")

    # Write the data to a file in Tecplot-readable format
    filename = "tabellams.dat"

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    with open(filename, 'w') as f:
        f.write(f"{len(species_names)} {20000}\n")
        
        j = 0
        for species_name in species_names:
            j += 1
            for i, T in enumerate(temperatures):
                dcp_mass = mass_dcp_values[species_name][i]
                cp_mass = mass_cp_values[species_name][i]
                h_mass = enthalpy_values[species_name][i]
                s_mass = entropy_values[species_name][i]
                f.write(f"{int(T)} {j} {h_mass:.12f} {s_mass:.12f} {cp_mass:.12f} {dcp_mass:.12f}\n")



def write_transport_properties(T_low, T_max, species_names, viscosity, conductivity):

    # Write the data to a file in Tecplot-readable format
    filename = "tab_trans.dat"

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    with open(filename, 'w') as f:
        for species_name in species_names:
            for i, T in enumerate(temperatures):
                f.write(f"{viscosity[species_name][i]:.12f} {conductivity[species_name][i]:.12f} \n")



def write_chemistry_properties (T_low, T_max, phase, further_sp):

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    # Write the data to a file in Tecplot-readable format
    filename = "rate.dat"
    with open(filename, 'w') as f:
        # Print out the reaction rates for each reaction in the specified format
        f.write(f"{phase.n_reactions} {20000}\n")
        for i in range(phase.n_reactions):
            for T in temperatures:
                phase.TP = T, ct.one_atm
                forward_rate = phase.forward_rate_constants[i]
                reverse_rate = phase.reverse_rate_constants[i]
                f.write(f'{int(T)}   {i+1}   {forward_rate:.20E}   {reverse_rate:.20E}\n')

    filename_ = 'stoich.dat'
    with open(filename_, mode='w') as file:
    
        # Write the header
        file.write(f"{phase.n_reactions} {phase.n_species}\n")
    
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
                
                file.write(f'{phase.species_index(species_name)+1} {i+1} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            for j, sp in enumerate(further_sp):
                reactant_coeff = 0.0
                product_coeff = 0.0
                efficiency_coeff = 0.0
                file.write(f'{phase.n_species+j+1} {i + 1} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            if 'three-body' in reaction.reaction_type or 'falloff' in reaction.reaction_type:
                reactant_coeff = 1.0; product_coeff = 1.0; efficiency_coeff = 0.0
            else:
                reactant_coeff = 0.0; product_coeff = 0.0; efficiency_coeff = 0.0
            file.write(f'{phase.n_species+len(further_sp)+1} {i+1} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')
