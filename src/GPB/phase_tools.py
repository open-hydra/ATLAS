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

  # Optionally save to a new YAML file
  updated_phase.write_yaml('updated_nasa9_phase.yaml')

  print("Thermo data updated successfully!")

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