import cantera as ct
from . import chemistry as IG_chemistry
from . import transport as IG_transport
from . import thermo as IG_thermo
from . import io as IG_IO
from .cea_compat import CEA
from ini import *
from PiNeR import get
import os, sys, re
from config import setup_cantera_dirs, CEA_TRANS_FILE, CHEMISTRY_DIR

setup_cantera_dirs()
CEAtransdir = CEA_TRANS_FILE

# ---------------------------------------------------------------------------
# Checks of a tabulated mechanism against what the chemistry tables can hold.
# Every message goes to stdout; nothing is ever written into the product files
# (the reader of the tables reads them positionally).
# ---------------------------------------------------------------------------
def _flint_guards(phase):
    """Refuse the falloff forms other than Troe and Lindemann and the chemically-activated reactions; warn on the name 'gas' and on pressure-dependent rates, which the tables hold at 1 atm only."""
    eff = phase.name.strip()
    rx = list(phase.reactions())
    shown = phase.name
    # the tables carry the Arrhenius, falloff-Troe and falloff-Lindemann forms only: every other falloff form (SRI, Tsang, ...)
    # and every chemically-activated reaction would be in no table
    bad = [f'{i+1} ({r.equation}; {r.reaction_type})' for i, r in enumerate(rx) if 'chemically-activated' in r.reaction_type
           or ('falloff' in r.reaction_type and r.reaction_type not in ('falloff-Troe', 'falloff-Lindemann'))]
    if bad:
        print(f"[ERROR] GPB: phase {shown}: {len(bad)} reactions have a form the chemistry tables cannot hold (they carry the Arrhenius, falloff-Troe and falloff-Lindemann forms only): {', '.join(bad)}")
        sys.exit(1)
    if eff == 'gas':
        print("[WARNING] GPB: phase name 'gas' identifies no mechanism: FLINT falls back to the general procedure; name the mechanism in the yaml")
    pdep = [f'{i+1} ({r.equation})' for i, r in enumerate(rx) if 'pressure-dependent-Arrhenius' in r.reaction_type or ('Chebyshev' in r.reaction_type and r.rate.n_pressure > 1)]
    if pdep:
        print(f"[WARNING] GPB: phase {shown}: {len(pdep)} pressure-dependent reactions (PLOG / multi-pressure Chebyshev) are tabulated at 1 atm only: {', '.join(pdep[:10])}{' ...' if len(pdep) > 10 else ''}")

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
    inerts_mixing, HG, strict_thermo = IG_read_options(inifile,section)
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
        elif thermo_model is None:
            # No thermo selector: NASA9 database for the species that come from no reactions file (species list,
            # mixture); the species of a reactions file keep the records of the file (file_thermo below)
            all_species = ct.Species.list_from_file('nasa9.yaml')
        else:
            print(f'[ERROR] GPB: thermo = {thermo_model} is not a database (allowed: NASA7, NASA9, Burcat)')
            sys.exit(1)

        # Force NASA9 if CEA is used (a thermo key that is ignored is said)
        if CEA_equilibrium:
            if thermo_model not in (None, 'NASA9'):
                print(f"[WARNING] key thermo of section [{section}]: thermo = {thermo_model} is ignored with CEA-file: the CEA equilibrium species use the NASA9 database")
            all_species = ct.Species.list_from_file('nasa9.yaml')

        # reactions = without thermo: the species of the file keep the thermo records of the file; with CEA-file the
        # NASA9 database forced above replaces them, as for the CEA equilibrium species
        file_thermo = reaction_model is not None and thermo_model is None and not CEA_equilibrium
        if file_thermo:
            print(f'[INFO] GPB: reactions = {reaction_model} without thermo: the thermo records of the file are used '
                  f'(set thermo = NASA7, NASA9 or Burcat to replace them with a database)')
        elif reaction_model is not None and thermo_model is None:
            print(f'[INFO] GPB: reactions = {reaction_model} without thermo, with CEA-file: NASA9 database assumed '
                  f'(thermo = NASA9), as for the CEA equilibrium species')


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
    # The thermo properties are read from the chosen database (thermo, or NASA9 with CEA-file);
    # without thermo, and for a species that the database lacks, they are taken from the reaction model.
    # Transport properties are read from the reaction model.
    if reaction_model is not None and phase_model is None:
        print(' -- Found reaction model:',reaction_model)
        # Load the full mechanism
        raw_mechanism = ct.Solution(reaction_model + '.yaml')
        # Species of the file without transport data: transport = cantera needs the file records (refused before any
        # product); transport = CEA takes the CEApolynomials records (simplified law without a record); without a
        # transport key no transport table is written. The database record of such a species keeps its (empty)
        # transport: the copy below is skipped (copying a missing record crashed Cantera 3.0.1).
        notr = [s.name for s in raw_mechanism.species() if s.transport is None]
        if notr and transport_model not in (None, 'CEA'):
            print(f"[ERROR] key reactions of section [{section}]: {reaction_model}.yaml has {len(notr)} of {raw_mechanism.n_species} species without transport data ({', '.join(notr[:10])}{' ...' if len(notr) > 10 else ''}): add the Lennard-Jones records to the file (the thermo databases carry no transport data; needed with transport = cantera; transport = CEA takes the CEApolynomials records instead)")
            sys.exit(1)
        if notr and transport_model == 'CEA':
            print(f"[INFO] GPB: transport = CEA: {len(notr)} species of {reaction_model}.yaml carry no transport data and take the CEApolynomials record: {', '.join(notr[:10])}{' ...' if len(notr) > 10 else ''}")
        # Create a dictionary for quick lookup of species
        # (none with reactions = without thermo: every species keeps the thermo and transport records of the file)
        all_species_dict = {} if file_thermo else {s.name: s for s in all_species}
        # Ensure all species from the mechanism are included
        combined_species = []
        thermo_replaced = []
        for species_name in raw_mechanism.species_names:
            if species_name in all_species_dict:
                # The database record replaces the file record: print the h(298.15 K) difference, WARNING above 1 kJ/mol
                db_sp, file_sp = all_species_dict[species_name], raw_mechanism.species(species_name)
                Tref = max(298.15, db_sp.thermo.min_temp, file_sp.thermo.min_temp)
                dh = (db_sp.thermo.h(Tref) - file_sp.thermo.h(Tref)) / 1.0e6   # kJ/mol, database - file
                lab = 'dh298' if Tref == 298.15 else f'dh{Tref:g}'   # a record that starts above 298.15 K is compared at its lower bound
                print(f"{'[WARNING]' if abs(dh) > 1.0 else '[INFO]'} GPB: species {species_name}: thermo from the database replaces the file record ({lab} database - file = {dh:+.3f} kJ/mol)")
                if abs(dh) > 1.0: thermo_replaced.append(species_name)
                # Use the thermo definition from all_species if available, take transport from mechanism
                if file_sp.transport is not None:
                    all_species_dict[species_name].transport = file_sp.transport
                combined_species.append(all_species_dict[species_name])
            else:
                # Otherwise, use the definition from the mechanism (said when a database was looked up)
                if not file_thermo:
                    print('This species is not present in the employed database: ',species_name)
                combined_species.append(raw_mechanism.species(species_name))
        if strict_thermo and thermo_replaced:
            hint = f'leave out thermo or use phase = {reaction_model} for the file records, or strict-thermo = false'
            if CEA_equilibrium:   # CEA-file forces NASA9 on the species of the file
                hint = 'with CEA-file the species of the file take NASA9: strict-thermo = false accepts them'
            print(f"[ERROR] GPB: strict-thermo = true: the database thermo differs by more than 1 kJ/mol at 298.15 K "
                  f"(or at the lower bound of a record that starts above it) for: {', '.join(thermo_replaced)} "
                  f"({hint})")
            sys.exit(1)
        # Create the custom mechanism
        mechanism = ct.Solution(thermo='ideal-gas',kinetics='gas',species=combined_species,reactions=raw_mechanism.reactions())
        mechanism.name = raw_mechanism.name
        mechanism.transport_model = raw_mechanism.transport_model
        species_group.append(mechanism)
    # ---------------------------------------------------

    # Checks of the mechanism against what the tables can hold: before any product file is written
    if reaction_model is not None:
        _flint_guards(mechanism)

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


    tmin_given = get(inifile, section, 'Tmin', str) is not None
    # Below the polynomial range of a species thermo.py extrapolates cp, h, s linearly (said only for an explicit Tmin)
    lo = {sp.name: sp.thermo.min_temp for sol in species_group for sp in sol.species()}
    if tmin_given and lo and T1 < max(lo.values()):
        worst = max(lo, key=lo.get)
        print(f"[WARNING] GPB: Tmin = {T1} K is below the polynomial range of {sum(1 for v in lo.values() if v > T1)} species (up to {lo[worst]:g} K for {worst}): cp, h, s are extrapolated linearly below the range")
    # Above the polynomial maximum of a species cp is frozen at the bound (h, s extended linearly): one [INFO] line
    hi = {sp.name: sp.thermo.max_temp for sol in species_group for sp in sol.species()}
    frozen = sorted(n for n, v in hi.items() if v < T2)
    if frozen:
        print(f"[INFO] GPB: cp frozen at the polynomial maximum for {len(frozen)} species above their range (from {min(hi[n] for n in frozen):g} K) up to Tmax = {T2} K: {', '.join(frozen[:10])}{' ...' if len(frozen) > 10 else ''}")

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

        # Binary diffusion coefficients (multicomponent diffusion model, optional output).
        # Only meaningful for kinetic-theory transport; CEA/constant models have no pair data.
        if transport_model not in ('CEA', 'constant'):
            IG_transport.compute_binary_diffusion(name, T1, T2, species_group)

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
        # chemistry-info.txt always ends with the block 'Reaction orders' / <n> / '<ir> <species> <order>' (n = 0 when the
        # yaml gives no explicit orders), for every phase: the reader of the tables tells a current file from one of an
        # older writer by it. ir is the index of the reaction in the list above. The tables carry orders for the
        # Arrhenius-type reactions only: orders given on a falloff reaction are not written (WARNING).
        rows, skipped = [], []
        for i, r in enumerate(mechanism.reactions()):
            if not r.orders:
                continue
            if 'falloff' in r.reaction_type:
                skipped.append(f'{i+1} ({r.equation})')
                continue
            rows += [(i + 1, s, o) for s, o in r.orders.items()]
        if skipped:
            print(f"[WARNING] GPB: phase {mechanism.name}: the explicit orders of {len(skipped)} falloff reactions are not written (the chemistry tables carry orders for Arrhenius-type reactions only): {', '.join(skipped)}")
        with open(IG_IO.outpath + name + 'chemistry-info.txt', 'a') as f:
            f.write(f"\nReaction orders\n{len(rows)}\n" + ''.join(f"{ir} {s} {o}\n" for ir, s, o in rows))
