import cantera as ct
import numpy as np
import yaml
import os
import math
outpath = 'fromATLAStoSolver/'
try:
    os.mkdir(outpath)
except FileExistsError:
    print(f"Directory '{outpath}' already exists.")


def read_yaml_file(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
        return data


def write_thermo_properties(name, T_low, T_max, species_names, molecular_weights, mass_cp_values, enthalpy_values, entropy_values, mass_dcp_values):

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "phase.txt"

    with open(filename, 'w') as f:
        f.write("ideal-gas phase\n")
        for i, species_name in enumerate(species_names):
            f.write(f"{species_name} {molecular_weights[i]:.6f}\n")

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "thermo.dat"

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
    filename = outpath + name + "transport.dat"

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


def write_chemistry_info (name, phase, further_sp):

    filename_ = outpath + name + 'chemistry-info.txt'
    with open(filename_, mode='w') as file:
    
        # Write the header
        file.write(f'{phase.name}\n')
        file.write(f'N.ro species = {phase.n_species}\n')
        file.write(f'N.ro reactions = {phase.n_reactions}\n')
        file.write(f'\n')
        file.write(f'General loop info. They are not used if the mechanism is exlplicitly defined\n')

        file.write(f'\n')
        file.write(f'Reaction type\n')

        # Iterate over each reaction
        for i in range(phase.n_reactions):
            reaction = phase.reaction(i)
            file.write(f'{i+1} {reaction.reaction_type}\n')

        file.write(f'\n')
        file.write(f'Reaction definition\n')
    
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
                        specified_efficiencies = reaction.third_body.efficiencies
                        if species_name in specified_efficiencies:
                            efficiency_coeff = specified_efficiencies[species_name]
                        else:
                            efficiency_coeff = reaction.third_body.efficiency(species_name)
                
                file.write(f'{i + 1} {species_name} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            for j, sp in enumerate(further_sp):
                reactant_coeff = 0.0
                product_coeff = 0.0
                efficiency_coeff = 0.0
                file.write(f'{i + 1} {sp} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')

            if 'three-body' in reaction.reaction_type or 'falloff' in reaction.reaction_type:
                reactant_coeff = 1.0; product_coeff = 1.0
            else:
                reactant_coeff = 0.0; product_coeff = 0.0

            efficiency_coeff = 0.0
            file.write(f'{i + 1} {"M"} {reactant_coeff} {product_coeff} {efficiency_coeff}\n')


def write_chemistry_Arrhenius(name, temperatures, kf, kb):
    """
    Write Arrhenius reaction rate data to a Tecplot-readable file.
    Each Arrhenius reaction is written in its own ZONE.
    """
    os.makedirs(outpath, exist_ok=True)  # ensure output directory exists
    filename = os.path.join(outpath, f"{name}chemistry-Arrhenius.dat")

    with open(filename, 'w') as f:
        f.write("TITLE = \"Arrhenius data\"\n")
        f.write("VARIABLES = \"Temperature\", \"kf\", \"kb\"\n")

        n_reactions, n_temps = kf.shape

        for i in range(n_reactions):
            f.write(f"ZONE T=\"Reaction {i+1}\"\n")
            f.write(f"I={n_temps}, F=POINT\n")
            for t, T in enumerate(temperatures):
                kf_val = kf[i, t]
                kb_val = kb[i, t]
                # Replace infinities with very large numbers
                if math.isinf(kf_val): kf_val = 1e300
                if math.isinf(kb_val): kb_val = 1e300
                f.write(f"{T:12.3f} {kf_val:20.12E} {kb_val:20.12E}\n")


def write_chemistry_Troe(name, temperatures, k_0_t, k_inf_t, kc_t, Fcent):
    """
    Write fall-off Troe reaction rate data to a Tecplot-readable file.
    Each Troe falloff reaction is written in its own ZONE.
    """
    os.makedirs(outpath, exist_ok=True)  # make sure output directory exists
    filename = os.path.join(outpath, f"{name}chemistry-Troe.dat")

    with open(filename, 'w') as f:
        f.write("TITLE = \"Fall-off Troe data\"\n")
        f.write("VARIABLES = \"Temperature\", \"k_inf\", \"k_0\", \"k_c\", \"F_cent\"\n")

        n_reactions, n_temps = k_0_t.shape

        for i in range(n_reactions):
            f.write(f"ZONE T=\"Reaction {i+1}\"\n")
            f.write(f"I={n_temps}, F=POINT\n")
            for t, T in enumerate(temperatures):
                k_inf = k_inf_t[i, t]
                k_0   = k_0_t[i, t]
                kc    = kc_t[i, t]
                fcent = Fcent[i, t]
                # Replace infinities with a very large number for Tecplot
                if math.isinf(k_inf): k_inf = 1e300
                if math.isinf(k_0):   k_0   = 1e300
                if math.isinf(kc):    kc    = 1e300
                if math.isinf(fcent): fcent = 1e300
                f.write(f"{T:12.3f} {k_inf:20.12E} {k_0:20.12E} {kc:20.12E} {fcent:20.12E}\n")


def write_chemistry_Lindemann(name, temperatures, k_0_l, k_inf_l, kc_l):
    """
    Write fall-off Lindemann data to a file in Tecplot-readable format.
    Each reaction gets its own ZONE.
    """
    os.makedirs(outpath, exist_ok=True)
    filename = os.path.join(outpath, f"{name}chemistry-Lindemann.dat")

    with open(filename, 'w') as f:
        f.write("TITLE = \"Fall-off Lindemann data\"\n")
        f.write("VARIABLES = \"Temperature\", \"k_inf\", \"k_0\", \"k_c\"\n")

        n_reactions = k_0_l.shape[0]
        n_temps = len(temperatures)

        for i in range(n_reactions):
            f.write(f"ZONE T=\"Reaction {i+1}\"\n")
            f.write(f"I={n_temps}, F=POINT\n")
            for t, T in enumerate(temperatures):
                k_0 = k_0_l[i, t]
                k_inf = k_inf_l[i, t]
                kc = kc_l[i, t]
                # Replace infinities with large number
                if math.isinf(k_inf): k_inf = 1e300
                if math.isinf(k_0): k_0 = 1e300
                if math.isinf(kc): kc = 1e300
                f.write(f"{T:12.3f} {k_inf:20.12E} {k_0:20.12E} {kc:20.12E}\n")

