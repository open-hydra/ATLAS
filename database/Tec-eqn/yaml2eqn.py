
import cantera as ct
import argparse
import os, sys
masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + '/database/'
ct.add_directory(datapath+'Chemistry')

def write_eqn_file(yaml_file, phase_name=None):
    try:
        sol = ct.Solution(yaml_file, name=phase_name) if phase_name else ct.Solution(yaml_file)
    except Exception as e:
        print(f"Failed to load {yaml_file}: {e}")
        return

    phase_name = sol.name or os.path.splitext(os.path.basename(yaml_file))[0]
    species = sol.species_names
    ns = len(species)

    output_file = f"{phase_name}.eqn"
    with open(output_file, "w") as f:
        f.write("#!MC 1410\n")
        # rho definition
        v_indices = [f"v{i}" for i in range(4, 4 + ns)]
        f.write('$!AlterData \n')
        f.write(f"Equation = '{{rho}}=" + "+".join(v_indices) + "'\n")

        # mass fractions
        for idx, sp in enumerate(species):
            v_num = idx + 4
            f.write('$!AlterData \n')
            f.write(f"Equation = '{{y{sp}}}=v{v_num}/{{rho}}'\n")

    print(f"✓ Wrote '{output_file}' with {ns} species from '{yaml_file}'")

def process_directory(directory, phase_name=None):
    for filename in os.listdir(directory):
        if filename.endswith(".yaml"):
            filepath = os.path.join(directory, filename)
            write_eqn_file(filepath, phase_name)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate equation files from Cantera YAML files.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--file", "-f", help="Path to a single Cantera YAML file.")
    group.add_argument("--dir", "-d", help="Path to a directory containing YAML files.")

    parser.add_argument("--phase", "-p", help="Optional: name of the phase (if needed).")

    args = parser.parse_args()

    if args.file:
        write_eqn_file(args.file, args.phase)
    elif args.dir:
        process_directory(args.dir, args.phase)
