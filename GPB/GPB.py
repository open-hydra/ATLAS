##################################################
#          GPB.py - General Phase Builder        #
##################################################

import cantera as ct
import IO, IO_Legacy
import transport
import thermo
import fixgas
from equilibrium import equilibrium
from IO_INI import *
from NewCEA import CEA
import os, sys

# ---------------------------------------------------
# Environment setup and configuration paths
# ---------------------------------------------------
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)

# Data path setup
datapath = masterpath + '/database/'
ct.add_directory(datapath + 'Thermo')
ct.add_directory(datapath + 'Chemistry')
transdir = datapath + 'transport/CEApolynomials.yaml'

# Input file definition
inifile = 'input.ini'

# ---------------------------------------------------
# Initialization of variables
# ---------------------------------------------------
species_group = []
cea = CEA()  # CEA object for equilibrium calculations
CEA_equilibrium = False  # Flags for equilibrium
cantera_equilibrium = False

# ---------------------------------------------------
# Reading input parameters from INI file
# ---------------------------------------------------
# Model definitions, species, and options
name, T1, T2, thermo_model, transport_model, reaction_model = read_models(inifile,'GPB-Phase1')
inert_species_names                                         = read_inert_species(inifile,'GPB-Phase1')
inputFixGas                                                 = read_fixgas(inifile,'GPB-Phase1')
inerts_mixing, HG                                           = read_options(inifile,'GPB-Phase1')
CEAfile                                                     = read_CEA(inifile,'GPB-Phase1',cea)
result                                                      = read_canteraXequilibrium(inifile,'GPB-Phase1')

# ---------------------------------------------------
# Determine if and which equilibrium to use (Cantera/CEA)
# ---------------------------------------------------
if result is not None:
    fuel, oxy, pressure, of = result
    cantera_equilibrium = True
if CEAfile is not None:
    CEA_equilibrium = True

# ---------------------------------------------------
# Load the Thermo Model
# ---------------------------------------------------
# Select the correct species based on the thermo model
if thermo_model == 'NASA7':
    all_species = ct.Species.list_from_file('nasa_gas.yaml')
elif thermo_model == 'NASA9':
    all_species = ct.Species.list_from_file('nasa9_gas.yaml')

# Assign NASA9 by default reactions phase is not defined
if thermo_model is None and reaction_model is None:
    all_species = ct.Species.list_from_file('nasa9_gas.yaml')

# Force NASA9 if CEA is used
if CEA_equilibrium:
    all_species = ct.Species.list_from_file('nasa9_gas.yaml')

# ---------------------------------------------------
# Load the Transport Model
# ---------------------------------------------------
if transport_model == 'CEA' or CEA_equilibrium:
    CEAdata = IO.read_yaml_file(transdir)


# ---------------------------------------------------
# Build the ideal-gas phase using the loaded species
# ---------------------------------------------------

# ---------------------------------------------------
# Reactive species are added if a reaction model is provided
if reaction_model is not None:
    raw_mechanism = ct.Solution(reaction_model+'.yaml')
    if thermo_model is None:
        mechanism = raw_mechanism
    else:
        reactive_species = [s for s in all_species if s.name in raw_mechanism.species_names]
        mechanism = ct.Solution(thermo='ideal-gas', kinetics='gas', species=reactive_species, reactions=raw_mechanism.reactions())
    mechanism.name = 'reactive species'
    species_group.append(mechanism)
# ---------------------------------------------------

# ---------------------------------------------------
# Cantera equilibrium calculation (if applicable)
if cantera_equilibrium:
    # Perform equilibrium calculation using an existing function
    cte_solution = equilibrium(all_species, fuel, oxy, pressure, of)
    # Extract species objects (not just names) with non-zero mole fractions
    cte_species = [cte_solution.species(i) for i in range(cte_solution.n_species) if cte_solution[i].X > 0]
    # If a reaction model exists, exclude species already in the reaction model
    if reaction_model is not None:
        cte_species = [s for s in cte_species if s.name not in raw_mechanism.species_names]
    # Proceed if there are species left
    if cte_species:
        # Create a new phase using the filtered species objects (not just names)
        cte_phase = ct.Solution(thermo='ideal-gas', species=cte_species, transport='mixture-averaged')
        # Name the new phase based on whether inert mixing is considered
        if inerts_mixing:
            cte_phase.name = 'ct-eq mixture'
        else:
            cte_phase.name = 'ct-eq species'
        # Extract mass fractions for the species in the original solution
        mass_fractions = []
        for s in cte_solution.species_names:
            if cte_solution[s].Y > 0:
                mass_fractions.append(cte_solution[s].Y)
        # Map species names to their mass fractions
        species_fraction_dict = dict(zip([s.name for s in cte_species], mass_fractions))
        # Convert the species fraction dictionary into an ordered array of mass fractions
        mass_fraction_array = np.array([species_fraction_dict[s.name] if s.name in species_fraction_dict else 0.0
                                        for s in cte_phase.species()])
        # Assign mass fractions to the new phase
        cte_phase.Y = mass_fraction_array
        species_group.append(cte_phase)
# ---------------------------------------------------

# ---------------------------------------------------
# CEA equilibrium calculation (if applicable)
if (CEA_equilibrium):
    cea.solve(CEAfile)
    CEA_species = [s for s in all_species if s.name in cea.SE.species.name]
    if reaction_model is not None:
        CEA_species = [s for s in CEA_species if s.name not in raw_mechanism.species_names]
    if CEA_species != []:
        CEA_phase = ct.Solution(thermo='ideal-gas', species=CEA_species, transport='mixture-averaged')
        if (inerts_mixing):
            CEA_phase.name = 'CEA mixture'
        else:
            CEA_phase.name = 'CEA species'
        # Create a dictionary mapping species names to their mass fractions
        cea_massf_dict = dict(zip(cea.SE.species.name, cea.SE.species.massf))
        # Get a list of species in the Cantera phase
        cantera_species_names = CEA_phase.species_names
        # Create an array of mass fractions for the Cantera phase based on CEA data
        mass_fractions_for_cantera = [cea_massf_dict.get(sp, 0.0) for sp in cantera_species_names]
        # Set the mass fractions in the Cantera phase (composition is fixed, temperature may vary)
        CEA_phase.Y = mass_fractions_for_cantera
        species_group.append(CEA_phase)
# ---------------------------------------------------

# ---------------------------------------------------
# Manual Inert species
if inert_species_names is not None:
    manual_inert_species= [s for s in all_species if s.name in inert_species_names]
    if reaction_model is not None:
        manual_inert_species = [s for s in manual_inert_species if s.name not in raw_mechanism.species_names]
    if (cantera_equilibrium):
        manual_inert_species = [s for s in manual_inert_species if s.name not in cte_phase.species_names]
    if (CEA_equilibrium):
        manual_inert_species = [s for s in manual_inert_species if s.name not in cea.SE.species.name]
    if manual_inert_species != []:
        manual_inert_phase = ct.Solution(thermo='ideal-gas',species=manual_inert_species,transport='mixture-averaged')
        manual_inert_phase.name = 'Manual inert species'
        species_group.append(manual_inert_phase)
# ---------------------------------------------------

# ---------------------------------------------------
# Constant-Cp species
if inputFixGas is not None:
    fix_names, fix_cp, fix_mw, fix_mil, fix_kl = inputFixGas
    fixgas_phase = fixgas.build_thermo(T1,T2,fix_names,fix_cp,fix_mw)
    species_group.append(fixgas_phase)
# ---------------------------------------------------

for i in range(len(species_group)):
    solution = species_group[i]
    if HG:
        all_species = [sp for sp in solution.species() if "(L)" not in sp.name]
        cond_species = [sp for sp in solution.species() if "(L)" in sp.name]
        for sp in cond_species:
            HG_species = ct.Species(name=sp.name + '-HG', composition={'H': 1e+5 * sp.molecular_weight / 1.008}, 
                                    thermo=None, transport=None)
            HG_species.thermo = sp.thermo
            if sp.transport is not None: HG_species.transport = sp.transport
            all_species.append(HG_species)
        new_phase = ct.Solution(thermo=solution.thermo_model,species=all_species, kinetics=solution.kinetics_model, 
                                transport=solution.transport_model)
        new_phase.Y = solution.Y
    else:
        gas_species = [sp for sp in solution.species() if "(L)" not in sp.name]
        new_phase = ct.Solution(thermo=solution.thermo_model,species=gas_species, kinetics=solution.kinetics_model, 
                                transport=solution.transport_model)
        mass_fractions = []
        for s in new_phase.species_names:
            if s in solution.species_names:
                mass_fractions.append(solution[s].Y)
        new_phase.Y = mass_fractions
    new_phase.name = solution.name
    species_group[i] = new_phase


# ---------------------------------------------------
# Build thermodynamic properties
# ---------------------------------------------------
thermo.compute_properties(name, T1, T2, species_group)

# ---------------------------------------------------
# Build transport properties
# ---------------------------------------------------
if transport_model is not None:
    if transport_model=='CEA':
        transport.compute_properties(name=name, model=transport_model, T_low=T1, T_max=T2, all_solutions=species_group, database=CEAdata)
    else:
        transport.compute_properties(name=name, model=transport_model, T_low=T1, T_max=T2, all_solutions=species_group)

# ---------------------------------------------------
# Build chemistry properties: finite rate and reactions coefficients
# ---------------------------------------------------
if reaction_model is not None:
    IO.write_chemistry_properties (name, T1, T2, mechanism)
    IO_Legacy.write_chemistry_properties (T1, T2, mechanism)
