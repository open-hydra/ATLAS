import cantera as ct
import os
import sys

masterpath = os.environ.get("ATLASDIR")
if masterpath is None:
    print("ATLAS environment variable is not set.")
    sys.exit(1)
datapath = masterpath + "/database/"
ct.add_directory(datapath + "thermo")
ct.add_directory(datapath + "chemistry")


def update_thermo_model(old_phase_name, model):
    """Return a Cantera Solution identical to *old_phase_name* but with thermo
    data replaced by NASA9 polynomials for any species found in nasa9.yaml.

    Parameters
    ----------
    old_phase_name : str
        YAML file name of the original mechanism (e.g. ``'FFCM2.yaml'``).
    model : str or None
        Thermo model identifier.  Currently ``'NASA9'`` triggers the replacement;
        any other value returns the original phase unchanged.

    Returns
    -------
    ct.Solution
    """
    old_phase = ct.Solution(old_phase_name)

    if model == "NASA9":
        nasa9_species_list = ct.Species.list_from_file("nasa9.yaml")
        nasa9_thermo = {sp.name: sp.thermo for sp in nasa9_species_list}

        new_species_list = []
        for species in old_phase.species():
            thermo = nasa9_thermo.get(species.name, species.thermo)
            transport = species.transport

            new_sp = ct.Species(name=species.name, composition=species.composition)
            new_sp.thermo = thermo
            new_sp.transport = transport
            new_species_list.append(new_sp)

        return ct.Solution(
            thermo="ideal-gas",
            species=new_species_list,
            reactions=old_phase.reactions(),
        )

    return old_phase


def add_species(species_name, old_phase, source):
    """Return a new Cantera Solution with *species_name* appended (if missing).

    Parameters
    ----------
    species_name : str
        Name of the species to add, e.g. ``'N2'``.
    old_phase : ct.Solution
        Existing Cantera Solution to extend.
    source : str
        Base name (without ``.yaml``) of the database file to look up the
        species in, e.g. ``'nasa9'``.

    Returns
    -------
    ct.Solution
    """
    original_species = old_phase.species()
    new_species = original_species.copy()

    if species_name not in old_phase.species_names:
        nasa_gas = ct.Species.list_from_file(source + ".yaml")
        species = next((sp for sp in nasa_gas if sp.name == species_name), None)
        if species:
            new_species.append(species)

    new_phase = ct.Solution(
        thermo="ideal-gas",
        kinetics="gas",
        species=new_species,
        reactions=old_phase.reactions(),
    )
    new_phase.name = old_phase.name
    return new_phase


def extract(models, solutions):
    """Extract adiabatic flame temperatures from a dict of equilibrium solutions.

    Parameters
    ----------
    models : list[str]
        Ordered list of mechanism names.
    solutions : dict[str, list[ct.Solution]]
        Keyed by model name; each value is an ordered list of equilibrated
        Cantera Solution objects.

    Returns
    -------
    dict[str, list[float]]
        ``Ta[model]`` is a list of temperatures (K) in the same order as
        ``solutions[model]``.
    """
    Ta = {}
    for model in models:
        Ta[model] = [sol.T for sol in solutions[model]]
    return Ta


def setup_mixture(gas, fuel_comp, oxi_comp, mr):
    """Set *gas* mass fractions according to *fuel_comp*, *oxi_comp*, and *mr*.

    Parameters
    ----------
    gas : ct.Solution
        Cantera gas object whose ``Y`` attribute will be set in-place.
    fuel_comp : dict[str, float]
        Fuel species mass fractions (need not sum to 1; will be normalised).
    oxi_comp : dict[str, float]
        Oxidiser species mass fractions (need not sum to 1; will be normalised).
    mr : float
        Oxidiser-to-fuel mass ratio (O/F).  Use ``0`` for pure oxidiser.
    """
    total_fuel = sum(fuel_comp.values())
    total_oxi = sum(oxi_comp.values())

    if mr == 0:
        total_fuel = total_fuel + total_oxi
        total_oxi = total_fuel

    norm_fuel = {sp: frac / total_fuel for sp, frac in fuel_comp.items()}
    norm_oxi = {sp: frac / total_oxi for sp, frac in oxi_comp.items()}

    combined: dict[str, float] = {}
    for sp, frac in norm_fuel.items():
        combined[sp] = frac / (1 + mr)
    for sp, frac in norm_oxi.items():
        if sp in combined:
            combined[sp] += frac if mr == 0 else frac * mr / (1 + mr)
        else:
            combined[sp] = frac if mr == 0 else frac * mr / (1 + mr)

    gas.Y = combined
