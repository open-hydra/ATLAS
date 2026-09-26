import cantera as ct
from . import properties as CP_properties
from . import io as CP_IO
from ini import *
from ini.condensed import phase_header_word
import os, sys
from config import setup_cantera_dirs, CEA_TRANS_FILE

setup_cantera_dirs()
CEAtransdir = CEA_TRANS_FILE

THERMO_FILES = {'NASA7': 'nasa_condensed.yaml', 'NASA9': 'nasa9.yaml', 'Burcat': 'burcat.yaml'}

class Material:
    def __init__(self, name, type):
        self.name = name
        self.type = type
        self.solution = None  # Store the Cantera solution object
        self.density = None
        self.specific_heat = None
        self.thermal_conductivity = None
        self.h0 = None   # [J/kg] enthalpy at 298.15 K, fixed-cp materials only (optional [GPB-Phase*] h0)
        self.psat_pair = None   # (liquid, vapour) cantera Species giving p_sat(T) (optional psat-vapour)
    
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
    if thermo_model in THERMO_FILES:
        all_mat = ct.Species.list_from_file(THERMO_FILES[thermo_model])

    # ---------------------------------------------------
    # Build the specific heat
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-varying material
    if fix_cp is None and thermo_model != 'SP-database':
        print(' -- Found T-varying properties materials')
        # INI order, not database order: groups[i], fix_rho[i] and material_tokens[i]
        # are indexed by the position in the INI `material` list
        materials = sorted([s for s in all_mat if s.name in material_names],
                           key=lambda s: material_names.index(s.name))
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
    # Optional saturation pressure: per material, a liquid/vapour
    # species pair of the loaded database (psat-vapour, psat-liquid);
    # compute_properties tabulates it as the Psat column
    # ---------------------------------------------------
    psat_pairs = CP_read_psat_pairs(inifile, section, [m.name for m in material_group])
    if psat_pairs is not None:
        if not header.endswith('-dispersed'):
            raise SystemExit(f"[ERROR] [{section}] psat-vapour: a solid phase has no Psat column (dispersed phases only)")
        if thermo_model not in ('NASA9', 'Burcat'):
            loaded = (f"{THERMO_FILES[thermo_model]}, which holds no vapour species" if thermo_model in THERMO_FILES
                      else "no species database")
            raise SystemExit(f"[ERROR] [{section}] psat-vapour needs thermo = NASA9 or Burcat: "
                             f"thermo = {thermo_model} loads {loaded}")
        species = {s.name: s for s in all_mat}
        for material, pair in zip(material_group, psat_pairs):
            if pair is not None:
                material.psat_pair = CP_properties.resolve_psat_pair(section, material.name, pair, species,
                                                                     THERMO_FILES[thermo_model])

    # ---------------------------------------------------
    # Per-material solver model tokens: validated here so a bad key
    # fails GPB, aligned with material_group (its length = number of
    # materials), written as key=value after '<name> <groups>' on the
    # material line of <name>phase.txt (IGLOO reads them there).
    # ---------------------------------------------------
    material_tokens = CP_read_material_models(inifile, section, len(material_group))

    # ---------------------------------------------------
    # Write materials name and groups number
    # ---------------------------------------------------
    CP_IO.write_basics(type, name, material_group, groups, modeling, material_tokens=material_tokens)

    # ---------------------------------------------------
    # Build physical and thermal properties
    # ---------------------------------------------------
    CP_properties.compute_properties(type, name, T1, T2, material_group)
