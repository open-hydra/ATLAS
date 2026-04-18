import cantera as ct
from . import chemistry as IG_chemistry
from . import transport as IG_transport
from . import thermo as IG_thermo
from . import io as IG_IO
from ini import *
from NewCEA import CEA
import os, sys, re
from config import setup_cantera_dirs, CEA_TRANS_FILE

setup_cantera_dirs()
CEAtransdir = CEA_TRANS_FILE

def build(inifile,section):
    """
    Build the ideal gas phase and its properties based on the provided INI file and section.

    Parameters:
    inifile (str): Path to the INI file containing the input parameters.
    section (str): Section of the INI file to read the parameters from.

    Returns:
    None

    This function performs the following steps:
    1. Initializes variables and reads input parameters from the INI file.
    2. Determines if and which equilibrium to use (Cantera/CEA).
    3. Loads the thermo and transport models if the phase model is not specified.
    4. Builds the ideal-gas phases using the loaded species.
    5. Checks the heavy-gas condition and adjusts species accordingly.
    6. Computes thermodynamic properties and write them.
    7. Computes transport properties and write them.
    8. Writes chemistry properties if a reaction model is provided.

    The ideal-gas phases are built as follows:
    1. Direct address of a phase solution.
    2. Reactive species if a reaction model is provided.
    3. Manual inert species.
    4. Constant-Cp species.
    5. Mixtures.
    6. Cantera equilibrium calculation if applicable.
    7. CEA equilibrium calculation if applicable.
    """

    # ---------------------------------------------------
    # Initialization of variables
    # ---------------------------------------------------
    species_group = []
    cea = CEA()
    CEA_equilibrium = False 
    cantera_equilibrium = False
    ct.add_directory(os.getcwd())

    # ---------------------------------------------------
    # Reading input parameters from INI file
    # ---------------------------------------------------
    # Model definitions, species, and options
    inputModels         = IG_read_models(inifile,section)
    inert_species_names = IG_read_inert_species(inifile,section)
    inputFixGas         = IG_read_fixgas(inifile,section)
    inerts_mixing, HG   = IG_read_options(inifile,section)
    inputCEA            = read_eq_CEA(inifile,section,cea)
    inputCTE            = read_eq_cantera(inifile,section)
    inputMix            = IG_read_mixture(inifile,section)

    name, T1, T2, phase_model, thermo_model, transport_model, reaction_model = inputModels

    if name.endswith('-'):
        string = name[:-1]  # Remove the last character
    else:
        string = 'no name'
    print(' - Ideal-gas phase:', string)
    print()

    # ---------------------------------------------------
    # Determine if and which equilibrium to use (Cantera/CEA)
    # ---------------------------------------------------
    if inputCTE is not None:
        cte_reactants = inputCTE
        cantera_equilibrium = True
    if inputCEA is not None:
        CEAfile = inputCEA
        CEA_equilibrium = True

    # ---------------------------------------------------
    # Load the Thermo Model (only if phase is not specified)
    # ---------------------------------------------------
    if phase_model is None:
        if thermo_model == 'NASA7':
            all_species = ct.Species.list_from_file('nasa_gas.yaml')
        elif thermo_model == 'NASA9':
            all_species = ct.Species.list_from_file('nasa9.yaml')
        elif thermo_model == 'Burcat':
            all_species = ct.Species.list_from_file('burcat.yaml')

        # Assign NASA9 by default reactions phase is not defined
        if thermo_model is None and reaction_model is None:
            all_species = ct.Species.list_from_file('nasa9.yaml')

        # Force NASA9 if CEA is used
        if CEA_equilibrium:
            all_species = ct.Species.list_from_file('nasa9.yaml')


    # ---------------------------------------------------
    # Load the Transport Model (only if phase is not specified)
    # ---------------------------------------------------
    if phase_model is None:
        if transport_model == 'CEA' or CEA_equilibrium:
            CEAdata = IG_IO.read_yaml_file(CEAtransdir)
    else:
        transport_model = 'cantera'


    # ---------------------------------------------------
    # Build the ideal-gas phase using the loaded species
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Direct address of a phase solution.
    if phase_model is not None:
        print(' -- Found phase model:',phase_model)
        phase = ct.Solution(phase_model + '.yaml')
        if (phase.n_reactions>0):
            mechanism = phase
            reaction_model = phase
        species_group.append(phase)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Reactive species are added if a reaction model is provided. 
    # By default, the thermo properties are read from the chosen database.
    # if one species is not found, it is taken from the reaction model.
    # Transport properties are read from the reaction model.
    if reaction_model is not None and phase_model is None:
        print(' -- Found reaction model:',reaction_model)
        # Load the full mechanism
        raw_mechanism = ct.Solution(reaction_model + '.yaml')
        # Create a dictionary for quick lookup of species
        all_species_dict = {s.name: s for s in all_species}
        # Ensure all species from the mechanism are included
        combined_species = []
        for species_name in raw_mechanism.species_names:
            if species_name in all_species_dict:
                # Use the thermo definition from all_species if available, take transport from mechanism
                all_species_dict[species_name].transport = raw_mechanism.species(species_name).transport
                combined_species.append(all_species_dict[species_name])
            else:
                # Otherwise, use the definition from the mechanism
                print('This species is not present in the employed database: ',species_name)
                combined_species.append(raw_mechanism.species(species_name))
        # Create the custom mechanism
        mechanism = ct.Solution(thermo='ideal-gas',kinetics='gas',species=combined_species,reactions=raw_mechanism.reactions())
        mechanism.name = raw_mechanism.name
        mechanism.transport_model = raw_mechanism.transport_model
        species_group.append(mechanism)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Cantera equilibrium calculation (if applicable)
    if cantera_equilibrium:
        print(' -- Found Cantera equilibrium')
        # Perform equilibrium calculation
        eq_mix, eq_gas = cte_reactants.build_cantera_mixture(species="FFCM2.yaml",model=thermo_model)
        eq_mix.equilibrate('HP', solver='gibbs', rtol=1e-6, max_steps=1000)
        # Extract species objects (not just names) with non-zero mole fractions
        eq_species = [eq_gas.species(i) for i in range(eq_gas.n_species) if eq_gas[i].X > 1e-5]
        # If a reaction model exists, exclude species already in the reaction model
        if reaction_model is not None:
            eq_species = [s for s in eq_species if s.name not in raw_mechanism.species_names]
        # Proceed if there are species left
        if eq_species:
            # Create a new phase using the filtered species objects (not just names)
            eq_phase = ct.Solution(thermo='ideal-gas', species=eq_species, transport='mixture-averaged')
            # Name the new phase based on whether inert mixing is considered
            if inerts_mixing:
                eq_phase.name = 'cte-mixture'
            else:
                eq_phase.name = 'cte-species'
            # Extract mass fractions for the species in the original solution
            mass_fractions = []
            for s in eq_gas.species_names:
                if eq_gas[s].Y > 0:
                    mass_fractions.append(eq_gas[s].Y)
            # Map species names to their mass fractions
            species_fraction_dict = dict(zip([s.name for s in eq_species], mass_fractions))
            # Convert the species fraction dictionary into an ordered array of mass fractions
            mass_fraction_array = np.array([species_fraction_dict[s.name] if s.name in species_fraction_dict else 0.0
                                            for s in eq_phase.species()])
            # Assign mass fractions to the new phase
            eq_phase.Y = mass_fraction_array
            species_group.append(eq_phase)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # CEA equilibrium calculation (if applicable)
    if (CEA_equilibrium):
        print(' -- Found CEA equilibrium')
        cea.solve(CEAfile)
        CEA_species = [s for s in all_species if s.name in cea.SE.species.name]
        if reaction_model is not None:
            CEA_species = [s for s in CEA_species if s.name not in raw_mechanism.species_names]
        if CEA_species != []:
            CEA_phase = ct.Solution(thermo='ideal-gas', species=CEA_species, transport='mixture-averaged')
            if (inerts_mixing):
                CEA_phase.name = 'CEA-mixture'
            else:
                CEA_phase.name = 'CEA-species'
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
        print(' -- Found manually specified species')
        # Get thermo properties
        manual_inert_species= [s for s in all_species if s.name in inert_species_names]
        # Get transport properties
        transport_species_list = ct.Species.list_from_file('Lennard-Jones.yaml')
        transport_species_dict = {sp.name: sp for sp in transport_species_list}
        for s in manual_inert_species:
            if s.name in transport_species_dict:
                s.transport = transport_species_dict[s.name].transport
            else:
              if (transport_model=='cantera'):
                print(f"No transport data found for species: {s.name}")
        if reaction_model is not None:
            manual_inert_species = [s for s in manual_inert_species if s.name not in raw_mechanism.species_names]
        if (cantera_equilibrium):
            manual_inert_species = [s for s in manual_inert_species if s.name not in cte_phase.species_names]
        if (CEA_equilibrium):
            manual_inert_species = [s for s in manual_inert_species if s.name not in cea.SE.species.name]
        if manual_inert_species != []:
            manual_inert_phase = ct.Solution(thermo='ideal-gas',species=manual_inert_species)
            manual_inert_phase.name = 'Manual-inert-species'
            manual_inert_phase.transport_model = 'mixture-averaged'
            species_group.append(manual_inert_phase)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Constant-Cp species
    if inputFixGas is not None:
        fix_names, fix_cp, fix_mw, fix_mil, fix_kl = inputFixGas
        dummy_species_list = []
        for i in range(len(fix_cp)):
            cp_molar = fix_cp[i] * fix_mw[i]
            # Coefficients for ConstantCp: [T_ref, h0, s0, Cp]
            coeffs = (1, cp_molar, 1, cp_molar)
            # Il peso molecolare deve essere definito tramite la composizione elementale.
            # Per imporre un peso molecolare qualsiasi si sfrutta un numero di atomi di
            # idrogeno pari al peso molecolare desiderato diviso quello di 1 atomo di H
            fixgas_species = ct.Species(fix_names[i], 'H:'+str(fix_mw[i]/1.008))
            fixgas_species.thermo = ct.ConstantCp(T_low=T1, T_high=T2, P_ref=ct.one_atm, coeffs=coeffs)
            dummy_species_list.append(fixgas_species)
        fixgas_phase = ct.Solution(name='constant-cp species', thermo='ideal-gas', species=dummy_species_list)
        species_group.append(fixgas_phase)
        if fix_mil is not None: transport_model = 'constant'
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Mixtures
    if inputMix is not None:
        print(' -- Found mixture')
        mix, mix_name = inputMix
        mix_composition = re.findall(r'{(.*?):(.*?)}', mix[0])
        mix_dict = {species: float(value) for species, value in mix_composition}
        selected_species = [sp for sp in all_species if sp.name in mix_dict]
        # Get transport properties
        transport_species_list = ct.Species.list_from_file('Lennard-Jones.yaml')
        transport_species_dict = {sp.name: sp for sp in transport_species_list}
        for s in selected_species:
            if s.name in transport_species_dict:
                s.transport = transport_species_dict[s.name].transport
            else:
                print(f"No transport data found for species: {s.name}")
        mix_phase = ct.Solution(thermo='ideal-gas',species=selected_species)
        mix_phase.transport_model = 'mixture-averaged'
        mix_phase.TPY = 313.0, ct.one_atm, mix_dict
        mix_phase.name = mix_name+'mixture'
        species_group.append(mix_phase)
    # ---------------------------------------------------

    # ---------------------------------------------------
    # Check the heavy-gas condition
    # ---------------------------------------------------
    for i in range(len(species_group)):
        solution = species_group[i]
        if HG:
            all_species = [sp for sp in solution.species() if "(L)" not in sp.name]
            cond_species = [sp for sp in solution.species() if "(L)" in sp.name]
            for sp in cond_species:
                HG_species = ct.Species(name=sp.name + '-HG', composition={'H': sp.molecular_weight / 1.008}, 
                                         thermo=None, transport=None)
                HG_species.thermo = sp.thermo
                if sp.transport is not None: HG_species.transport = sp.transport
                all_species.append(HG_species)
            new_phase = ct.Solution(thermo=solution.thermo_model,species=all_species, kinetics=solution.kinetics_model)
            new_phase.Y = solution.Y
        else:
            gas_species = [sp for sp in solution.species() if "(L)" not in sp.name]
            new_phase = ct.Solution(thermo=solution.thermo_model,species=gas_species, kinetics=solution.kinetics_model)
            mass_fractions = []
            for s in new_phase.species_names:
                if s in solution.species_names:
                    mass_fractions.append(solution[s].Y)
            new_phase.Y = mass_fractions
        new_phase.name = solution.name
        new_phase.transport_model = solution.transport_model
        species_group[i] = new_phase


    # ---------------------------------------------------
    # Build thermodynamic properties
    # ---------------------------------------------------
    IG_thermo.compute_properties(name, T1, T2, species_group)

    # ---------------------------------------------------
    # Build transport properties
    # ---------------------------------------------------
    if transport_model is not None:
        if transport_model=='CEA':
            IG_transport.compute_properties(name=name, model=transport_model, T_low=T1, T_max=T2, all_solutions=species_group, database=CEAdata)
        elif transport_model=='constant':
            IG_transport.compute_properties(name=name, model=transport_model, T_low=T1, T_max=T2, all_solutions=species_group, mil=fix_mil, kl=fix_kl)
        else:
            IG_transport.compute_properties(name=name, model=transport_model, T_low=T1, T_max=T2, all_solutions=species_group)

    # ---------------------------------------------------
    # Build chemistry properties
    # ---------------------------------------------------
    if reaction_model is not None:
        sp = []
        # Before writing the reactions data, define an array of inert species 
        # to properly write the stoichiometric info
        for p in species_group:
            if p.name != mechanism.name and "mix" not in p.name:
                for sp_ in p.species_names: sp.append(sp_)
            elif "mix" in p.name:
                sp.append('inertMix')
        IG_chemistry.compute_properties (name, T1, T2, mechanism, sp)
