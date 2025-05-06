from input_CLI import setup_CLI, parse_args

# Parse CLI arguments
args = parse_args()

# Setup reactants using CLI arguments
store, of_switch = setup_CLI(args)

# Build and equilibrate
if of_switch:
    mix, gas = store.build_cantera_mixture(model=args.model)
    mix.equilibrate('HP', solver='gibbs', rtol=1e-6, max_steps=1000)
else:
    gas = store.build_cantera_solution(model=args.model)
    gas.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)

# Output
print("\nMixture composition (mass fractions):")
for name, y in zip(gas.species_names, gas.Y):
    if y > 1e-5:
        print(f"{name}: {y:.6f}")
print(f"\nTemperature [K]: {gas.T}")
print(f"Pressure [Pa]: {gas.P}")
print(f"Enthalpy [J/kg]: {gas.enthalpy_mass}")
