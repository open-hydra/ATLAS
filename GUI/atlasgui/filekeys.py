"""Which INI keys carry a file, and how the GUI resolves one.

ATLAS reads a surprising number of files *through* the INI: a wall temperature
can be a table, an inlet can be a time series, a phase can be a Cantera
mechanism, a boundary can take its composition from a CEA deck.  Every one of
those is a key whose value is a path, and the GUI has no business making the
user type it.  This module is the single place that knows

* which keys of which section take a file (:func:`role_of`),
* what kind of thing the key names -- a file, a directory, or a *stem* that a
  tool resolves against its own search path (:class:`FileRole`),
* how a chosen path becomes the value to store (:func:`value_for`), and
* whether a stored value still resolves (:func:`status`).

The catalogue covers every tool, not only the ones the GUI edits today: the
rules come from the generated references under ``docs/user-guide/*/``, which
are written from the tools' own registries, so a key added there shows up here
as soon as this list is extended.

The module is deliberately Qt-free so it can be checked headlessly.
"""

from __future__ import annotations

import glob
import os
from dataclasses import dataclass

from .gpbmodel import ATLAS_ROOT

CHEMISTRY_DIR = os.path.join(ATLAS_ROOT, "database", "chemistry")

# ------------------------------------------------------------------- filters
TABLE = ("Data tables (*.dat *.txt *.csv)", "All files (*)")
FIELD = ("Field files (*.tec *.szplt *.plt *.dat *.txt)", "All files (*)")
TECPLOT = ("Tecplot files (*.tec *.szplt *.plt)", "All files (*)")
CEA = ("CEA input decks (*.inp)", "All files (*)")
INI = ("INI files (*.ini)", "All files (*)")
YAML = ("Cantera files (*.yaml *.yml)", "All files (*)")
MESH = ("Mesh / field files (*.tec *.szplt *.p3d *.plt)", "All files (*)")
ANY = ("All files (*)",)

# What a key names.
FILE = "file"            # a path to a file, read as written
DIR = "dir"              # a directory
STEM = "stem"            # a file name without its extension, found on a search path
PREFIX = "prefix"        # a directory or a file-name prefix

#: Keys of the five BCB time-series families: the BC record keeps 32 characters
#: of the name, so BCB refuses a longer value instead of truncating it.
NAME_LIMIT = 32


@dataclass(frozen=True)
class FileRole:
    """What a key names, and what a chooser for it should offer."""

    label: str                       # short wording for a dialog row
    kind: str = FILE
    filters: tuple = ANY
    hint: str = ""
    extensions: tuple = ()           # appended to a stem when looking for it
    search: tuple = ()               # extra directories the tool searches
    keywords: tuple = ()             # values that are names, not paths
    max_len: int = 0                 # refused above this many characters
    local: bool = True               # the tool reads it from the case directory

    def describes_file(self):
        return self.kind in (FILE, STEM)


# --------------------------------------------------------------- BCB section
#: Every variable BCB can take from a table, as ``<name>-file``
#: (``src/BCB/config.f90``, ``variable_file_keys``).
VARYING = ("ks", "q", "T", "Tref", "hconv", "qrad", "eps", "alpha", "beta",
           "g", "krho", "a", "n", "pRef", "rhoGrain", "Taf", "SFgeo", "SF",
           "mach", "p")

#: The time-series keys, with their 32-character limit.
TIME_SERIES = {
    "time-file": "full boundary state over time",
    "p0-time-file": "total pressure over time",
    "p-time-file": "static pressure over time",
    "q-time-file": "wall heat flux over time",
    "T-time-file": "wall temperature over time",
}

_BC_KEYS = {}
for _name in VARYING:
    _BC_KEYS[f"{_name}-file"] = FileRole(
        label=f"varying {_name}",
        filters=TABLE,
        hint=f"ASCII table of {_name} along file-direction "
             "(one 'coordinate value' pair per row, monotone coordinate).")
for _key, _what in TIME_SERIES.items():
    _BC_KEYS[_key] = FileRole(
        label=_what, filters=TABLE, max_len=NAME_LIMIT,
        hint="Two columns, time [s] and the value. The BC record keeps 32 "
             "characters of the name, so keep the file in the case directory.")
_BC_KEYS.update({
    "line-file": FileRole(
        label="unwrapped time record", filters=TECPLOT,
        hint="2-D record mapped around the face; BCB writes the time-file "
             "itself, so this name may be longer than 32 characters."),
    "range-file": FileRole(
        label="injector plate patches", filters=TABLE,
        hint="Patch table of the plate, used with inner-patch / outer-patch."),
    "eq-CEA-file": FileRole(
        label="CEA equilibrium deck", filters=CEA,
        hint="CEA input deck whose equilibrium gives the composition; "
             "eq-CEA-section picks the case inside it."),
    "distribution": FileRole(
        label="size distribution", filters=TABLE,
        keywords=("Normal", "Rosin-Rammler", "uniform"),
        hint="A built-in law (Normal) or a table of the size distribution."),
})

# ---------------------------------------------------------- global parameters
_PARAM_KEYS = {
    "BCB-file": FileRole(label="BCB deck", filters=INI,
                         hint="INI file holding the BCB blocks and boundaries "
                              "(default: this file)."),
    "ICB-file": FileRole(label="ICB deck", filters=INI,
                         hint="INI file holding the ICB blocks "
                              "(default: this file)."),
    "input-file": FileRole(label="GPB deck", filters=INI,
                           hint="INI file GPB reads (default: input.ini)."),
}

# ---------------------------------------------------------------- GPB phase
_GPB_KEYS = {
    "reactions": FileRole(
        label="reaction mechanism", kind=STEM, filters=YAML,
        extensions=(".yaml",), search=(CHEMISTRY_DIR,),
        hint="Cantera mechanism, named without .yaml. GPB looks for it in the "
             "case directory and in database/chemistry."),
    "phase": FileRole(
        label="Cantera phase file", kind=STEM, filters=YAML,
        extensions=(".yaml",), search=(CHEMISTRY_DIR,),
        hint="Existing phase file, named without .yaml -- the file name, which "
             "may differ from the phase name inside it."),
    "CEA-file": FileRole(
        label="CEA input deck", filters=CEA, extensions=("", ".inp"),
        hint="CEA deck of the reactants; the .inp extension is optional."),
}

# --------------------------------------------------------------- ICB section
_ICB_KEYS = {
    "old-solution": FileRole(
        label="previous solution", filters=TECPLOT,
        hint="Field the initial condition is interpolated from."),
    "old-species": FileRole(
        label="species of the old solution", kind=PREFIX, filters=ANY,
        hint="A directory (old/) or a file prefix (old-) locating the "
             "<phase>phase.txt of the old solution."),
    "eq-CEA-file": _BC_KEYS["eq-CEA-file"],
}
# the values ICB reads from a profile (ICB-IG, ICB-RF, ICB-SP of its input
# reference): u, v, w take none
for _name in ("mach", "p0", "T0", "p", "T", "rho", "h", "vel"):
    _ICB_KEYS[f"{_name}-file"] = FileRole(
        label=f"{_name} profile", filters=FIELD,
        hint=f"A two-column table (coordinate, {_name}) along {_name}-direction, "
             f"or a Tecplot field (.tec, .szplt) with {_name} cell-centred.")
_ICB_SPECIES_PROFILE = FileRole(
    label="mass-fraction profile", filters=FIELD,
    hint="A two-column table (coordinate, y) along y<species>-direction, or a "
         "Tecplot field (.tec, .szplt) with y cell-centred.")

# ----------------------------------------------------------- the other tools
_STB_KEYS = {
    "qvol-file": FileRole(label="volumetric source", filters=FIELD,
                          hint="1-D profile or 3-D field of the source term."),
}

_MDB_KEYS = {
    "grid": FileRole(label="grid to split", filters=MESH,
                     hint="Grid (or grid and solution) file MDB decomposes."),
    "grid-out": FileRole(label="decomposed grid", filters=MESH, local=False,
                         hint="Where the split grid is written."),
    "bc-path": FileRole(label="BC directory", kind=DIR,
                        hint="Directory holding bc.txt, bc2.txt, ..."),
    "bc-out-path": FileRole(label="split BC directory", kind=DIR, local=False,
                            hint="Directory the split BC files are written to."),
    "map-file": FileRole(label="decomposition record", filters=ANY, local=False,
                         hint="Where the decomposition map is written."),
}

#: ``context -> {key: role}``.  A context is a kind of section, not a tool:
#: the same ``[name]`` BC section is written by BCB and read by the solvers.
CONTEXTS = {
    "bc-section": _BC_KEYS,
    "atlas-parameters": _PARAM_KEYS,
    "gpb-phase": _GPB_KEYS,
    "icb-section": _ICB_KEYS,
    "stb": _STB_KEYS,
    "mdb": _MDB_KEYS,
}

#: Suffix rules, applied when no exact key matches.  They catch the phase-
#: prefixed spellings (``drop-krho-file``, ``partL-distribution``) and any
#: ``<var>-file`` a tool grows later.
_SUFFIX_RULES = (
    ("-time-file", FileRole(label="time series", filters=TABLE,
                            max_len=NAME_LIMIT,
                            hint="Two columns: time [s] and the value.")),
    ("-distribution", _BC_KEYS["distribution"]),
    ("-file", FileRole(label="data file", filters=FIELD,
                       hint="File this key takes its values from.")),
    ("-path", FileRole(label="directory", kind=DIR)),
)


def role_of(key, context="bc-section"):
    """The :class:`FileRole` of *key*, or ``None`` when it takes no file."""
    key = (key or "").strip()
    if not key:
        return None
    table = CONTEXTS.get(context, {})
    if key in table:
        return table[key]
    if context == "icb-section" and key.startswith("y") and key.endswith("-file") \
            and len(key) > len("y-file"):
        return _ICB_SPECIES_PROFILE
    for suffix, role in _SUFFIX_RULES:
        if key.endswith(suffix) and len(key) > len(suffix):
            # a phase-prefixed spelling keeps the wording of the bare key
            bare = key[key.index("-") + 1:] if context == "bc-section" else ""
            return table.get(bare, role)
    return None


def is_file_key(key, context="bc-section"):
    return role_of(key, context) is not None


def file_keys(context="bc-section", keys=None):
    """``[(key, role)]`` for *keys* (default: every key of the context)."""
    table = CONTEXTS.get(context, {})
    if keys is None:
        keys = [k for k in table if k != "distribution"]
    out = []
    for key in keys:
        role = role_of(key, context)
        if role is not None:
            out.append((key, role))
    return out


# ------------------------------------------------------------------ resolving
def candidates(value, case_dir, role):
    """Every path *value* could mean, in the order the tool would try them."""
    value = (value or "").strip()
    if not value:
        return []
    case_dir = case_dir or os.getcwd()
    stems = [value]
    if role.kind == STEM or role.extensions:
        stems = [value + ext for ext in (role.extensions or ("",))]
        if role.kind != STEM and value not in stems:
            stems.insert(0, value)
    out = []
    for stem in stems:
        if os.path.isabs(stem):
            out.append(stem)
            continue
        out.append(os.path.join(case_dir, stem))
        for directory in role.search:
            out.append(os.path.join(directory, stem))
    return out


def status(value, case_dir, role):
    """``(state, path, message)`` for a stored value.

    *state* is ``empty``, ``keyword``, ``found``, ``missing`` or ``too-long``;
    *path* the file that was found, when one was.
    """
    value = (value or "").strip()
    if not value:
        return "empty", "", ""
    if value in role.keywords or value.lower() in [k.lower() for k in role.keywords]:
        return "keyword", "", f"{value}: a built-in law, not a file"
    if role.max_len and len(value) > role.max_len:
        return "too-long", "", (
            f"{len(value)} characters: the BC record keeps {role.max_len}, so "
            "BCB refuses this name. Shorten it or move the file into the case "
            "directory.")
    if role.kind == DIR:
        path = value if os.path.isabs(value) else os.path.join(
            case_dir or os.getcwd(), value)
        if os.path.isdir(path):
            return "found", path, path
        return "missing", "", f"no directory {value}"
    if role.kind == PREFIX:
        base = value if os.path.isabs(value) else os.path.join(
            case_dir or os.getcwd(), value)
        if os.path.isdir(base) or glob.glob(base + "*phase.txt"):
            return "found", base, base
        return "missing", "", f"nothing found for {value}"
    for path in candidates(value, case_dir, role):
        if os.path.isfile(path):
            return "found", path, path
    where = "the case directory"
    if role.search:
        where += " or " + ", ".join(
            os.path.relpath(d, ATLAS_ROOT) for d in role.search)
    return "missing", "", f"{value} not found in {where}"


def value_for(path, case_dir, role):
    """The value to store in the INI for a chosen *path*.

    Relative to the case directory whenever the file is inside it (the tools
    run there and the solvers read some of these names verbatim), the stem
    alone for a key that takes one.
    """
    path = os.path.abspath(path)
    case_dir = os.path.abspath(case_dir or os.getcwd())
    try:
        inside = os.path.commonpath([path, case_dir]) == case_dir
    except ValueError:                        # different drives / roots
        inside = False
    value = os.path.relpath(path, case_dir) if inside else path
    if role.kind == STEM:
        # A stem may carry a directory the tool resolves from the case
        # directory (phase = local/JLqua); one found on the search path is
        # named on its own, since that is where the tool looks for it.
        value = os.path.splitext(value if inside else os.path.basename(path))[0]
    return value


def in_search_path(path, case_dir, role):
    """True when the tool will find *path* where it is.

    A stem is resolved against the case directory and the tool's own search
    path, so a file anywhere *under* the case directory is reachable (the stem
    then carries the subdirectory), while elsewhere only the search
    directories themselves are.
    """
    if role.kind != STEM:
        return True            # a plain path may point anywhere that is readable
    path = os.path.abspath(path)
    case_dir = os.path.abspath(case_dir or os.getcwd())
    try:
        if os.path.commonpath([path, case_dir]) == case_dir:
            return True
    except ValueError:
        pass
    return os.path.dirname(path) in [os.path.abspath(d) for d in role.search]
