import cantera as ct
import os, sys
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

def update_thermo_model(old_phase_name,model):
  
  old_phase = ct.Solution(old_phase_name)

  if model == 'NASA9':

    # Load the NASA9 species data
    nasa9_species_list = ct.Species.list_from_file('nasa9.yaml')

    # Create a mapping of NASA9 thermo data by species name
    nasa9_thermo = {species.name: species.thermo for species in nasa9_species_list}

    # Replace thermo data for species in common
    new_species_list = []
    for species in old_phase.species():
        # Default to original thermo and transport
        thermo = species.thermo
        transport = species.transport

        if species.name in nasa9_thermo:
            # Replace thermo if NASA9 data is available
            thermo = nasa9_thermo[species.name]

        # Create a new species with the updated or original data
        new_species = ct.Species(
            name=species.name,
            composition=species.composition
        )
        new_species.thermo = thermo
        new_species.transport = transport

        #print(new_species.composition,new_species.thermo,new_species.transport,thermo)

        # Add to the new species list
        new_species_list.append(new_species)

    # Create a new phase with updated species
    updated_phase = ct.Solution(thermo='ideal-gas', species=new_species_list, reactions=old_phase.reactions())

  else:
    updated_phase = old_phase

  return updated_phase


def add_species(species_name,old_phase,source):

    # List of original species
    original_species = old_phase.species()
    new_species = original_species.copy()

    nasa_gas = ct.Species.list_from_file(source+'.yaml')

    # Find and add N2 species from nasa_gas if missing
    if species_name not in old_phase.species_names:
        species = next((sp for sp in nasa_gas if sp.name == species_name), None)
        if species:
            new_species.append(species)

    # Create a new Solution with the combined species list and the original reactions
    new_phase = ct.Solution(thermo='ideal-gas', kinetics='gas', species=new_species, reactions=old_phase.reactions())
    new_phase.name = old_phase.name

    return new_phase


def extract(models,solutions):
    
    Ta = {}
    for model in models:
        Ta[model] = []
        for sol in solutions[model]:
            Ta[model].append(sol.T)

    if len(models)==1:
        if len(solutions[models[0]])==1:
            print(solutions[models[0]][0].T)
            for s in range(solutions[models[0]][0].n_species):
                print(solutions[models[0]][0].species_names[s],solutions[models[0]][0][s].Y[0])
            return None

    return Ta


def setup_mixture(gas, fuel_comp, oxi_comp, mr):
    """
    Set the gas state according to the mixture ratio and component compositions.

    Parameters:
        gas (ct.Solution): Cantera gas object.
        fuel_comp (dict): Fuel composition as a dictionary, e.g., {'CH4': 1.0}.
        oxi_comp (dict): Oxidizer composition as a dictionary, e.g., {'O2': 0.21, 'N2': 0.79}.
        mr (float): Mixture ratio (fuel to oxidizer).
        
    Returns:
        None: Gas composition is set directly in the `gas` object.
    """

    # Normalize the fuel and oxidizer compositions (in case they don't sum to 1)
    total_fuel = sum(fuel_comp.values())
    total_oxi = sum(oxi_comp.values())
    
    if mr == 0:
        total_fuel = total_fuel + total_oxi
        total_oxi = total_fuel
    normalized_fuel_comp = {species: frac / total_fuel for species, frac in fuel_comp.items()}
    normalized_oxi_comp = {species: frac / total_oxi for species, frac in oxi_comp.items()}

    # Combined mixture composition
    combined_comp = {}
    
    for species, frac in normalized_fuel_comp.items():
        combined_comp[species] = frac/(1+mr)
    
    for species, frac in normalized_oxi_comp.items():
        if species in combined_comp:
            if mr==0:
                combined_comp[species] += frac
            else:
                combined_comp[species] += frac*mr/(1+mr) # If species is in both, sum the fractions
        else:
            if mr==0:
                combined_comp[species] = frac
            else:
                combined_comp[species] = frac*mr/(1+mr) # Oxidizer-only species
    
    # Set the gas composition
    gas.Y = combined_comp