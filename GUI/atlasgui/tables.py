"""The property tables GPB wrote, read back for the Phases stage.

GPB writes the tables of a phase named ``gas`` into ``fromATLAStoSolver/`` as
``gas-<table>`` (an unnamed phase: ``<table>``):

* ``phase.txt`` -- the kind of the phase on its first line (``ideal-gas
  phase``, ``condensed-dispersed``, ``solid-bulk``, ``real-fluid phase``),
  then its species and their molar masses, its materials and their
  populations, or its fluid;
* an ideal gas: ``thermo.dat`` (cp, h, s, dcp/dT of every species against T,
  one zone per species, or one ``mix`` zone for a heavy gas),
  ``transport.dat`` (viscosity, conductivity), ``diffusion.dat`` (the binary
  coefficient of every pair, at the reference pressure its title gives),
  ``chemistry-Arrhenius.dat`` (kf, kb of the reactions that are not fall-off),
  ``chemistry-Troe.dat`` and ``chemistry-Lindemann.dat`` (the fall-off ones),
  ``chemistry-info.txt`` (the reactions, read for their equations);
* a condensed or a solid phase: ``properties.dat``, one zone per material;
* a real fluid: ``thermo.dat`` and ``transport.dat`` on a grid of pressure
  (I, fastest) and enthalpy (J), the enthalpy and the entropy taken from 0 at
  (Tmin, pmin).

They are ASCII Tecplot: the 1-D tables ``F=POINT``, the real-fluid grids
``DATAPACKING=BLOCK``.  :func:`phase_outputs` finds the phases written,
:func:`sheets` what can be drawn of one -- curves against T (``xy``) or a map
over (p, h) (``map``) -- and :func:`load_sheet` reads one.  No Qt here.
"""

from __future__ import annotations

import glob
import os
import re
from collections import OrderedDict
from dataclasses import dataclass, field

import numpy as np

OUTPUT_DIR = "fromATLAStoSolver"
INFINITE = 1e299            # GPB writes an infinite rate as 1e300

# the first word of phase.txt -> the family of the phase (as the Phases stage has them)
FAMILIES = {"ideal-gas": "gas", "condensed-dispersed": "condensed",
            "liquid-dispersed": "condensed", "solid-dispersed": "condensed",
            "solid-bulk": "solid", "solid": "solid", "real-fluid": "real-fluid",
            "real-gas": "real-fluid"}
FAMILY_LABELS = {"gas": "ideal gas", "condensed": "dispersed phase", "solid": "solid",
                 "real-fluid": "real fluid", "": "phase"}

# the tables of a phase: file suffix -> role
ROLES = OrderedDict([
    ("phase.txt", "phase"), ("thermo.dat", "thermo"), ("transport.dat", "transport"),
    ("diffusion.dat", "diffusion"), ("chemistry-Arrhenius.dat", "arrhenius"),
    ("chemistry-Troe.dat", "troe"), ("chemistry-Lindemann.dat", "lindemann"),
    ("chemistry-info.txt", "reactions"), ("composition.txt", "composition"),
    ("properties.dat", "properties"),
])

# label and unit of a column, by its name in the file
VARIABLES = {
    "Temperature": ("T · temperature", "K"),
    "Pressure": ("p · pressure", "Pa"),
    "Cp": ("cp · specific heat", "J/(kg·K)"),
    "Enthalpy": ("h · enthalpy", "J/kg"),
    "Enthalpy_abs": ("h · enthalpy, formation included", "J/kg"),
    "Entropy": ("s · entropy", "J/(kg·K)"),
    "dCp": ("dcp/dT", "J/(kg·K²)"),
    "Viscosity": ("μ · viscosity", "Pa·s"),
    "Conductivity": ("λ · conductivity", "W/(m·K)"),
    "Dij": ("D · binary diffusion", "m²/s"),
    "kf": ("kf · forward rate constant", ""),
    "kb": ("kb · backward rate constant", ""),
    "k_inf": ("k∞ · high-pressure rate", ""),
    "k_0": ("k₀ · low-pressure rate", ""),
    "k_c": ("Kc · equilibrium constant", ""),
    "F_cent": ("Fcent · Troe broadening", "–"),
    "Density": ("ρ · density", "kg/m³"),
    "Energy": ("e · energy per volume", "J/m³"),
    "Psat": ("psat · vapour pressure", "Pa"),
    "SoundSpeed": ("a · speed of sound", "m/s"),
    "dRho/dT": ("∂ρ/∂T at constant p", "kg/(m³·K)"),
    "dRho/dh": ("∂ρ/∂h at constant p", "kg·s²/m⁵"),
    "dRho/dp": ("∂ρ/∂p at constant h", "s²/m²"),
}

SHEET_LABELS = {"thermo": "Thermodynamics and transport", "diffusion": "Binary diffusion",
                "arrhenius": "Reaction rates", "troe": "Fall-off rates · Troe",
                "lindemann": "Fall-off rates · Lindemann", "properties": "Properties",
                "grid": "Property grid"}
# sheets whose values span decades: drawn on a logarithmic scale at first
LOG_SHEETS = ("diffusion", "arrhenius", "troe", "lindemann")


def describe(name):
    """``(label, unit)`` of column *name*."""
    return VARIABLES.get(name, (name, ""))


class TableError(ValueError):
    """A file that is not a table GPB writes, said in one sentence."""


# ----------------------------------------------------------------- phases
@dataclass
class PhaseOutput:
    """The tables GPB wrote for one phase."""
    name: str                      # "" for an unnamed phase
    family: str                    # gas, condensed, solid, real-fluid ("" when unknown)
    directory: str
    header: str = ""               # the first line of phase.txt
    members: list = field(default_factory=list)    # species, materials or the fluid
    files: OrderedDict = field(default_factory=OrderedDict)      # role -> path

    @property
    def prefix(self):
        return f"{self.name}-" if self.name else ""

    @property
    def label(self):
        return f"{self.name or '(unnamed)'} · {FAMILY_LABELS.get(self.family, 'phase')}"

    def mtime(self):
        """When GPB last wrote a table of the phase."""
        times = []
        for path in self.files.values():
            try:
                times.append(os.path.getmtime(path))
            except OSError:
                pass
        return max(times) if times else 0.0


def output_dir(case_dir):
    """Where the tools' files of *case_dir* are: its ``fromATLAStoSolver/``,
    or the folder itself when it has none (a set of files copied from a
    run)."""
    out = os.path.join(case_dir, OUTPUT_DIR)
    return out if os.path.isdir(out) else case_dir


def read_phase_file(path):
    """``(family, header, members)`` of a ``phase.txt``."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.split() for line in handle if line.strip()]
    except OSError:
        return "", "", []
    if not lines:
        return "", "", []
    header = " ".join(lines[0])
    family = FAMILIES.get(lines[0][0].lower(), "")
    return family, header, [tokens[0] for tokens in lines[1:]]


def phase_outputs(case_dir):
    """The phases whose tables are in the case: the ones GPB wrote into
    ``fromATLAStoSolver/``, then any other the case folder holds (phase
    files given to BCB and ICB by hand)."""
    found = OrderedDict()
    places = [output_dir(case_dir)]
    if os.path.abspath(places[0]) != os.path.abspath(case_dir):
        places.append(case_dir)
    for directory in places:
        for path in sorted(glob.glob(os.path.join(directory, "*phase.txt"))):
            stem = os.path.basename(path)[:-len("phase.txt")]
            if stem and not stem.endswith("-"):
                continue                       # not a GPB name (<name>-phase.txt or phase.txt)
            name = stem[:-1]
            if name in found:
                continue
            family, header, members = read_phase_file(path)
            phase = PhaseOutput(name, family, directory, header, members)
            for suffix, role in ROLES.items():
                candidate = os.path.join(directory, stem + suffix)
                if os.path.isfile(candidate):
                    phase.files[role] = candidate
            found[name] = phase
    return list(found.values())


# ----------------------------------------------------------------- tables
@dataclass
class Zone:
    """One zone: ``shape`` is ``(I,)`` or ``(I, J)``, ``data[variable]`` an
    array of that shape (I fastest in the file)."""
    name: str
    shape: tuple
    data: OrderedDict = field(default_factory=OrderedDict)


@dataclass
class Table:
    path: str
    title: str = ""
    variables: list = field(default_factory=list)
    zones: list = field(default_factory=list)


_HEADER = re.compile(r"^\s*(TITLE|VARIABLES|ZONE|[A-Z]+\s*=)", re.I)
_QUOTED = re.compile(r'"([^"]*)"')
_SIZE = re.compile(r"\b([IJK])\s*=\s*(\d+)", re.I)
_ZONE_TITLE = re.compile(r'\bT\s*=\s*(?:"([^"]*)"|([^,\s]+))', re.I)
_PACKING = re.compile(r"\b(?:DATAPACKING|F)\s*=\s*(\w+)", re.I)


def read_table(path):
    """The :class:`Table` of an ASCII Tecplot file GPB writes."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as exc:
        raise TableError(f"cannot be read: {exc.strerror or exc}") from exc
    table = Table(path)
    zones = []                         # [header text, [data lines]]
    for line in lines:
        if not line.strip():
            continue
        if _HEADER.match(line):
            word = line.strip().split("=")[0].strip().upper()
            if word == "TITLE":
                found = _QUOTED.search(line)
                table.title = found.group(1) if found else ""
            elif word.startswith("VARIABLES"):
                table.variables = _QUOTED.findall(line) or \
                    line.split("=", 1)[1].replace(",", " ").split()
            elif word.startswith("ZONE"):
                zones.append([line, []])
            elif zones:
                zones[-1][0] += " " + line       # "I=5000, F=POINT" under the ZONE line
            continue
        if not zones:
            raise TableError("data before the first ZONE: not a Tecplot table")
        zones[-1][1].append(line)
    if not table.variables:
        raise TableError("no VARIABLES line: not a Tecplot table")
    if not zones:
        raise TableError("no ZONE: the table is empty")
    nvar = len(table.variables)
    for header, rows in zones:
        title = _ZONE_TITLE.search(header)
        name = (title.group(1) if title.group(1) is not None else title.group(2)) if title else ""
        sizes = {k.upper(): int(v) for k, v in _SIZE.findall(header)}
        shape = tuple(sizes[k] for k in "IJ" if sizes.get(k, 1) > 1 or k == "I")
        npoints = int(np.prod(shape))
        values = np.fromstring(" ".join(rows), sep=" ")
        if values.size != npoints * nvar:
            raise TableError(f"zone {name or len(table.zones) + 1}: {values.size} values for "
                             f"{npoints} points of {nvar} variables")
        packing = _PACKING.search(header)
        block = packing is not None and packing.group(1).upper() == "BLOCK"
        values = values.reshape(nvar, npoints) if block else values.reshape(npoints, nvar).T
        zone = Zone(name, shape)
        for n, variable in enumerate(table.variables):
            # Fortran order: I fastest
            zone.data[variable] = values[n].reshape(shape, order="F")
        table.zones.append(zone)
    return table


_CACHE = OrderedDict()             # (path, mtime_ns, size) -> Table


def cached_table(path):
    """:func:`read_table`, read again only when the file has changed."""
    info = os.stat(path)
    key = (path, info.st_mtime_ns, info.st_size)
    if key in _CACHE:
        _CACHE.move_to_end(key)
        return _CACHE[key]
    table = read_table(path)
    _CACHE[key] = table
    while len(_CACHE) > 8:
        _CACHE.popitem(last=False)
    return table


# ------------------------------------------------------------- reactions
def read_reactions(path):
    """``[(type, equation)]`` of every reaction of ``chemistry-info.txt``, in
    the mechanism's order; [] when it cannot be read."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.strip() for line in handle]
    except OSError:
        return []
    types, sides = OrderedDict(), OrderedDict()
    part = None
    for line in lines:
        if line.startswith("Reaction type"):
            part = "type"
            continue
        if line.startswith("Reaction definition"):
            part = "definition"
            continue
        tokens = line.split()
        if part == "type" and len(tokens) == 2 and tokens[0].isdigit():
            types[int(tokens[0])] = tokens[1]
        elif part == "definition" and len(tokens) == 5 and tokens[0].isdigit():
            try:
                number, species = int(tokens[0]), tokens[1]
                left, right = float(tokens[2]), float(tokens[3])
            except ValueError:
                continue
            reactants, products = sides.setdefault(number, ([], []))
            if species == "M":
                if left:
                    reactants.append("M")
                    products.append("M")
                continue
            if left:
                reactants.append(_term(left, species))
            if right:
                products.append(_term(right, species))
    reactions = []
    for number, kind in types.items():
        reactants, products = sides.get(number, ([], []))
        falloff = "falloff" in kind
        tail = " (+M)" if falloff and "M" in reactants else ""
        if falloff:
            reactants = [s for s in reactants if s != "M"]
            products = [s for s in products if s != "M"]
        left = " + ".join(reactants) + tail
        right = " + ".join(products) + tail
        reactions.append((kind, f"{left} → {right}".strip() if reactants or products else ""))
    return reactions


def _term(coefficient, species):
    if coefficient == 1:
        return species
    text = f"{coefficient:g}"
    return f"{text} {species}"


def reaction_labels(phase, role, count):
    """The labels of the *count* zones of rate table *role* (``arrhenius``,
    ``troe``, ``lindemann``): the zone n of a table is the n-th reaction of
    its kind, numbered here as in the mechanism."""
    path = phase.files.get("reactions")
    reactions = read_reactions(path) if path else []

    def of_kind(kind):
        if role == "arrhenius":
            return "falloff" not in kind
        return kind == {"troe": "falloff-Troe", "lindemann": "falloff-Lindemann"}[role]

    numbers = [n for n, (kind, _eq) in enumerate(reactions, start=1) if of_kind(kind)]
    labels = []
    for n in range(count):
        if n < len(numbers):
            number = numbers[n]
            equation = reactions[number - 1][1]
            labels.append(f"R{number} · {equation}" if equation else f"R{number}")
        else:
            labels.append(f"Reaction {n + 1}")
    return labels


# ----------------------------------------------------------------- sheets
@dataclass
class Sheet:
    """What can be drawn of one or two tables of a phase.

    ``form`` is ``xy`` (curves against ``x``, one per zone) or ``map`` (a
    quantity over the grid of ``x`` and ``y``).  ``quantities`` are the
    column names offered; ``series`` the zones of an ``xy`` sheet with their
    labels."""
    key: str
    label: str
    form: str
    paths: list
    x: str = "Temperature"
    y: str = ""
    quantities: list = field(default_factory=list)
    series: list = field(default_factory=list)       # [(zone name, label)]
    notes: list = field(default_factory=list)
    log: bool = False
    zones: OrderedDict = field(default_factory=OrderedDict)   # zone name -> Zone (merged)

    def values(self, zone, name):
        part = self.zones.get(zone)
        return None if part is None else part.data.get(name)


def sheets(phase):
    """The keys and labels of what can be drawn of *phase*:
    ``[(key, label)]``, in the order the Phases stage offers them."""
    files = phase.files
    found = []
    if phase.family == "real-fluid":
        if "thermo" in files or "transport" in files:
            found.append(("grid", SHEET_LABELS["grid"]))
        return found
    if "thermo" in files or "transport" in files:
        found.append(("thermo", SHEET_LABELS["thermo"]))
    for role in ("properties", "diffusion", "arrhenius", "troe", "lindemann"):
        if role in files:
            found.append((role, SHEET_LABELS[role]))
    return found


def load_sheet(phase, key):
    """The :class:`Sheet` *key* of *phase*, its tables read (and merged: the
    thermodynamics and the transport of a gas, the two grids of a real
    fluid).  Raises :class:`TableError`."""
    files = phase.files
    if key in ("thermo", "grid"):
        roles = [r for r in ("thermo", "transport") if r in files]
    else:
        roles = [key]
    if not roles:
        raise TableError(f"GPB wrote no {SHEET_LABELS.get(key, key).lower()} table")
    tables = [(role, cached_table(files[role])) for role in roles]
    sheet = Sheet(key, SHEET_LABELS.get(key, key), "map" if key == "grid" else "xy",
                  [files[r] for r in roles], log=key in LOG_SHEETS)
    if key == "grid":
        return _grid_sheet(sheet, tables)
    for role, table in tables:
        if not table.variables or table.variables[0] != "Temperature":
            raise TableError(f"{os.path.basename(table.path)}: its first column is "
                             f"{table.variables[0] if table.variables else 'missing'}, "
                             "not the temperature")
        for zone in table.zones:
            merged = sheet.zones.get(zone.name)
            if merged is None:
                merged = sheet.zones[zone.name] = Zone(zone.name, zone.shape,
                                                       OrderedDict(Temperature=zone.data["Temperature"]))
            elif merged.shape != zone.shape or not np.allclose(
                    merged.data["Temperature"], zone.data["Temperature"]):
                sheet.notes.append(f"{os.path.basename(table.path)}: zone {zone.name} has "
                                   "other temperatures than the thermodynamics; left out")
                continue
            for name in table.variables[1:]:
                data = zone.data[name]
                if key in LOG_SHEETS:
                    data = np.where(np.abs(data) >= INFINITE, np.nan, data)
                merged.data[name] = data
                if name not in sheet.quantities:
                    sheet.quantities.append(name)
    labels = list(sheet.zones)
    if key in ("arrhenius", "troe", "lindemann"):
        labels = reaction_labels(phase, key, len(sheet.zones))
        # reversible: a backward rate (kb), an equilibrium constant (Kc) not 0
        for n, zone in enumerate(sheet.zones.values()):
            back = zone.data.get("kb", zone.data.get("k_c"))
            if back is not None and np.nanmax(np.abs(back)) > 0:
                labels[n] = labels[n].replace(" → ", " ⇌ ", 1)
        sheet.notes.append("Rate constants in Cantera's units: m³, kmol and s, to the order "
                           "of the reaction.")
        if any(np.isnan(z.data[q]).any() for z in sheet.zones.values()
               for q in sheet.quantities if q in z.data):
            sheet.notes.append("Where GPB wrote an infinite rate (1e300) there is no point.")
    elif key == "diffusion":
        pressure = re.search(r"Pref\s*=\s*([-+0-9.eE]+)", tables[0][1].title)
        if pressure:
            sheet.notes.append(f"At {float(pressure.group(1)):g} Pa; the solver scales D with "
                               "1/p.")
        labels = [name.replace("-", " – ", 1) for name in sheet.zones]
    sheet.series = list(zip(sheet.zones, labels))
    return sheet


def _grid_sheet(sheet, tables):
    """The (p, h) grids of a real fluid, as one zone."""
    grid = None
    for role, table in tables:
        if table.variables[:2] != ["Pressure", "Enthalpy"]:
            raise TableError(f"{os.path.basename(table.path)}: not a grid of pressure and "
                             "enthalpy")
        if len(table.zones) != 1 or len(table.zones[0].shape) != 2:
            raise TableError(f"{os.path.basename(table.path)}: not one 2-D zone")
        zone = table.zones[0]
        if grid is None:
            grid = Zone("grid", zone.shape, OrderedDict(
                (name, zone.data[name]) for name in ("Pressure", "Enthalpy")))
        elif zone.shape != grid.shape or not (
                np.allclose(zone.data["Pressure"], grid.data["Pressure"])
                and np.allclose(zone.data["Enthalpy"], grid.data["Enthalpy"])):
            sheet.notes.append(f"{os.path.basename(table.path)}: on another grid than the "
                               "thermodynamics; left out")
            continue
        for name in table.variables[2:]:
            grid.data[name] = zone.data[name]
            sheet.quantities.append(name)
    p, h = grid.data["Pressure"], grid.data["Enthalpy"]
    # the grid GPB builds: p along I (the same in every J), h along J
    if not (np.allclose(p, p[:, :1]) and np.allclose(h, h[:1, :])):
        raise TableError("the grid is not one of pressure along I and enthalpy along J")
    sheet.x, sheet.y = "Pressure", "Enthalpy"
    sheet.zones["grid"] = grid
    sheet.series = [("grid", "grid")]
    if "Temperature" in sheet.quantities:        # the temperature first: it reads the map
        sheet.quantities.remove("Temperature")
        sheet.quantities.insert(0, "Temperature")
    sheet.notes.append("h and s from 0 at (Tmin, pmin) of the phase.")
    return sheet


def axis(sheet, name):
    """The 1-D values along *name* (``Pressure`` or ``Enthalpy``) of a map."""
    data = sheet.zones["grid"].data[name]
    return data[:, 0] if name == sheet.x else data[0, :]
