"""The initial field ICB wrote: read back, and the quantities it implies.

ICB writes the field of every phase into ``fromATLAStoSolver/``
(``io_fields.f90``, ``write_vtk_tec``): ``<name>-ic.tec`` (ASCII Tecplot,
``IC-format = tec``), ``<name>-ic.vtm`` with one ``vtk/B<n>-<kind>.vts`` per
block (``vtk``), or ``<name>-ic.szplt`` (binary Tecplot, which needs TecIO and
is not read here).  A zone (a ``.vts``) is named ``B<n>-<kind>``: the mesh
block *n* it fills, and the kind of the phase (IG, CD, SP, RF).  The values
are cell-centred, i fastest, in SI units.

:func:`read_field` gives a :class:`Field` -- the bands as written, per block --
and :func:`derive` the quantities the solver variables imply.  For an ideal
gas (bands ``rho1 … rhoN u v w p`` and the turbulence ones) they are:

* the density ``rho`` (the sum of the partial densities) and the mass
  fractions ``Y_<species>``, the species and their molar masses taken from the
  ``<name>-phase.txt`` ICB read;
* the temperature ``T = p / (rho R)``, ``R`` the gas constant of the mixture;
* the speed ``|V|`` and the ``Mach`` number, the speed of sound from the
  mixture's ``cp(T)`` in ``<name>-thermo.dat``.

A real fluid gets its speed; a solid, a dispersed phase keep their bands.
:func:`quantities` lists what can be shown, with a label and a unit.
No Qt here; the ``.vts`` blocks are read with pyvista.
"""

from __future__ import annotations

import glob
import os
import re
import xml.etree.ElementTree as ElementTree
from collections import OrderedDict
from dataclasses import dataclass, field

import numpy as np

OUTPUT_DIR = "fromATLAStoSolver"
RU = 8.314462618                    # J/(mol K)
_ZONE_NAME = re.compile(r"^B(\d+)-(\w+)$")
KIND_LABELS = {"IG": "ideal gas", "CD": "dispersed phase", "SP": "solid", "RF": "real fluid"}

# label and unit of a band or a derived quantity, by name (the species and the
# populations of a dispersed phase follow patterns, see :func:`describe`)
_KNOWN = {
    "p": ("p · pressure", "Pa"), "T": ("T · temperature", "K"),
    "Mach": ("Mach number", "–"), "speed": ("|V| · speed", "m/s"),
    "rho": ("ρ · density", "kg/m³"), "u": ("u · velocity x", "m/s"),
    "v": ("v · velocity y", "m/s"), "w": ("w · velocity z", "m/s"),
    "h": ("h · enthalpy", "J/kg"), "matID": ("material index", "–"),
    "rhoNuTilde": ("ρν̃ · Spalart-Allmaras", "kg/(m·s)"),
    "rhoK": ("ρk · turbulent energy", "J/m³"), "rhoOmega": ("ρω · dissipation rate", "kg/(m³·s)"),
}
_STRESS = re.compile(r"^r[uvw]'?[uvw]'?$")
_POPULATION = re.compile(r"^(rp|up|vp|wp|Pp\d*|Tp|np)_(\d)(\d+)$")
_POPULATION_UNITS = {"rp": ("ρp · partial density", "kg/m³"), "up": ("up · velocity x", "m/s"),
                     "vp": ("vp · velocity y", "m/s"), "wp": ("wp · velocity z", "m/s"),
                     "Tp": ("Tp · temperature", "K"), "np": ("np · number density", "1/m³")}


@dataclass
class FieldBlock:
    """The values of one block: ``values[name]`` is a flat array of its cells,
    i fastest; ``shape`` the cells along i, j, k."""
    block: int                     # the mesh block, from 1
    kind: str
    shape: tuple
    values: OrderedDict = field(default_factory=OrderedDict)


@dataclass
class Field:
    """The initial field of one phase, as ICB wrote it."""
    path: str
    phase: str                     # the name of the phase ("" for an unnamed one)
    kind: str = ""
    bands: list = field(default_factory=list)      # the names as written
    blocks: OrderedDict = field(default_factory=OrderedDict)     # mesh block -> FieldBlock
    names: list = field(default_factory=list)      # what can be shown, derived first
    notes: list = field(default_factory=list)      # what could not be derived, and why
    fractions: dict = field(default_factory=dict)  # "Y_<species>" -> its partial density band

    @property
    def label(self):
        return os.path.basename(self.path)

    def values(self, block, name):
        """The values of *name* in mesh block *block*, or None.  A mass
        fraction is computed when asked for: a mechanism has many."""
        part = self.blocks.get(block)
        if part is None:
            return None
        if name in part.values:
            return part.values[name]
        band = self.fractions.get(name)
        if band is not None and band in part.values and "rho" in part.values:
            rho = part.values["rho"]
            return part.values[band] / np.where(rho > 0, rho, np.nan)
        return None


@dataclass
class FieldFile:
    phase: str
    path: str
    format: str                    # "tec", "vtk" or "szplt"
    mtime: float


def field_files(case_dir):
    """The fields ICB wrote into ``fromATLAStoSolver/``, a gas first."""
    from .tables import output_dir
    found = []
    out = output_dir(case_dir)
    for pattern, fmt in (("*ic.tec", "tec"), ("*ic.vtm", "vtk"), ("*ic.szplt", "szplt")):
        for path in sorted(glob.glob(os.path.join(out, pattern))):
            base = os.path.basename(path)
            stem = base[:base.rindex("ic.")]
            if stem and not stem.endswith("-"):
                continue                       # not an ICB name (<name>-ic.tec or ic.tec)
            try:
                mtime = os.path.getmtime(path)
            except OSError:
                continue
            found.append(FieldFile(stem.rstrip("-"), path, fmt, mtime))
    return found


# ----------------------------------------------------------------- reading
class FieldError(ValueError):
    """A file that is not an initial field ICB writes, said in one sentence."""


def read_field(path):
    """The :class:`Field` of *path*, a ``.tec`` or a ``.vtm`` of ICB."""
    base = os.path.basename(path)
    phase = base[:base.rindex("ic.")].rstrip("-") if "ic." in base else ""
    if path.endswith(".vtm"):
        result = _read_vtm(path)
    elif path.endswith(".szplt"):
        raise FieldError("a binary Tecplot file (.szplt) is not read here: write the field "
                         "with IC-format = tec or vtk to see it")
    else:
        result = _read_tec(path)
    result.phase = phase
    kinds = {b.kind for b in result.blocks.values()}
    result.kind = kinds.pop() if len(kinds) == 1 else ""
    return result


def _read_tec(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    match = re.search(r"VARIABLES\s*=\s*(.*)", text)
    if not match:
        raise FieldError(f"{os.path.basename(path)} has no VARIABLES line")
    names = re.findall(r'"([^"]*)"|(\S+)', match.group(1).replace(",", " "))
    names = [a or b for a, b in names]
    zones = list(re.finditer(r"^\s*ZONE\b(.*)$", text, re.M))
    if not zones:
        raise FieldError(f"{os.path.basename(path)} has no zone")
    result = Field(path, "")
    for n, zone in enumerate(zones):
        header = zone.group(1)
        title = re.search(r'\bT\s*=\s*"?([^",]+)"?', header)
        dims = [int(re.search(rf"\b{c}\s*=\s*(\d+)", header).group(1))
                if re.search(rf"\b{c}\s*=\s*(\d+)", header) else 1 for c in "IJK"]
        location = re.search(r"VARLOCATION\s*=\s*\(([^)]*)\)", header)
        cell = set()
        if location:
            for first, last, where in re.findall(
                    r"\[(\d+)(?:\s*-\s*(\d+))?\]\s*=\s*(\w+)", location.group(1)):
                if where.upper().startswith("CELL"):
                    cell.update(range(int(first), int(last or first) + 1))
        if not cell:
            raise FieldError(f"{os.path.basename(path)}: its values are nodal; ICB writes "
                             "the value of each cell")
        if "POINT" in header.upper() and "BLOCK" not in header.upper():
            raise FieldError(f"{os.path.basename(path)}: POINT data, where ICB writes BLOCK data")
        name = title.group(1).strip() if title else ""
        block, kind = _zone_block(name, n)
        nodes = dims[0] * dims[1] * dims[2]
        shape = (max(dims[0] - 1, 1), max(dims[1] - 1, 1), max(dims[2] - 1, 1))
        cells = shape[0] * shape[1] * shape[2]
        end = zones[n + 1].start() if n + 1 < len(zones) else len(text)
        tokens = text[zone.end():end].split()
        sizes = [cells if v + 1 in cell else nodes for v in range(len(names))]
        if len(tokens) < sum(sizes):
            raise FieldError(f"{os.path.basename(path)}: zone {name or n + 1} holds "
                             f"{len(tokens)} values for {sum(sizes)}")
        part = FieldBlock(block, kind, shape)
        start = 0
        for v, size in enumerate(sizes):
            if v + 1 in cell:
                part.values[names[v]] = np.array(tokens[start:start + size], dtype=float)
            start += size
        result.blocks[block] = part
    result.bands = [names[v] for v in range(len(names)) if v + 1 in cell]
    return result


def _zone_block(name, index):
    """``(mesh block, kind)`` of a zone named ``B<n>-<kind>``; the zone's
    place, from 1, when ICB's name is not there."""
    match = _ZONE_NAME.match(name)
    if match:
        return int(match.group(1)), match.group(2)
    return index + 1, ""


def _read_vtm(path):
    try:
        tree = ElementTree.parse(path)
    except (ElementTree.ParseError, OSError) as exc:
        raise FieldError(f"{os.path.basename(path)} cannot be read: {exc}") from exc
    import pyvista as pv
    result = Field(path, "")
    files = [node.get("file") for node in tree.iter("DataSet") if node.get("file")]
    if not files:
        raise FieldError(f"{os.path.basename(path)} names no block file")
    for n, name in enumerate(files):
        full = os.path.join(os.path.dirname(path), name)
        if not os.path.isfile(full):
            raise FieldError(f"{os.path.basename(path)}: {name} is missing")
        grid = pv.read(full)
        if not grid.cell_data.keys():
            raise FieldError(f"{name}: no cell values; ICB writes the value of each cell")
        block, kind = _zone_block(os.path.splitext(os.path.basename(name))[0], n)
        dims = getattr(grid, "dimensions", None) or (grid.n_cells + 1, 2, 2)
        shape = tuple(max(d - 1, 1) for d in dims)
        part = FieldBlock(block, kind, shape)
        for key in grid.cell_data.keys():
            values = np.asarray(grid.cell_data[key], dtype=float)
            if values.ndim == 1:
                part.values[key] = values
        result.blocks[block] = part
        if not result.bands:
            result.bands = list(part.values)
    return result


# ------------------------------------------------------------ derived values
def read_species(path):
    """``[(species, molar mass in kg/mol)]`` of an ideal-gas phase file, or
    None when it is not one."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.split() for line in handle if line.strip()]
    except OSError:
        return None
    if not lines or "ideal-gas" not in " ".join(lines[0]).lower():
        return None
    species = []
    for tokens in lines[1:]:
        try:
            species.append((tokens[0], float(tokens[1]) / 1000.0))
        except (IndexError, ValueError):
            return None
    return species


def read_cp_tables(path):
    """``{species: (T, cp)}`` of a GPB ``thermo.dat`` (one zone per species,
    ``Temperature Cp Enthalpy Entropy dCp``, cp in J/(kg K)), or None."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError:
        return None
    zones = list(re.finditer(r'^\s*ZONE\s+T\s*=\s*"([^"]*)".*$', text, re.M))
    tables = {}
    for n, zone in enumerate(zones):
        end = zones[n + 1].start() if n + 1 < len(zones) else len(text)
        body = text[zone.end():end]
        rows = [line for line in body.splitlines()
                if line.strip() and not re.match(r"\s*[A-Za-z]", line)]
        try:
            data = np.array(" ".join(rows).split(), dtype=float).reshape(-1, 5)
        except ValueError:
            return None
        tables[zone.group(1).strip()] = (data[:, 0], data[:, 1])
    return tables or None


def phase_file(case_dir, phase, suffix):
    """``<phase>-<suffix>`` (``<suffix>`` for an unnamed phase) as ICB read it:
    in the case directory, else where GPB wrote it."""
    name = f"{phase}-{suffix}" if phase else suffix
    for directory in (case_dir, os.path.join(case_dir, OUTPUT_DIR)):
        path = os.path.join(directory, name)
        if os.path.isfile(path):
            return path
    return None


def derive(result, case_dir):
    """Add to *result* the quantities its bands imply (see the module), and
    fill ``names`` with what can be shown, the usual ones first."""
    derived = []
    if result.kind == "IG":
        derived = _derive_gas(result, case_dir)
    elif result.kind == "RF":
        derived = _derive_speed(result)
    order = derived + [b for b in result.bands if b not in derived and not _partial(b)]
    if result.kind == "IG":
        order += [b for b in result.bands if _partial(b)]
    result.names = order
    return result


def _partial(name):
    return re.fullmatch(r"rho\d+", name) is not None


def _derive_speed(result):
    velocity = [c for c in ("u", "v", "w") if c in result.bands]
    if not velocity:
        return []
    for part in result.blocks.values():
        part.values["speed"] = np.sqrt(sum(part.values[c] ** 2 for c in velocity))
    return ["p", "speed"] if "p" in result.bands else ["speed"]


def _derive_gas(result, case_dir):
    partial = [b for b in result.bands if _partial(b)]
    if not partial or "p" not in result.bands:
        result.notes.append("the bands are not those of an ideal gas: shown as written")
        return []
    names = ["p"]
    for part in result.blocks.values():
        part.values["rho"] = sum(part.values[b] for b in partial)
    path = phase_file(case_dir, result.phase, "phase.txt")
    species = read_species(path) if path else None
    if species is None or len(species) != len(partial):
        what = f"{result.phase}-phase.txt" if result.phase else "phase.txt"
        result.notes.append(f"T and Mach need the molar masses of {what}, "
                            + ("which is not there" if path is None else
                               "which does not match the field"))
        names += _derive_speed(result)[-1:] + ["rho"]
        return names
    weights = np.array([w for _s, w in species])
    tables = None
    thermo = phase_file(case_dir, result.phase, "thermo.dat")
    if thermo:
        tables = read_cp_tables(thermo)
        if tables is not None and not all(s in tables for s, _w in species):
            tables = None
    for part in result.blocks.values():
        rho = part.values["rho"]
        safe = np.where(rho > 0, rho, np.nan)
        fractions = [part.values[b] / safe for b in partial]
        gas_constant = RU * sum(y / w for y, w in zip(fractions, weights))
        temperature = part.values["p"] / (safe * gas_constant)
        part.values["T"] = temperature
        if tables is not None:
            cp = np.zeros_like(temperature)
            for (name, _w), y in zip(species, fractions):
                t_table, cp_table = tables[name]
                cp += y * np.interp(temperature, t_table, cp_table)
            gamma = cp / (cp - gas_constant)
            part.values["a"] = np.sqrt(gamma * gas_constant * temperature)
    names.append("T")
    speed = _derive_speed(result)
    if tables is not None and speed:
        for part in result.blocks.values():
            part.values["Mach"] = part.values["speed"] / part.values.pop("a")
        names.append("Mach")
    elif speed:
        what = f"{result.phase}-thermo.dat" if result.phase else "thermo.dat"
        result.notes.append(f"the Mach number needs the cp of every species, from {what}")
        for part in result.blocks.values():
            part.values.pop("a", None)
    names += speed[-1:] + ["rho"]
    if len(species) > 1:
        result.fractions = {f"Y_{name}": band for (name, _w), band in zip(species, partial)}
        names += list(result.fractions)
    return names


def describe(name):
    """``(label, unit)`` of a band or a derived quantity."""
    if name in _KNOWN:
        return _KNOWN[name]
    if name.startswith("Y_"):
        return f"Y {name[2:]} · mass fraction", "–"
    if _partial(name):
        return f"ρ{name[3:]} · partial density", "kg/m³"
    if _STRESS.match(name):
        return f"{name} · Reynolds stress", "kg/(m·s²)"
    match = _POPULATION.match(name)
    if match:
        key, material, group = match.groups()
        label, unit = _POPULATION_UNITS.get(key, (f"{key} · pressure", "Pa"))
        return f"{label} (material {material}, group {group})", unit
    return name, ""


def quantities(result):
    """``[(name, label, unit)]`` of what *result* can show."""
    return [(name,) + describe(name) for name in result.names]


def value_range(result, name, blocks=None):
    """``(min, max)`` of *name* over the blocks of *result* (those of
    *blocks* when given), the values that are not numbers left out, or None."""
    low, high = np.inf, -np.inf
    for b in result.blocks:
        if blocks is not None and b not in blocks:
            continue
        values = result.values(b, name)
        if values is None:
            continue
        finite = values[np.isfinite(values)]
        if finite.size:
            low, high = min(low, float(finite.min())), max(high, float(finite.max()))
    return (low, high) if low <= high else None


def fit_issues(result, shapes):
    """What does not fit between *result* and the mesh: ``shapes`` is the cell
    shape of every mesh block, from block 1.  Returns ``(blocks that fit,
    [sentences])``."""
    fits, issues = set(), []
    for b, part in result.blocks.items():
        if b > len(shapes):
            issues.append(f"the field has a block {b}, the mesh {len(shapes)}")
        elif tuple(shapes[b - 1]) != tuple(part.shape):
            issues.append(f"block {b} has {'×'.join(map(str, part.shape))} cells in the field, "
                          f"{'×'.join(map(str, shapes[b - 1]))} in the mesh")
        else:
            fits.add(b)
    return fits, issues
