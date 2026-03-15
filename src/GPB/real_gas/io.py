import os
from config import OUTPATH, ensure_output_dir

ensure_output_dir()
outpath = OUTPATH


def write_phase(name, fluid):
    """Write the real-gas phase descriptor file."""
    filename = outpath + name + "phase.txt"
    with open(filename, 'w') as f:
        f.write("real-gas phase\n")
        f.write(f"{fluid}\n")


def write_thermo(name, pmin, pmax, dp, hmin, hmax, dh, NP, NH, rows):
    """Write the real-gas thermo lookup table."""
    filename = outpath + name + "thermo.dat"
    with open(filename, 'w') as f:
        f.write("TITLE = \"Mass Thermodynamic Properties\"\n")
        f.write('VARIABLES = "Pressure", "Enthalpy", "Density", '
                '"Temperature", "dRho/dT", "dRho/dh", '
                '"Cp", "Entropy", "dRho/dp", "SoundSpeed"\n')
        f.write(f"ZONE T=real-gas, I={NP}, J={NH}, VARLOCATION=([1-10]=NODAL)\n")
        for row in rows:
            f.write(" ".join(f"{v}" for v in row) + "\n")


def write_transport(name, pmin, pmax, dp, hmin, hmax, dh, NP, NH, rows):
    """Write the real-gas transport lookup table."""
    filename = outpath + name + "transport.dat"
    with open(filename, 'w') as f:
        f.write("TITLE = \"Transport Properties\"\n")
        f.write('VARIABLES = "Pressure", "Enthalpy", '
                '"Viscosity", "Conductivity"\n')
        f.write(f"ZONE T=real-gas, I={NP}, J={NH}, VARLOCATION=([1-4]=NODAL)\n")
        for row in rows:
            f.write(" ".join(f"{v}" for v in row) + "\n")
