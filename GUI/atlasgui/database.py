"""What the ATLAS database holds, for the pickers in the GPB panel.

The lists come from the repository itself (``database/chemistry/*.yaml``,
``database/thermo/*.yaml``) and from the case directory, so a picker always
offers what GPB will actually be able to load.  Everything is read lazily and
cached: the thermo files are ~1 MB each and are only scanned when the user
opens a species picker.
"""

from __future__ import annotations

import glob
import os
import re

from .gpbmodel import ATLAS_ROOT

DATABASE_DIR = os.path.join(ATLAS_ROOT, "database")
CHEMISTRY_DIR = os.path.join(DATABASE_DIR, "chemistry")
THERMO_DIR = os.path.join(DATABASE_DIR, "thermo")

THERMO_FILES = {
    "NASA9": "nasa9.yaml",
    "Burcat": "burcat.yaml",
    "NASA7": "nasa_condensed.yaml",
}

_species_cache = {}
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


def species_of_database(name):
    """Species names held by a thermo database (cached, ~1 MB scan)."""
    if name in _species_cache:
        return _species_cache[name]
    path = os.path.join(THERMO_DIR, THERMO_FILES.get(name, ""))
    species = []
    if os.path.isfile(path):
        pattern = re.compile(r"^\s*-\s*name:\s*(\S+)")
        with open(path, errors="ignore") as handle:
            for line in handle:
                match = pattern.match(line)
                if match:
                    species.append(match.group(1).strip().strip("'\""))
    _species_cache[name] = species
    return species


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
