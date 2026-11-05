"""What the ATLAS database holds, for the pickers in the GPB panel.

The lists come from the repository itself (``database/chemistry/*.yaml``,
``database/thermo/*.yaml``) and from the case directory, so a picker always
offers what GPB will actually be able to load.  Everything is read lazily and
cached: the thermo files are ~1 MB each and are only scanned when the user
opens a species picker.
"""

from __future__ import annotations

import glob
import importlib.util
import os
import re

from .gpbmodel import ATLAS_ROOT, family_of

DATABASE_DIR = os.path.join(ATLAS_ROOT, "database")
CHEMISTRY_DIR = os.path.join(DATABASE_DIR, "chemistry")
THERMO_DIR = os.path.join(DATABASE_DIR, "thermo")

# The file GPB loads for each database, by phase family (gas, or the condensed
# and solid phases, which GPB builds alike).  NASA9 and Burcat are in
# database/thermo; NASA7 is not: GPB takes Cantera's own nasa_gas.yaml
# (src/GPB/ideal_gas/builder.py) or nasa_condensed.yaml
# (src/GPB/condensed/builder.py) from Cantera's data directory.
THERMO_FILES = {
    "NASA9": "nasa9.yaml",
    "Burcat": "burcat.yaml",
}
NASA7_FILES = {"gas": "nasa_gas.yaml", "condensed": "nasa_condensed.yaml"}
# The SP-database is code, not a species file: its materials are the names
# compute_properties_from_database() branches on.
SP_FILE = os.path.join(THERMO_DIR, "sp_custom.py")

# The databases tag a condensed entry with a parenthesised state -- H2O(L),
# AL(cr), Fe(a), ZrO2(II), CaO(S), Hg(liq)REF -- and leave a gas untagged, or
# tag it (g)/(G)/(gas) where the formula also exists condensed.  Groups such
# as C3H2(3) or CH2(NO2)2 belong to a gas formula and are none of these.
LIQUID_TAGS = {"L", "liq"}
SOLID_TAGS = {
    "cr", "crI", "crII", "s", "S", "gr", "GR", "an", "a", "a'", "b", "c", "d",
    "I", "I'", "II", "II-r", "III", "III,II", "IV", "V", "I-y",
    "a-qz", "b-qz", "b-crt",
}

# The states a phase of each type is made of: gaseous species for a gas, the
# liquids and solids a dispersed phase carries, solids for a wall.  An entry
# the database lists as condensed without saying which ("condensed": RP-1 and
# ABS in NASA9) goes with any condensed phase.
PHASE_STATES = {
    "condensed-dispersed": ("liquid", "solid", "condensed"),
    "liquid-dispersed": ("liquid", "condensed"),
    "solid-dispersed": ("solid", "condensed"),
    "solid": ("solid", "condensed"),
    "solid-bulk": ("solid", "condensed"),
}
GAS_STATES = ("gas",)

_state_cache = {}
_mech_species_cache = {}


def _stems(pattern):
    return sorted({os.path.splitext(os.path.basename(p))[0]
                   for p in glob.glob(pattern)})


def mechanism_files(case_dir=None):
    """Mechanism / phase file stems GPB can load, database first."""
    names = _stems(os.path.join(CHEMISTRY_DIR, "*.yaml"))
    local = _stems(os.path.join(case_dir or ".", "*.yaml"))
    return names, [n for n in local if n not in names]


def cea_files(case_dir=None):
    directory = case_dir or "."
    return sorted(os.path.basename(p)
                  for p in glob.glob(os.path.join(directory, "*.inp")))


def _cantera_data_dirs():
    """Cantera's data directories, found without importing Cantera (slow, and
    perhaps not in the GUI's environment): the installed package first, then
    the conda environments ATLAS.sh activates for GPB."""
    dirs = []
    try:
        spec = importlib.util.find_spec("cantera")
    except (ImportError, ValueError):
        spec = None
    for location in (spec.submodule_search_locations or []) if spec else []:
        dirs.append(os.path.join(location, "data"))
    env = os.environ.get("ATLAS_CONDA_ENV", "ct-env")
    for prefix in (os.environ.get("CONDA_PREFIX"),
                   os.path.expanduser(os.path.join("~", ".conda", "envs", env))):
        if prefix:
            dirs += sorted(glob.glob(os.path.join(
                prefix, "lib", "python3*", "site-packages", "cantera", "data")))
    return [d for d in dirs if os.path.isdir(d)]


def thermo_file(name, family="gas"):
    """Path of the file GPB loads for database *name* in a phase of *family*,
    or None when it cannot be found."""
    if name == "NASA7":
        filename = NASA7_FILES["gas" if family == "gas" else "condensed"]
        for directory in _cantera_data_dirs():
            path = os.path.join(directory, filename)
            if os.path.isfile(path):
                return path
        return None
    path = os.path.join(THERMO_DIR, THERMO_FILES.get(name, ""))
    return path if os.path.isfile(path) else None


def phase_states(phase_type):
    """The states (gas, liquid, solid, condensed) a phase of *phase_type* takes."""
    return PHASE_STATES.get((phase_type or "").strip(), GAS_STATES)


def describe_states(phase_type):
    """What the picker of a *phase_type* phase lists, in words."""
    states = phase_states(phase_type)
    if states == GAS_STATES:
        return "gaseous species"
    if "liquid" in states and "solid" in states:
        return "liquid and solid materials"
    return "liquid materials" if "liquid" in states else "solid materials"


def species_state(name):
    """``"liquid"`` or ``"solid"`` from the state tag of *name*, ``""`` when
    it carries none."""
    for tag in re.findall(r"\(([^()]*)\)", name):
        if tag in LIQUID_TAGS:
            return "liquid"
        if tag in SOLID_TAGS:
            return "solid"
    return ""


def _scan_states(path, untagged):
    """``[(name, state), ...]`` of a species file.

    *untagged* is the state of an entry with no tag: ``"gas"``,
    ``"condensed"`` (a file of condensed species only), or ``"ordered"`` for
    the NASA Glenn file, whose header lists the gases first and the condensed
    species after them -- an untagged entry past the first condensed one is
    condensed.
    """
    entries = []
    pattern = re.compile(r"^\s*-\s*name:\s*(\S+)")
    past_gases = False
    with open(path, errors="ignore") as handle:
        for line in handle:
            match = pattern.match(line)
            if not match:
                continue
            name = match.group(1).strip().strip("'\"")
            state = species_state(name)
            if state:
                past_gases = True
            elif untagged == "ordered":
                state = "condensed" if past_gases else "gas"
            else:
                state = untagged
            entries.append((name, state))
    return entries


def _sp_materials():
    """The materials of the SP-database, in the order sp_custom.py lists them."""
    try:
        with open(SP_FILE, errors="ignore") as handle:
            text = handle.read()
    except OSError:
        return []
    names = re.findall(r"""\bname\s*==\s*['"]([^'"]+)['"]""", text)
    return list(dict.fromkeys(names))


def database_states(name, family="gas"):
    """``[(species, state), ...]`` held by database *name* for a phase of
    *family* (cached: the files are ~1 MB scans)."""
    family = "gas" if family == "gas" else "condensed"
    key = (name, family)
    if key in _state_cache:
        return _state_cache[key]
    entries = []
    if name == "SP-database":
        # Custom property laws of solids (fuels, cladding, graphite).
        entries = [(n, "solid") for n in _sp_materials()]
    else:
        path = thermo_file(name, family)
        if path:
            untagged = {"NASA9": "ordered", "NASA7": family}.get(name, "gas")
            entries = _scan_states(path, untagged)
    _state_cache[key] = entries
    return entries


def species_of_database(name, phase_type="ideal-gas"):
    """Names of database *name* a phase of *phase_type* can be made of: the
    gases for a gas phase, the liquids and/or solids for a condensed one."""
    states = phase_states(phase_type)
    return [species for species, state
            in database_states(name, family_of(phase_type))
            if state in states]


def species_of_mechanism(stem, case_dir=None):
    """Species listed by a mechanism/phase yaml, without loading Cantera."""
    key = (stem, case_dir)
    if key in _mech_species_cache:
        return _mech_species_cache[key]
    path = None
    for candidate in (os.path.join(case_dir or ".", stem + ".yaml"),
                      os.path.join(CHEMISTRY_DIR, stem + ".yaml")):
        if os.path.isfile(candidate):
            path = candidate
            break
    species = []
    if path:
        text = open(path, errors="ignore").read()
        # The phase block lists them as "species: [A, B, C]", possibly wrapped.
        match = re.search(r"\n\s*species:\s*\[(.*?)\]", text, re.S)
        if match:
            species = [s.strip().strip("'\"")
                       for s in match.group(1).replace("\n", " ").split(",")
                       if s.strip()]
        if not species:
            species = re.findall(r"^\s*-\s*name:\s*(\S+)", text, re.M)
            species = [s.strip().strip("'\"") for s in species]
    _mech_species_cache[key] = species
    return species


# A short, safe list for the real-fluid picker when CoolProp is not importable.
COMMON_FLUIDS = [
    "Water", "CO2", "Nitrogen", "Oxygen", "Hydrogen", "Methane", "Ethanol",
    "Air", "Helium", "Argon", "Ammonia", "R134a", "n-Dodecane", "n-Heptane",
]


def coolprop_fluids():
    """Every fluid CoolProp knows, or a short common list without CoolProp."""
    try:
        from CoolProp.CoolProp import FluidsList
        return sorted(FluidsList())
    except Exception:
        return list(COMMON_FLUIDS)
