import cantera as ct
import os, sys
from config import setup_cantera_dirs

setup_cantera_dirs()

class Reactant:
    def __init__(self, name='', prop_type='', T=0.0, wt=1.0):
        self.T = T      # Temperature in K
        self.wt = wt    # Weight fraction
        self.name = name
        self.type = prop_type  # 'F' for fuel, 'O' for oxidizer
        self.condensed = False  # True if the reactant is condensed (liquid or solid)

    def build(self,reactant_string,type,temperature):
        """
        Build a reactant object from a string.
        The string should be in the format: "name:weight_fraction"
        """
        reactant_parts = reactant_string.split(':')

        self.name = reactant_parts[0]
        self.wt = float(reactant_parts[1])
        self.type = type
        self.T = temperature
        # Check if the name contains a phase indicator (e.g., '(L)' or '(cr)')
        if '(L)' in self.name or '(cr)' in self.name:
            self.condensed = True
        else:
            self.condensed = False


class ReactantStore:
    def __init__(self, pressure=ct.one_atm, mixture_ratio=None):
        self.index = None  # Placeholder for the index
        self.pressure = pressure
        self.mixture_ratio = mixture_ratio  # O/F ratio
        self.reactants = []
        self.fuel_and_oxidizer = None  # Placeholder for fuel and oxidizer mixtures

    def add_reactant(self, reactant: Reactant):
        self.reactants.append(reactant)


    def build_cantera_solution(self, species, model='NASA9'):
        """
        Returns a Cantera Solution set to the specified state.
        """

        newmodel = update_thermo_model(species,model)
        species_list = newmodel.species()

        composition = {}
        for r in self.reactants:
            composition[r.name] = r.wt

        # Normalize for safety
        total = sum(composition.values())
        for k in composition:
            composition[k] /= total

        avg_temp = sum(r.T*r.wt/total for r in self.reactants)
        solution = ct.Solution(thermo="ideal-gas", species=species_list)
        solution.TPY = avg_temp, self.pressure, composition

        return solution
    

    def build_cantera_mixture(self, species, model='NASA9'):
        """
        Build separate fuel and oxidizer streams and mixes them.
        """

        newmodel = update_thermo_model(species,model)
        species_list = newmodel.species()

        fuel_composition = {}
        oxidizer_composition = {}

        skip_fuel = False
        skip_oxidizer = False

        for r in self.reactants:
            if r.type == 'F':
                fuel_composition[r.name] = fuel_composition.get(r.name, 0.0) + r.wt
                Tf = r.T
                if r.condensed:
                    nasa_species = ct.Species.list_from_file("nasa9.yaml")
                    species = next(s for s in nasa_species if s.name == r.name)
                    fuel = ct.Solution(thermo="ideal-gas", species=[species])
                    skip_fuel = True
            elif r.type == 'O':
                oxidizer_composition[r.name] = oxidizer_composition.get(r.name, 0.0) + r.wt
                To = r.T
                if r.condensed:
                    nasa_species = ct.Species.list_from_file("nasa9.yaml")
                    species = next(s for s in nasa_species if s.name == r.name)
                    oxidizer = ct.Solution(thermo="ideal-gas", species=[species])
                    skip_oxidizer = True

        # Normalize compositions
        fuel_total = sum(fuel_composition.values())
        ox_total = sum(oxidizer_composition.values())
        for k in fuel_composition:
            fuel_composition[k] /= fuel_total
        for k in oxidizer_composition:
            oxidizer_composition[k] /= ox_total

        if not skip_fuel:
            fuel = ct.Solution(thermo="ideal-gas", species=species_list)
            fuel.TPY = Tf, self.pressure, fuel_composition

        if not skip_oxidizer:
            oxidizer = ct.Solution(thermo="ideal-gas", species=species_list)
            oxidizer.TPY = To, self.pressure, oxidizer_composition

        molar_ratio = self.mixture_ratio / (oxidizer.mean_molecular_weight / fuel.mean_molecular_weight)
        moles_oxi = molar_ratio / (1 + molar_ratio)
        moles_fuel = 1 - moles_oxi

        products = ct.Solution(thermo="ideal-gas", species=species_list)

        # create a mixture of the reactants phases with the products model,
        # with the number of moles for fuel and oxidizer based on the O/F ratio
        mix = ct.Mixture([(oxidizer, moles_oxi), (fuel, moles_fuel), (products, 0)])

        return mix, products


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

        # Add to the new species list
        new_species_list.append(new_species)

    # Create a new phase with updated species
    updated_phase = ct.Solution(thermo='ideal-gas', species=new_species_list, reactions=old_phase.reactions())

  else:
    updated_phase = old_phase

  return updated_phase
