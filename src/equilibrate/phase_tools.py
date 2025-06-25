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
