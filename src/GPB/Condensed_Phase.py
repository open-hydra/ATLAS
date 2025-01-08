import cantera as ct
import CP_properties
import CP_IO
from Read_INI import *
import os, sys

masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)

# Data path setup
datapath = masterpath + '/database/'
ct.add_directory(datapath + 'Thermo')
ct.add_directory(datapath + 'Transport')
ct.add_directory(datapath + 'Chemistry')
CEAtransdir = datapath + 'Transport/CEApolynomials.yaml'

class Material:
    def __init__(self, name, type):
        self.name = name
        self.type = type
        self.solution = None  # Store the Cantera solution object
        self.density = None
        self.specific_heat = None
        self.thermal_conductivity = None
    
    def load_from_cantera(self, cantera_solution):
        """
        Load the Cantera solution and set the initial temperature.
        """
        self.solution = cantera_solution

def build(type,inifile,section):

    # ---------------------------------------------------
    # Initialization of variables
    # ---------------------------------------------------
    material_group = []

    # ---------------------------------------------------
    # Reading input parameters from INI file
    # ---------------------------------------------------
    # Model definitions, materials, and options
    inputModels = CP_read_models(inifile,section)
    inputMat = CP_read_material(inifile,section)

    name, T1, T2, thermo_model = inputModels
    material_names, groups, fix_cp, fix_k, fix_rho = inputMat

    if name.endswith('-'):
        string = name[:-1]  # Remove the last character
    else:
        string = 'no name'
    if 'dispersed' in type:
        print(' - Condensed-dispersed phase:', string)
    elif type == 'solid':
        print(' - Solid phase:', string)
    print()

    # ---------------------------------------------------
    # Load the Thermo Model
    # ---------------------------------------------------
    if thermo_model is None: thermo_model = 'NASA9'
    if thermo_model == 'NASA7':
        all_mat = ct.Species.list_from_file('nasa_condensed.yaml')
    elif thermo_model == 'NASA9':
        all_mat = ct.Species.list_from_file('nasa9.yaml')
    elif thermo_model == 'Burcat':
        all_mat = ct.Species.list_from_file('burcat.yaml')

    # ---------------------------------------------------
    # Build the specific heat
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-varying material
    if fix_cp is None:
        print(' -- Found T-varying properties materials')
        materials = [s for s in all_mat if s.name in material_names]
        for m in materials:
            ct_solution = ct.Solution(thermo='fixed-stoichiometry',species=[m])
            material = Material(name=ct_solution.species_names[0], type='cantera')
            material.load_from_cantera(ct_solution)
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-constant material
    if fix_cp is not None:
        print(' -- Found fixed properties materials')
        for i in range(len(fix_cp)):
            material = Material(name=material_names[i],type='fixed')
            material.density = fix_rho[i]
            material.specific_heat = fix_cp[i]
            try:
                material.thermal_conductivity = fix_k[i]
            except:
                material.thermal_conductivity = 0.0
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Write materials name and groups number
    # ---------------------------------------------------
    CP_IO.write_basics(type, name, material_group, groups)

    # ---------------------------------------------------
    # Build physical and thermal properties
    # ---------------------------------------------------
    CP_properties.compute_properties(type, name, T1, T2, material_group)

