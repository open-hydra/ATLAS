import cantera as ct
from . import properties as CP_properties
from . import io as CP_IO
from ini import *
from ini.condensed import phase_header_word
import os, sys
from config import setup_cantera_dirs, CEA_TRANS_FILE

setup_cantera_dirs()
CEAtransdir = CEA_TRANS_FILE

class Material:
    def __init__(self, name, type):
        self.name = name
        self.type = type
        self.solution = None  # Store the Cantera solution object
        self.density = None
        self.specific_heat = None
        self.thermal_conductivity = None
        self.h0 = None   # [J/kg] enthalpy at 298.15 K, fixed-cp materials only (optional [GPB-Phase*] h0)
    
    def load_from_cantera(self, cantera_solution):
        """
        Load the Cantera solution and set the initial temperature.
        """
        self.solution = cantera_solution

def build(type,inifile,section,modeling=None):

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
    header = phase_header_word(type)
    if header.endswith('-dispersed'):
        print(' - Condensed-dispersed phase:', string)
    else:
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
    if fix_cp is None and thermo_model != 'SP-database':
        print(' -- Found T-varying properties materials')
        materials = [s for s in all_mat if s.name in material_names]
        for i, m in enumerate(materials):
            ct_solution = ct.Solution(thermo='fixed-stoichiometry', species=[m])
            material = Material(name=ct_solution.species_names[0], type='cantera')
            material.load_from_cantera(ct_solution)
            if material.density is None:
                material.density = fix_rho[i]
            # the solid layout writes a conductivity column: optional k per material, else 0 (as the fixed branch)
            material.thermal_conductivity = fix_k[i] if fix_k is not None else 0.0
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-constant material
    if fix_cp is not None:
        print(' -- Found fixed properties materials')
        fix_h0 = CP_read_enthalpy_datum(inifile, section, len(fix_cp))
        for i in range(len(fix_cp)):
            material = Material(name=material_names[i],type='fixed')
            material.density = fix_rho[i]
            material.specific_heat = fix_cp[i]
            if fix_h0 is not None:
                material.h0 = fix_h0[i]
            try:
                material.thermal_conductivity = fix_k[i]
            except:
                material.thermal_conductivity = 0.0
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-constant material
    if thermo_model == 'SP-database':
        print(' -- Found T-varying properties materials from database')
        for i in range(len(material_names)):
            material = Material(name=material_names[i],type='SP-database')
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Per-material solver model tokens (P3): validated here so a bad key
    # fails GPB, aligned with material_group (its length = number of
    # materials). NOT written yet: the line below keeps them out of the
    # phase file until the IGLOO/ICE/MI2 readers accept tokens.
    # ---------------------------------------------------
    material_tokens = CP_read_material_models(inifile, section, len(material_group))
    material_tokens = None  # P3.5: delete this line once the IGLOO/ICE/MI2 readers accept tokens (hydra-side handoff)

    # ---------------------------------------------------
    # Write materials name and groups number
    # ---------------------------------------------------
    CP_IO.write_basics(type, name, material_group, groups, modeling, material_tokens=material_tokens)

    # ---------------------------------------------------
    # Build physical and thermal properties
    # ---------------------------------------------------
    CP_properties.compute_properties(type, name, T1, T2, material_group)
