import cantera as ct
import numpy as np
import yaml


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
    filename = name + "-thermo-mw.txt"

    with open(filename, 'w') as f:
        for i, species_name in enumerate(species_names):
            f.write(f"{species_name} {molecular_weights[i]:.6f}\n")

    # Write the data to a file in Tecplot-readable format
    filename = name + "-thermo.dat"

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
    filename = name + "-transport.dat"

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


    
def write_chemistry_properties (name, T_low, T_max, phase):

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

    filename_ = name + '-chemistry-stoich.txt'
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

            if 'three-body' in reaction.reaction_type or 'falloff' in reaction.reaction_type:
                reactant_coeff = 1.0; product_coeff = 1.0; efficiency_coeff = 0.0
            else:
                reactant_coeff = 0.0; product_coeff = 0.0; efficiency_coeff = 0.0
            file.write(f'{i + 1} {"M"} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')
