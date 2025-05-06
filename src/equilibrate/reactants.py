import cantera as ct
import os, sys
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Thermo')
ct.add_directory(datapath+'Chemistry')

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
        self.pressure = pressure
        self.mixture_ratio = mixture_ratio  # O/F ratio
        self.reactants = []
        self.fuel_and_oxidizer = None  # Placeholder for fuel and oxidizer mixtures

    def add_reactant(self, reactant: Reactant):
        self.reactants.append(reactant)


    def build_cantera_solution(self, model='nasa9.yaml'):
        """
        Returns a Cantera Solution set to the specified state.
        """

        species_list = ct.Species.list_from_file(model)

        composition = {}
        for r in self.reactants:
            if r.name in composition:
                composition[r.name] += r.wt
            else:
                composition[r.name] = r.wt

        # Normalize for safety
        total = sum(composition.values())
        for k in composition:
            composition[k] /= total

        avg_temp = sum(r.T * r.wt for r in self.reactants)
        solution = ct.Solution(thermo="ideal-gas", species=species_list)
        solution.TPY = avg_temp, self.pressure, composition

        return solution
    

    def build_cantera_mixture(self, model='nasa9.yaml'):
        """
        Build separate fuel and oxidizer streams and mixes them.
        """
        
        # Check if the model file is passed. If not, extract the species from the already loaded model
        try:
            species_list = ct.Species.list_from_file(model)
        except:
            species_list = model.species()

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
