"""The boundary file BCB wrote, read back: the BC of every boundary cell.

BCB writes one file per phase into ``fromATLAStoSolver/``: ``<name>-bc.txt``
(``bc.txt`` for an unnamed phase), and ``<name>-bc<L>.txt`` for multigrid
level *L* (docs/user-guide/bcb/output.md).  A record is a coordinate line --
``block i [j [k]] face id``, 4, 5 or 6 integers for a 1-D, 2-D or 3-D mesh --
and the lines of its payload: the neighbour of a connection, the donors of a
chimera cell, the values of a wall or an inlet.  The records run block by
block (the blocks of the phase, numbered from 1 in mesh order), face 1 to 6,
the cells of a face with ``m`` fastest -- j, k on faces 1 and 2, i, k on 3 and
4, i, j on 5 and 6 --, and ``i, j, k`` is the cell next to the face.  A
dispersed phase repeats its table once per material and population.

:func:`read_bc` gives a :class:`BCFile`, the BC id of every cell of every
face in arrays the shape of the face's cells; :func:`describe_id` names an
id, :func:`decode` its payload; :func:`block_map` puts the blocks of the
file on the blocks of the mesh.  No Qt here.
"""

from __future__ import annotations

import glob
import os
import re
from collections import OrderedDict
from dataclasses import dataclass, field

import numpy as np

from .tables import OUTPUT_DIR, output_dir, read_phase_file

_NAME = re.compile(r"^(?:(.+)-)?bc(\d*)\.txt$")

# id -> (what it is, the fields of its payload); ``massf`` is one field per species
_GAS = {
    0: ("null", []),
    101: ("connection", []), 102: ("chimera", []),
    103: ("multi-solver connection", []), 104: ("multi-solver chimera", []),
    200: ("axis", []), 201: ("periodic", []),
    300: ("symmetry", []),
    301: ("wall, heat flux", ["q", "ks", "eps"]),
    302: ("wall, temperature", ["T", "ks", "eps"]),
    400: ("extrapolation", []),
    401: ("inlet, total conditions", ["T0", "p0", "alpha", "beta", "rf", "massf"]),
    402: ("inlet, total pressure from a file", ["T0", "p0", "alpha", "beta", "rf", "massf"]),
    403: ("inlet, mass flux and T0", ["T0", "g", "alpha", "beta", "rf", "massf"]),
    404: ("inlet, mass flux and T", ["T", "g", "alpha", "beta", "rf", "massf"]),
    405: ("inlet, supersonic", ["mach", "T", "p", "alpha", "beta", "rf", "massf"]),
    406: ("outlet", ["p", "rf"]),
    407: ("inlet, total conditions and back-pressure",
          ["T0", "p0", "p", "alpha", "beta", "rf", "massf"]),
    408: ("inlet, normal velocity", ["T", "un", "alpha", "beta", "rf", "massf"]),
    410: ("inlet, state from a file", ["time-file", "periodic"]),
    420: ("inlet, injector nozzle", ["T0", "p0", "psub", "psup", "g", "rf", "massf"]),
    421: ("inlet, Borda injector", ["T0", "p0", "A1/A3", "rf", "massf"]),
    501: ("manifold", ["block", "face"]),
    502: ("solid propellant", ["Taf", "a", "n", "pRef", "rhoGrain", "SF", "massf"]),
    503: ("melting surface", ["cp", "Tm", "Ti", "dh", "qrad", "eps", "massf"]),
    504: ("pyrolysis", ["pyro", "qrad", "eps", "massf"]),
    505: ("surface reactions", ["surf", "qrad", "eps"]),
    506: ("pyrolysing ablator", ["pyro-table", "surf", "phi", "hv0", "qrad", "eps"]),
}
_SOLID = dict(_GAS)
_SOLID.update({
    301: ("wall, heat flux", ["q"]),
    302: ("wall, temperature", ["T"]),
    303: ("wall, convection and radiative flux", ["hconv", "qrad", "Tref"]),
    304: ("wall, radiative exchange", ["eps", "Tref"]),
    305: ("wall, convection and radiative exchange", ["hconv", "eps", "Tref"]),
})
_DISPERSED = dict(_GAS)
_DISPERSED.update({
    400: ("outlet", []),
    401: ("inlet, scaled on the gas", ["krho", "kV", "alphap", "betap", "kT", "rp", "sigmap",
                                       "distribution", "ds"]),
    402: ("inlet, mass flux and speed", ["gp", "|V|", "alphap", "betap", "Tp", "rp", "sigmap",
                                         "distribution", "ds"]),
    403: ("inlet, mass flux, speed scaled", ["gp", "kV", "alphap", "betap", "Tp", "rp",
                                             "sigmap", "distribution", "ds"]),
})
INTERFACES = (101, 102, 103, 104, 201)     # not a boundary: a face shared with other cells


def describe_id(bc_id, family="gas"):
    """``(what it is, payload fields)`` of BC *bc_id* in a file of *family*."""
    table = {"solid": _SOLID, "condensed": _DISPERSED}.get(family, _GAS)
    return table.get(bc_id, (f"BC {bc_id}", []))


@dataclass
class FaceCells:
    """The cells of one face: ``ids[m, n]`` the BC id (-1: no record),
    ``lines[m, n]`` the line of its first record."""
    ids: np.ndarray
    lines: np.ndarray


@dataclass
class BlockCells:
    block: int                     # the block of the phase, from 1
    dims: tuple                    # its cells along i, j, k
    faces: OrderedDict = field(default_factory=OrderedDict)    # face -> FaceCells
    copies: int = 1                # the tables of a dispersed phase
    span: tuple = (0, 0)           # its first and last line + 1


@dataclass
class BCFile:
    path: str
    phase: str
    level: int
    ndim: int = 3
    family: str = ""
    members: list = field(default_factory=list)     # species (a gas), materials
    blocks: OrderedDict = field(default_factory=OrderedDict)  # block -> BlockCells
    lines: list = field(default_factory=list)
    records: int = 0

    @property
    def label(self):
        return os.path.basename(self.path)

    def counts(self):
        """``{id: cells}`` over the file (one copy of a repeated table)."""
        found = {}
        for block in self.blocks.values():
            for face in block.faces.values():
                ids, counts = np.unique(face.ids[face.ids >= 0], return_counts=True)
                for bc_id, count in zip(ids.tolist(), counts.tolist()):
                    found[bc_id] = found.get(bc_id, 0) + count
        return dict(sorted(found.items()))

    def record(self, block, face, m, n, copy=0):
        """The lines of the record of cell *(m, n)* (from 0) of *face* of
        *block*: the coordinate line, then the payload."""
        part = self.blocks[block]
        start = int(part.faces[face].lines[m, n])
        if copy:
            start += copy * (part.span[1] - part.span[0]) // part.copies
        end = start + 1
        while end < len(self.lines) and not _is_coordinate(self.lines[end], self.ndim):
            end += 1
        return self.lines[start:end]


@dataclass
class BCFileInfo:
    phase: str
    level: int
    path: str
    mtime: float


def bc_files(case_dir):
    """The boundary files of the case, by phase then level."""
    found = []
    for path in glob.glob(os.path.join(output_dir(case_dir), "*bc*.txt")):
        match = _NAME.match(os.path.basename(path))
        if not match:
            continue
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        found.append(BCFileInfo(match.group(1) or "", int(match.group(2) or 1), path, mtime))
    return sorted(found, key=lambda f: (f.phase, f.level))


class BCFileError(ValueError):
    """A file that is not a boundary file of BCB, said in one sentence."""


def _is_coordinate(line, ndim):
    tokens = line.split()
    return len(tokens) == ndim + 3 and all(t.lstrip("-").isdigit() for t in tokens)


def read_bc(path, phase=None, level=1):
    """The :class:`BCFile` of *path*."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as exc:
        raise BCFileError(f"cannot be read: {exc.strerror or exc}") from exc
    if phase is None:
        match = _NAME.match(os.path.basename(path))
        phase, level = (match.group(1) or "", int(match.group(2) or 1)) if match else ("", 1)
    result = BCFile(path, phase, level, lines=lines)
    stem = f"{phase}-" if phase else ""
    # the phase file BCB read: GPB's, else the case folder's
    family, members = "", []
    here = os.path.dirname(os.path.abspath(path))
    for directory in (here, os.path.dirname(here)):
        family, _header, members = read_phase_file(os.path.join(directory, stem + "phase.txt"))
        if family:
            break
    result.family, result.members = family or "gas", members
    first = next((line for line in lines if line.strip()), None)
    if first is None:
        raise BCFileError("the file is empty")
    tokens = first.split()
    if len(tokens) not in (4, 5, 6) or not all(t.lstrip("-").isdigit() for t in tokens):
        raise BCFileError("its first line is not a record of a boundary cell "
                          "(block, i, j, k, face, id)")
    ndim = result.ndim = len(tokens) - 3
    raw = {}                       # block -> list of (line, i, j, k, face, id)
    for number, line in enumerate(lines):
        tokens = line.split()
        if len(tokens) != ndim + 3:
            continue
        try:
            values = [int(t) for t in tokens]
        except ValueError:
            continue
        block, face, bc_id = values[0], values[-2], values[-1]
        index = values[1:1 + ndim] + [1] * (3 - ndim)
        raw.setdefault(block, []).append((number, *index, face, bc_id))
    if not raw:
        raise BCFileError("no record of a boundary cell")
    for block, rows in raw.items():
        data = np.array(rows, dtype=np.int64)
        dims = tuple(int(data[:, c].max()) for c in (1, 2, 3))
        part = BlockCells(block, dims, span=(int(data[0, 0]), int(data[-1, 0]) + 1))
        result.records += len(data)
        for face in sorted(set(data[:, 4].tolist())):
            rows_f = data[data[:, 4] == face]
            m_axis, n_axis = {1: (2, 3), 2: (2, 3), 3: (1, 3), 4: (1, 3),
                              5: (1, 2), 6: (1, 2)}.get(face, (1, 2))
            shape = (dims[m_axis - 1], dims[n_axis - 1])
            ids = np.full(shape, -1, dtype=np.int32)
            first = np.full(shape, -1, dtype=np.int64)
            m, n = rows_f[:, m_axis] - 1, rows_f[:, n_axis] - 1
            ok = (m >= 0) & (n >= 0) & (m < shape[0]) & (n < shape[1])
            m, n, rows_f = m[ok], n[ok], rows_f[ok]
            # the first record of a cell (a dispersed phase repeats them)
            cell, at = np.unique(m * shape[1] + n, return_index=True)
            ids.reshape(-1)[cell] = rows_f[at, 5]
            first.reshape(-1)[cell] = rows_f[at, 0]
            part.faces[face] = FaceCells(ids, first)
        cells = sum(int((f.ids >= 0).sum()) for f in part.faces.values())
        part.copies = max(1, round(len(data) / max(cells, 1)))
        result.blocks[block] = part
    return result


_CACHE = OrderedDict()


def cached_bc(path):
    """:func:`read_bc`, read again only when the file has changed."""
    info = os.stat(path)
    key = (path, info.st_mtime_ns, info.st_size)
    if key not in _CACHE:
        _CACHE[key] = read_bc(path)
        while len(_CACHE) > 4:
            _CACHE.popitem(last=False)
    return _CACHE[key]


# ---------------------------------------------------------------- payloads
def _number(token):
    """A value of a record as it reads: ``2000`` for ``2.0000000000000000E+03``."""
    try:
        value = float(token)
    except ValueError:
        return token
    if value == int(value) and abs(value) < 1e9:
        return str(int(value))
    return f"{value:.10g}"


def decode(result, bc_id, payload):
    """``[(name, value)]`` of the *payload* lines of a record of *bc_id*."""
    if not payload:
        return []
    tokens = [t for t in re.split(r"[,\s]+", " ".join(payload)) if t]
    if bc_id in (101, 103, 201):
        values = tokens
        nd = result.ndim
        if len(values) >= nd + 2:
            where = ", ".join(values[1:1 + nd])
            pairs = [("to block", values[0]), ("cell", f"({where})"), ("face", values[1 + nd])]
            if bc_id == 103 and len(values) > nd + 6:
                pairs.append(("ks", values[-1]))
            return pairs
        return [("payload", " ".join(values))]
    if bc_id in (102, 104):
        counts = payload[0].split()
        pairs = [("donors, layer 1", counts[0] if counts else "?"),
                 ("donors, layer 2", counts[1] if len(counts) > 1 else "?")]
        if len(counts) > 2:
            pairs.append(("ks", counts[2]))
        return pairs
    _what, names = describe_id(bc_id, result.family)
    pairs = []
    n = 0
    for name in names:
        if name == "massf":
            species = [m for m in result.members] or []
            count = len(species)
            for s in range(count):
                if n >= len(tokens):
                    break
                value = tokens[n]
                n += 1
                try:
                    if float(value) <= 1e-19:
                        continue                # the floor of a species not set
                except ValueError:
                    pass
                pairs.append((f"Y({species[s]})", _number(value)))
            continue
        if n >= len(tokens):
            break
        pairs.append((name, _number(tokens[n])))
        n += 1
    if n < len(tokens):
        pairs.append(("turbulence" if result.family != "condensed" else "more",
                      ", ".join(_number(t) for t in tokens[n:])))
    return pairs


# ------------------------------------------------------------------ blocks
def block_map(result, mesh_dims, phase_blocks=None):
    """``({block of the file: mesh block}, how, issues)``, blocks from 1.

    *mesh_dims*: the cells along i, j, k of every mesh block; *phase_blocks*:
    the mesh blocks of the phase in the deck (its ``[BCB-BlockN] phase``
    lists), None when there is no deck.  Without one the blocks of the file
    are matched to the mesh blocks in order, by size; a file of a multigrid
    level is matched at that level."""
    factor = 2 ** (result.level - 1)

    def coarse(dims):
        # BCB halves every direction of more than one cell, once per level
        return tuple(max(1, n // factor) if n > 1 else n for n in dims[:result.ndim])

    wanted = {b: part.dims[:result.ndim] for b, part in result.blocks.items()}
    sizes = [coarse(tuple(d)) for d in mesh_dims]
    issues = []
    if phase_blocks is not None:
        mapping = {}
        for local, mesh in enumerate(phase_blocks, start=1):
            if local in wanted:
                mapping[local] = mesh
        how = "the blocks of the phase in the deck"
        extra = [b for b in wanted if b not in mapping]
        if extra:
            issues.append(f"block {', '.join(map(str, extra))} of the file: the deck gives the "
                          "phase fewer blocks")
    else:
        mapping, start = {}, 0
        for local in sorted(wanted):
            for mesh in range(start, len(sizes)):
                if sizes[mesh] == wanted[local]:
                    mapping[local] = mesh + 1
                    start = mesh + 1
                    break
        if len(wanted) == len(sizes) and all(mapping.get(b) == b for b in wanted):
            how = "block for block"
        else:
            how = "by size, in mesh order (no deck says which blocks the phase has)"
    for local, mesh in sorted(mapping.items()):
        if mesh > len(sizes):
            issues.append(f"block {local}: the mesh has {len(sizes)} blocks")
        elif sizes[mesh - 1] != wanted[local]:
            shown = "×".join(map(str, wanted[local]))
            have = "×".join(map(str, sizes[mesh - 1]))
            issues.append(f"block {local} of the file ({shown} cells) is not mesh block "
                          f"{mesh} ({have})")
    unplaced = [b for b in wanted if b not in mapping]
    if unplaced and phase_blocks is None:
        issues.append(f"block {', '.join(map(str, unplaced))} of the file: no mesh block of "
                      "its size")
    return {b: m for b, m in mapping.items()
            if m <= len(sizes) and sizes[m - 1] == wanted[b]}, how, issues


def fine_ids(face, fine_shape, factor):
    """The ids of a coarse level's face on the cells of the mesh: each
    coarse cell over the fine ones it covers."""
    m = np.minimum(np.arange(fine_shape[0]) // (factor if fine_shape[0] > 1 else 1),
                   face.ids.shape[0] - 1)
    n = np.minimum(np.arange(fine_shape[1]) // (factor if fine_shape[1] > 1 else 1),
                   face.ids.shape[1] - 1)
    return face.ids[np.ix_(m, n)], (m, n)
