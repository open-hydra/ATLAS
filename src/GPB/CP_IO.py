import numpy as np
import os
outpath = 'fromATLAStoSolver/'
try:
    os.mkdir(outpath)
except FileExistsError:
    print(f"Directory '{outpath}' already exists.")


def write_basics(type, name, mat_phases, groups):

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "phase.txt"

    with open(filename, 'w') as f:
        if 'condensed' in type:
            f.write("condensed-dispersed phase\n")
        elif type == 'solid':
            f.write("solid phase\n")
        for i, m in enumerate(mat_phases):
            f.write(f"{m.name} {int(groups[i])}\n")



def write_properties(type, name, T_low, T_max, species_names, mass_cp, density, enthalpy, conductivity):

    # Write the data to a file in Tecplot-readable format
    filename = outpath + name + "properties.dat"

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    with open(filename, 'w') as f:
        f.write("TITLE = \"Mass Thermodynamic Properties\"\n")

        if 'dispersed' in type:
            f.write("VARIABLES = \"Temperature\", \"Cp\", \"Density\", \"Enthalpy\"\n")
            
            for species_name in species_names:
                f.write(f"ZONE T=\"{species_name}\"\n")
                f.write(f"I={len(temperatures)}, F=POINT\n")
                for i, T in enumerate(temperatures):
                    cp_mass = mass_cp[species_name][i]
                    h_mass = enthalpy[species_name][i]
                    rho = density[species_name][i]
                    f.write(f"{T} {cp_mass:.6f} {rho:.6f} {h_mass:.6f}\n")

        else:
            f.write("VARIABLES = \"Temperature\", \"Cp\", \"Density\", \"Conductivity\"\n")
            
            for species_name in species_names:
                f.write(f"ZONE T=\"{species_name}\"\n")
                f.write(f"I={len(temperatures)}, F=POINT\n")
                for i, T in enumerate(temperatures):
                    cp_mass = mass_cp[species_name][i]
                    rho = density[species_name][i]
                    k = conductivity[species_name][i]
                    f.write(f"{T} {cp_mass:.6f} {rho:.6f} {k:.6f}\n")
