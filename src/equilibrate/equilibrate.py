from input_CLI import parse_args
from setup_CLI import setup_CLI
from setup_TEC import setup_TEC
from ORION import write_TEC
from bunch import run_parallel

def main():
    # Parse CLI arguments
    args = parse_args()

    if args.pressure is not None:
        # Setup reactants using CLI arguments
        store, of_switch = setup_CLI(args)
        once = True
    elif args.file is not None:
        # Setup reactants using Tecplot file
        stores, x, y, z, v, v_names = setup_TEC(args.file,args.species)
        once = False
    else:
        print("Nothing to equilibrate.")
        return

    # Build and equilibrate
    if once:
        if of_switch:
            mix, gas = store.build_cantera_mixture(model=args.model, species=args.species)
            mix.equilibrate('HP', solver='gibbs', rtol=1e-6, max_steps=1000)
        else:
            gas = store.build_cantera_solution(model=args.model, species=args.species)
            gas.equilibrate('HP', solver='vcs', rtol=1e-6, max_steps=1000)
    else:
        run_parallel(stores, args, v)

    # Output
    if once:
        print("\nMixture composition (mass fractions):")
        for name, y in zip(gas.species_names, gas.Y):
            if y > 1e-5:
                print(f"{name}: {y:.6f}")
        print(f"\nTemperature [K]: {gas.T}")
        print(f"Pressure [Pa]: {gas.P}")
        print(f"Enthalpy [J/kg]: {gas.enthalpy_mass}")
    else:
        write_TEC("eq-field.tec",x,y,z,v,var_names=v_names)

if __name__ == "__main__":
    main()
