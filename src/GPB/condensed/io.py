import numpy as np
import os
from config import OUTPATH, ensure_output_dir
from ini.condensed import phase_header_word

outpath = OUTPATH
ensure_output_dir()


def write_basics(type, name, mat_phases, groups, modeling=None, material_tokens=None):
    """<name>phase.txt: line 1 = type word [+ ' modeling=<v>'], then one
    '<name> <groups>[ key=value ...]' line per material. material_tokens is a
    per-material list of 'key=value' strings (nothing is written until P3 wires it)."""

    # Write the data to a free-format ASCII file
    filename = outpath + name + "phase.txt"

    with open(filename, 'w') as f:
        head = phase_header_word(type)
        if modeling:
            head += f" modeling={modeling}"
        f.write(head + "\n")
        for i, m in enumerate(mat_phases):
            line = f"{m.name} {int(groups[i])}"
            if material_tokens and material_tokens[i]:
                line += " " + " ".join(material_tokens[i])
            f.write(line + "\n")



def write_properties(type, name, T_low, T_max, species_names, mass_cp, density, enthalpy, conductivity, energy):

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
            f.write("VARIABLES = \"Temperature\", \"Cp\", \"Density\", \"Conductivity\", \"Energy\"\n")
            
            for species_name in species_names:
                f.write(f"ZONE T=\"{species_name}\"\n")
                f.write(f"I={len(temperatures)}, F=POINT\n")
                for i, T in enumerate(temperatures):
                    cp_mass = mass_cp[species_name][i]
                    rho = density[species_name][i]
                    k = conductivity[species_name][i]
                    e_mass = energy[species_name][i]
                    f.write(f"{T} {cp_mass:.6f} {rho:.6f} {k:.6f} {e_mass:.6f}\n")
