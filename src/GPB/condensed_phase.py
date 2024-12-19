import cantera as ct
import IO
import thermo
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

def build(inifile,section):

    # ---------------------------------------------------
    # Initialization of variables
    # ---------------------------------------------------
    material_group = []

    # ---------------------------------------------------
    # Reading input parameters from INI file
    # ---------------------------------------------------
    # Model definitions, species, and options
    inputModels         = CP_read_models(inifile,section)
    inputFixMat         = CP_read_fixmat(inifile,section)

    name, T1, T2, thermo_model = inputModels

    print(' - Condensed phase:', name)
    print()

    # ---------------------------------------------------
    # Load the Thermo Model (only if phase is not specified)
    # ---------------------------------------------------
    if thermo_model == 'NASA7':
        all_species = ct.Species.list_from_file('nasa_gas.yaml')
    elif thermo_model == 'NASA9':
        all_species = ct.Species.list_from_file('nasa9.yaml')
    elif thermo_model == 'Burcat':
        all_species = ct.Species.list_from_file('burcat.yaml')

    # Assign NASA9 by default reactions phase is not defined
    if thermo_model is None:
        all_species = ct.Species.list_from_file('nasa9.yaml')

    # ---------------------------------------------------
    # Build the ideal-gas phase using the loaded species
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Constant-Cp material
    if inputFixMat is not None:
        fix_names, fix_cp, fix_k, fix_rho = inputFixMat
        for i in range(len(fix_cp)):
            cp_molar = fix_cp[i]
            # Coefficients for ConstantCp: [T_ref, h0, s0, Cp]
            coeffs = (1, cp_molar, 1, cp_molar)
            # Il peso molecolare deve essere definito tramite la composizione elementale.
            # Per imporre un peso molecolare qualsiasi si sfrutta un numero di atomi di
            # idrogeno pari al peso molecolare desiderato diviso quello di 1 atomo di H
            fixmat = ct.Species(fix_names[i])
            fixmat.thermo = ct.ConstantCp(T_low=T1, T_high=T2, P_ref=ct.one_atm, coeffs=coeffs)
            fixmat_phase = ct.Solution(name='constant-cp material', thermo='fixed-stoichiometry', species=[fixmat], equation_of_state_parameters={'density': 152.00} )
            fixmat_phase.TP = 1000, ct.one_atm
            print(fixmat_phase.density)
            material_group.append(fixmat_phase)
    # ---------------------------------------------------


    # ---------------------------------------------------
    # Build thermodynamic properties
    # ---------------------------------------------------
    #thermo.compute_properties(name, T1, T2, species_group)

