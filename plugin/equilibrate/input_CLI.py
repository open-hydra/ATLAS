import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Equilibrate a fuel/oxidizer mixture using Cantera.")
    parser.add_argument("--species", type=str, required=True, help="Cantera YAML file (e.g., FFCM2.yaml)")

    parser.add_argument("--model", type=str, required=True, help="Thermodynamic model (e.g., NASA9)")

    parser.add_argument("--file", type=str, required=False, help="Tecplot file to equilibrate)")

    parser.add_argument("--fuel", type=str, nargs='+', required=False,
                        help='Fuel composition entries like CH4:0.3 or CH4 (implies CH4:1.0)')
    parser.add_argument("--oxidizer", type=str, nargs='+', required=False,
                        help='Oxidizer composition entries like O2:0.7 or O2 (implies O2:1.0)')
    parser.add_argument("--reactants", type=str, nargs='+', required=False,
                        help='Reactants composition entries like O2:0.7,CH4:0.6')
    parser.add_argument("--fuel-T", type=float, default=300.0, help="Fuel temperature in K")
    parser.add_argument("--oxidizer-T", type=float, default=300.0, help="Oxidizer temperature in K")
    parser.add_argument("--temperature", type=float, default=300.0, help="Reactants temperature in K")
    parser.add_argument("--pressure", type=float, default=None, help="Pressure in Pa")
    parser.add_argument("--mixture-ratio", type=float, default=None, help="Mixture ratio (fuel/oxidizer mass)")
    return parser.parse_args()
