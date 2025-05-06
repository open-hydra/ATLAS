import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Equilibrate a fuel/oxidizer mixture using Cantera.")
    parser.add_argument("--model", type=str, required=True, help="Cantera YAML file (e.g., FFCM2.yaml)")
    parser.add_argument("--fuel", type=str, nargs='+', required=False,
                        help='Fuel composition entries like CH4:0.3 or CH4 (implies CH4:1.0)')
    parser.add_argument("--oxidizer", type=str, nargs='+', required=False,
                        help='Oxidizer composition entries like O2:0.7 or O2 (implies O2:1.0)')
    parser.add_argument("--reactants", type=str, nargs='+', required=False,
                        help='Reactants composition entries like O2:0.7,CH4:0.6')
    parser.add_argument("--fuel-T", type=float, default=300.0, help="Fuel temperature in K")
    parser.add_argument("--oxidizer-T", type=float, default=300.0, help="Oxidizer temperature in K")
    parser.add_argument("--temperature", type=float, default=300.0, help="Reactants temperature in K")
    parser.add_argument("--pressure", type=float, default=101250.0, help="Pressure in Pa")
    parser.add_argument("--mixture-ratio", type=float, default=None, help="Mixture ratio (fuel/oxidizer mass)")
    return parser.parse_args()

def parse_composition(entries):
    """Ensure each entry has a weight fraction; default to 1.0 if not specified."""
    out = []
    for e in entries:
        if ':' not in e:
            e = f"{e}:1.0"
        out.append(e)
    return out

def setup_CLI(args):
    from reactants import Reactant, ReactantStore

    of_switch = True
    store = ReactantStore()

    if args.pressure is None:
        return None
    store.pressure = args.pressure
    store.mixture_ratio = args.mixture_ratio
    if store.mixture_ratio is None:
        of_switch = False

    # Parse and build fuel reactants
    if args.fuel is not None:
        for rstr in parse_composition(args.fuel):
            r = Reactant()
            r.build(rstr, "F", args.fuel_T)
            store.add_reactant(r)

    # Parse and build oxidizer reactants
    if args.oxidizer is not None:
        for rstr in parse_composition(args.oxidizer):
            r = Reactant()
            r.build(rstr, "O", args.oxidizer_T)
            store.add_reactant(r)

    # Parse and build general reactants
    if args.reactants is not None:
        for rstr in parse_composition(args.reactants):
            r = Reactant()
            r.build(rstr, "N", args.temperature)
            store.add_reactant(r)

    return store, of_switch