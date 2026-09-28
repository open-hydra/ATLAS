import cantera as ct
from . import properties as CP_properties
from . import io as CP_IO
from ini import *
from ini.condensed import phase_header_word, CP_read_per_material
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
    thermo_given = thermo_model is not None   # before the NASA9 default below

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
    # T-varying material: a database phase (no cp, or thermo given with cp). Every INI
    # material in INI order, so groups[i], rho[i], k[i], h0[i] and material_tokens[i] are
    # the material's own; one the database lacks takes its constant cp, rho, k, h0 from the INI.
    database = thermo_model in THERMO_FILES and (fix_cp is None or thermo_given)
    if database:
        print(' -- Found T-varying properties materials')
        names = [material_names] if isinstance(material_names, str) else list(material_names)
        nmat = len(names)
        rho = CP_read_per_material(inifile, section, 'rho', nmat)
        k = CP_read_per_material(inifile, section, 'k', nmat)
        cp = CP_read_per_material(inifile, section, 'cp', nmat)
        h0 = CP_read_enthalpy_datum(inifile, section, nmat)
        if rho is None:
            raise SystemExit(f"[ERROR] [{section}] rho: give the density of each material (one value per material)")
        species = {s.name: s for s in all_mat}
        missing = [n for n in names if n not in species]
        if missing and cp is None:
            raise SystemExit(f"[ERROR] [{section}] {' '.join(missing)}: not in {THERMO_FILES[thermo_model]}, and no cp "
                             "is given: correct the name, or give cp (one value per material, used only by the "
                             "materials the database lacks)")
        if missing and h0 is None and len(missing) < nmat:
            raise SystemExit(f"[ERROR] [{section}] {' '.join(missing)}: constant properties in a phase whose other "
                             f"materials come from {THERMO_FILES[thermo_model]} (absolute enthalpy): give h0 "
                             "(enthalpy at 298.15 K on the database's formation scale)")
        for i, n in enumerate(names):
            if n in species:
                ct_solution = ct.Solution(thermo='fixed-stoichiometry', species=[species[n]])
                material = Material(name=ct_solution.species_names[0], type='cantera')
                material.load_from_cantera(ct_solution)
                if cp is not None:
                    print(f' -- {n} from {THERMO_FILES[thermo_model]}: its cp in the INI is not used')
            else:
                material = Material(name=n, type='fixed')
                material.specific_heat = cp[i]
                if h0 is not None:
                    material.h0 = h0[i]
                print(f' -- {n} is not in {THERMO_FILES[thermo_model]}: constant properties from the INI '
                      f'(cp = {cp[i]:g}, rho = {rho[i]:g}' + (f', h0 = {h0[i]:g})' if h0 is not None else ')'))
            material.density = rho[i]
            # the solid layout writes a conductivity column: optional k per material, else 0 (as the fixed branch)
            material.thermal_conductivity = k[i] if k is not None else 0.0
            material_group.append(material)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # T-constant material
    if fix_cp is not None and not database:
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
