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