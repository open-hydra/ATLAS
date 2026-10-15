"""Data model for a BCB boundary-condition setup and INI (de)serialisation.

A BCB ``input.ini`` has three kinds of sections:

* ``[ATLAS-Parameters]`` -- optional global solver settings.
* ``[BCB-BlockN]``        -- one per block, mapping ``face1..face6`` to a name.
* named BC sections       -- ``[name]`` with ``type = ...`` plus parameters.

A face value is either a *keyword* BC that needs no section (``symmetry``,
``connection``, ``chimera``, ...) or the name of a defined section.

This module is intentionally free of any GUI / Qt / VTK dependency so it can be
unit-tested headlessly.
"""

from __future__ import annotations

from collections import OrderedDict

# BC keywords that are assigned directly on the face line and need no section.
KEYWORD_BCS = [
    "symmetry",
    "outlet",
    "extrapolation",
    "connection",
    "chimera",
    "null",
    "axisymmetric",
]

# BC types that are defined through a named ``[section]`` with ``type = <type>``.
# The lists are *suggested* parameter keys shown in the editor; any key/value
# may be added, so the catalogue does not need to be exhaustive.
TYPED_BCS = OrderedDict([
    ("wall",     ["T", "q", "ks", "Tref", "hconv", "eps", "qrad", "alpha", "beta",
                  "direction", "file-direction", "T-file", "q-file", "ks-file",
                  "Tref-file", "hconv-file", "qrad-file", "eps-file"]),
    ("inlet",    ["g", "T", "T0", "p", "p0", "pRef", "direction", "file-direction",
                  "yN2", "yO2", "yH2", "yCH4", "yH2O", "yCO2", "g-file", "Taf-file",
                  "pRef-file"]),
    ("outlet",   ["p", "pRef", "pRef-file"]),
    ("manifold", ["p0", "T0", "p", "T"]),
    ("gsi",      ["surface-reactions", "pyrolysis-model", "qrad", "eps",
                  "cp", "T", "Ti", "dh",
                  "eq-CEA-file", "eq-CEA-section",
                  "yN2", "yO2", "yH2", "yH2O", "yCO2",
                  "a", "n", "pRef", "rhoGrain", "T0", "krho", "SF",
                  "nuTilde", "k", "omega", "Rij", "nrans",
                  "direction", "a-file", "n-file", "pRef-file", "rhoGrain-file",
                  "Taf-file", "krho-file", "SF-file", "SFgeo-file",
                  "qrad-file", "eps-file", "T-file"]),
    ("periodic", ["direction"]),
])

# Keys whose value must be one of a fixed set of names. BCB stops with an error
# on an unknown name, so the editor pre-fills the first entry and lists the rest.
ENUM_KEY_VALUES = {
    "pyrolysis-model": ["HTPB", "HDPB", "PP"],
    "surface-reactions": ["bradley"],
}

# Renamed BC types, applied when reading an ``input.ini``. ``srm`` became ``gsi``
# when the solid-propellant grain BC was folded into the gas-surface interaction
# family, and BCB no longer accepts the old name.
TYPE_ALIASES = {"srm": "gsi"}

# Suggested keys for the [ATLAS-Parameters] section.
ATLAS_PARAM_KEYS = ["MG-levels", "BC-force-connect", "BC-chimera", "BCB-file"]

# A BC is a section the user names freely, so BCB owns every section that is
# not claimed by another ATLAS tool.  These prefixes are what "claimed" means;
# a case file shared with GPB/ICB/STB/MDB/KAnT must survive a round trip here.
TOOL_SECTION_PREFIXES = ("GPB-Phase", "BCB-Block", "ICB-", "STB-", "MDB-", "KAnT-")
RESERVED_SECTIONS = ("ATLAS-Parameters",)


def is_bc_section(name):
    """True when *name* is a named BC definition rather than a tool section."""
    name = name.strip()
    return not (name in RESERVED_SECTIONS or name.startswith(TOOL_SECTION_PREFIXES))


class BCSection:
    """A named BC section: a type plus ordered key/value parameters."""

    def __init__(self, name, bc_type="wall", params=None):
        self.name = name
        self.type = bc_type
        self.params = OrderedDict(params or [])

    def clone_as(self, new_name):
        return BCSection(new_name, self.type, list(self.params.items()))


class BCBDocument:
    """In-memory representation of a BCB setup.

    * ``parameters``   -- OrderedDict for ``[ATLAS-Parameters]``.
    * ``nblocks``      -- number of blocks.
    * ``block_faces``  -- list (per block) of ``{face_int: name_or_None}``.
    * ``block_extras`` -- list (per block) of the non-``face`` keys of its
      section (``phase = gas``, ...), kept so nothing is lost on a round trip.
    * ``sections``     -- OrderedDict ``name -> BCSection`` for typed BCs.
    * ``block_ndim``   -- list of assignable face counts per block (4 or 6).
    * ``wildcard``     -- the ``[BCB-Block*]`` section, which BCB applies to
      every block without one of its own.  It is expanded into the blocks as
      soon as their number is known, and written back untouched until then.
    """

    def __init__(self):
        self.parameters = OrderedDict()
        self.nblocks = 0
        self.block_faces = []
        self.block_extras = []
        self.block_ndim = []
        self.sections = OrderedDict()
        self.wildcard = OrderedDict()
        self.wildcard_applied = False

    # -- structure -------------------------------------------------------
    def set_blocks(self, ndims):
        """Configure block count and per-block assignable-face count.

        *ndims* is an iterable of 4 or 6 (one entry per block).  Existing
        assignments are preserved where the block still exists.
        """
        ndims = list(ndims)
        new_faces = []
        new_extras = []
        for b, nface in enumerate(ndims):
            prev = self.block_faces[b] if b < len(self.block_faces) else {}
            faces = OrderedDict()
            for f in range(1, nface + 1):
                faces[f] = prev.get(f)
            new_faces.append(faces)
            new_extras.append(self.block_extras[b]
                              if b < len(self.block_extras) else OrderedDict())
        self.nblocks = len(ndims)
        self.block_ndim = ndims
        self.block_faces = new_faces
        self.block_extras = new_extras
        self.apply_wildcard()

    # -- wildcard block --------------------------------------------------
    def apply_wildcard(self):
        """Seed faces left empty from ``[BCB-Block*]`` (what BCB itself does)."""
        if not self.wildcard or not self.nblocks:
            return
        wildcard_faces = {
            int(k[4:]): v for k, v in self.wildcard.items()
            if k.lower().startswith("face") and k[4:].isdigit()
        }
        extras = OrderedDict(
            (k, v) for k, v in self.wildcard.items()
            if not k.lower().startswith("face"))
        for b in range(self.nblocks):
            for f, value in wildcard_faces.items():
                if f in self.block_faces[b] and not self.block_faces[b][f]:
                    self.block_faces[b][f] = value or None
            for key, value in extras.items():
                self.block_extras[b].setdefault(key, value)
        self.wildcard_applied = True

    def assign(self, block_idx, face, name):
        """Assign *name* (or None to clear) to *face* of block *block_idx* (0-based)."""
        self.block_faces[block_idx][face] = name or None

    def face_value(self, block_idx, face):
        return self.block_faces[block_idx].get(face)

    # -- sections --------------------------------------------------------
    def add_section(self, section: BCSection):
        self.sections[section.name] = section

    def remove_section(self, name):
        self.sections.pop(name, None)
        for faces in self.block_faces:
            for f, val in faces.items():
                if val == name:
                    faces[f] = None

    def rename_section(self, old, new):
        if old not in self.sections or old == new:
            return
        sec = self.sections.pop(old)
        sec.name = new
        # Reinsert preserving order.
        self.sections[new] = sec
        for faces in self.block_faces:
            for f, val in faces.items():
                if val == old:
                    faces[f] = new

    def available_names(self):
        """All names assignable to a face: keyword BCs + defined sections."""
        return list(KEYWORD_BCS) + list(self.sections.keys())

    def referenced_sections(self):
        """Section names actually used on at least one face, in first-use order."""
        seen = []
        for faces in self.block_faces:
            for f in sorted(faces):
                val = faces[f]
                if val in self.sections and val not in seen:
                    seen.append(val)
        # Include defined-but-unused sections at the end so nothing is lost.
        for name in self.sections:
            if name not in seen:
                seen.append(name)
        return seen

    # -- validation ------------------------------------------------------
    def unassigned_faces(self):
        """List of ``(block_idx, face)`` with no assignment (an error for BCB)."""
        missing = []
        for b, faces in enumerate(self.block_faces):
            for f, val in faces.items():
                if not val:
                    missing.append((b, f))
        return missing

    # -- serialisation ---------------------------------------------------
    def to_ini_blocks(self):
        """The BCB part of the file: one string per section, no parameters."""
        blocks = []
        if self.wildcard and not self.wildcard_applied:
            # No block is known yet (no mesh, no [BCB-BlockN]): keep the
            # wildcard exactly as it was read.
            lines = ["[BCB-Block*]"]
            lines += [f"{k} = {v}" for k, v in self.wildcard.items()]
            blocks.append("\n".join(lines))
        for b in range(self.nblocks):
            lines = [f"[BCB-Block{b + 1}]"]
            for key, value in self.block_extras[b].items():
                lines.append(f"{key} = {value}")
            for f in sorted(self.block_faces[b]):
                val = self.block_faces[b][f]
                lines.append(f"face{f} = {val if val else ''}")
            blocks.append("\n".join(lines))

        for name in self.referenced_sections():
            sec = self.sections[name]
            lines = [f"[{name}]"]
            if sec.type:
                lines.append(f"type = {sec.type}")
            for k, v in sec.params.items():
                if str(k).strip() == "":
                    continue
                lines.append(f"{k} = {v}")
            blocks.append("\n".join(lines))
        return blocks

    def to_ini(self):
        """The BCB document on its own (``[ATLAS-Parameters]`` included)."""
        blocks = []
        params = OrderedDict(
            (k, v) for k, v in self.parameters.items() if str(v).strip() != ""
        )
        if params:
            block = ["[ATLAS-Parameters]"]
            block += [f"{k} = {v}" for k, v in params.items()]
            blocks.append("\n".join(block))
        blocks.extend(self.to_ini_blocks())
        return ("\n\n".join(blocks).rstrip("\n") + "\n") if blocks else ""

    # -- parsing ---------------------------------------------------------
    @classmethod
    def from_ini(cls, text):
        """Parse an existing INI into a BCB document (for editing).

        Uses a permissive line parser (not configparser) so Fortran-style
        values and duplicate-looking keys survive untouched.
        """
        return cls.from_sections(_parse_ini(text))

    @classmethod
    def from_sections(cls, sections):
        """Build from parsed ``[(name, [(key, value), ...]), ...]``.

        Sections owned by another tool are left alone (see
        :func:`is_bc_section`): in a shared case file they belong to GPB or
        ICB, not to a boundary condition.
        """
        doc = cls()

        # Global parameters.
        for name, kv in sections:
            if name == "ATLAS-Parameters":
                for k, v in kv:
                    doc.parameters[k] = v

        # Block sections, plus the [BCB-Block*] fallback.
        block_map = {}
        extras_map = {}
        max_face = {}
        for name, kv in sections:
            if not name.startswith("BCB-Block"):
                continue
            if name[len("BCB-Block"):].strip() == "*":
                doc.wildcard = OrderedDict(kv)
                continue
            try:
                idx = int(name[len("BCB-Block"):]) - 1
            except ValueError:
                continue
            faces = OrderedDict()
            extras = OrderedDict()
            for k, v in kv:
                if k.lower().startswith("face") and k[4:].isdigit():
                    f = int(k[4:])
                    faces[f] = v or None
                    max_face[idx] = max(max_face.get(idx, 0), f)
                else:
                    extras[k] = v
            block_map[idx] = faces
            extras_map[idx] = extras

        # Named BC sections: everything this GUI does not route elsewhere.
        for name, kv in sections:
            if not is_bc_section(name):
                continue
            kv_dict = OrderedDict(kv)
            bc_type = kv_dict.pop("type", "wall")
            bc_type = TYPE_ALIASES.get(bc_type.strip(), bc_type)
            sec = BCSection(name, bc_type, list(kv_dict.items()))
            doc.add_section(sec)

        if block_map:
            nblocks = max(block_map) + 1
            ndims = []
            for b in range(nblocks):
                nf = max_face.get(b, 4)
                ndims.append(6 if nf > 4 else 4)
            doc.block_extras = [OrderedDict(extras_map.get(b, {}))
                                for b in range(nblocks)]
            doc.set_blocks(ndims)
            for b, faces in block_map.items():
                for f, val in faces.items():
                    if f in doc.block_faces[b]:
                        doc.block_faces[b][f] = val
            doc.apply_wildcard()
        return doc

    # -- per-block keys --------------------------------------------------
    def block_key(self, block_idx, key, default=""):
        if 0 <= block_idx < len(self.block_extras):
            return self.block_extras[block_idx].get(key, default)
        return default

    def set_block_key(self, block_idx, key, value):
        if not (0 <= block_idx < len(self.block_extras)):
            return
        if value is None or str(value).strip() == "":
            self.block_extras[block_idx].pop(key, None)
        else:
            self.block_extras[block_idx][key] = str(value).strip()


def _parse_ini(text):
    """Return ``[(section_name, [(key, value), ...]), ...]`` preserving order."""
    sections = []
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = (line[1:-1].strip(), [])
            sections.append(current)
            continue
        if current is None:
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            current[1].append((k.strip(), v.strip()))
    return sections
