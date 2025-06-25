import cantera as ct
from reactants import Reactant, ReactantStore

def test_without_mixture_ratio():
    print("\n--- Test: Without mixture ratio ---")

    store = ReactantStore()
    store.pressure = ct.one_atm

    # Add two reactants with predefined weight fractions
    r1 = Reactant()
    r1.build("CH4:0.3", "F", 300)
    r2 = Reactant()
    r2.build("O2:0.7", "O", 300)

    store.add_reactant(r1)
    store.add_reactant(r2)

    gas = store.build_cantera_solution(species="FFCM2.yaml",model='own')
    gas.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)

    print(f"Mixture composition (mass):")
    for name, y in zip(gas.species_names, gas.Y):
        if y > 1e-5:
            print(f"{name}: {y:.6f}")
    print(f"Temperature [K]: {gas.T}")
    print(f"Pressure [Pa]: {gas.P}")
    print(f"Enthalpy [J/kg]: {gas.enthalpy_mass}")


def test_with_mixture_ratio():
    print("\n--- Test: With mixture ratio ---")

    store = ReactantStore()
    store.pressure = ct.one_atm
    store.mixture_ratio = 7/3

    # Add pure fuel and oxidizer components
    r1 = Reactant()
    r1.build("CH4(L):1.0", "F", 100)
    r2 = Reactant()
    r2.build("O2(L):1.0", "O", 90)

    store.add_reactant(r1)
    store.add_reactant(r2)

    mix, gas = store.build_cantera_mixture(species="FFCM2.yaml",model='own')
    mix.equilibrate('HP', solver='gibbs', rtol=1e-6, max_steps=1000)

    print(f"Mixture composition (mass):")
    for name, y in zip(gas.species_names, gas.Y):
        if y > 1e-5:
            print(f"{name}: {y:.6f}")
    print(f"Temperature [K]: {gas.T}")
    print(f"Pressure [Pa]: {gas.P}")
    print(f"Enthalpy [J/kg]: {gas.enthalpy_mass}")

if __name__ == "__main__":
    test_without_mixture_ratio()
    test_with_mixture_ratio()
