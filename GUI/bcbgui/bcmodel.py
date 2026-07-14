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

import io
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
    ("srm",      ["a", "n", "pRef", "rhoGrain", "Taf", "krho", "SF", "SFgeo",
                  "direction", "a-file", "n-file", "pRef-file", "rhoGrain-file",
                  "Taf-file", "krho-file", "SF-file", "SFgeo-file"]),
    ("periodic", ["direction"]),
])

# Suggested keys for the [ATLAS-Parameters] section.
ATLAS_PARAM_KEYS = ["MG-levels", "BC-force-connect", "BC-chimera", "BCB-file"]


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

    * ``parameters``  -- OrderedDict for ``[ATLAS-Parameters]``.
    * ``nblocks``     -- number of blocks.
    * ``block_faces`` -- list (per block) of ``{face_int: name_or_None}``.
    * ``sections``    -- OrderedDict ``name -> BCSection`` for typed BCs.
    * ``block_ndim``  -- list of assignable face counts per block (4 or 6).
    """

    def __init__(self):
        self.parameters = OrderedDict()
        self.nblocks = 0
        self.block_faces = []
        self.block_ndim = []
        self.sections = OrderedDict()

    # -- structure -------------------------------------------------------
    def set_blocks(self, ndims):
        """Configure block count and per-block assignable-face count.

        *ndims* is an iterable of 4 or 6 (one entry per block).  Existing
        assignments are preserved where the block still exists.
        """
        ndims = list(ndims)
        new_faces = []
        for b, nface in enumerate(ndims):
            prev = self.block_faces[b] if b < len(self.block_faces) else {}
            faces = OrderedDict()
            for f in range(1, nface + 1):
                faces[f] = prev.get(f)
            new_faces.append(faces)
        self.nblocks = len(ndims)
        self.block_ndim = ndims
        self.block_faces = new_faces

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
    def to_ini(self):
        out = io.StringIO()

        params = OrderedDict(
            (k, v) for k, v in self.parameters.items() if str(v).strip() != ""
        )
        if params:
            out.write("[ATLAS-Parameters]\n")
            for k, v in params.items():
                out.write(f"{k} = {v}\n")
            out.write("\n")

        for b in range(self.nblocks):
            out.write(f"[BCB-Block{b + 1}]\n")
            for f in sorted(self.block_faces[b]):
                val = self.block_faces[b][f]
                out.write(f"face{f} = {val if val else ''}\n")
            out.write("\n")

        for name in self.referenced_sections():
            sec = self.sections[name]
            out.write(f"[{name}]\n")
            if sec.type:
                out.write(f"type = {sec.type}\n")
            for k, v in sec.params.items():
                if str(k).strip() == "":
                    continue
                out.write(f"{k} = {v}\n")
            out.write("\n")

        return out.getvalue().rstrip("\n") + "\n"

    # -- parsing ---------------------------------------------------------
    @classmethod
    def from_ini(cls, text):
        """Parse an existing BCB INI into a document (for editing).

        Uses a permissive line parser (not configparser) so Fortran-style
        values and duplicate-looking keys survive untouched.
        """
        doc = cls()
        sections = _parse_ini(text)

        # Global parameters.
        for name, kv in sections:
            if name == "ATLAS-Parameters":
                for k, v in kv:
                    doc.parameters[k] = v

        # Block sections.
        block_map = {}
        max_face = {}
        for name, kv in sections:
            if name.startswith("BCB-Block"):
                try:
                    idx = int(name[len("BCB-Block"):]) - 1
                except ValueError:
                    continue
                faces = OrderedDict()
                for k, v in kv:
                    if k.lower().startswith("face"):
                        try:
                            f = int(k[4:])
                        except ValueError:
                            continue
                        faces[f] = v or None
                        max_face[idx] = max(max_face.get(idx, 0), f)
                block_map[idx] = faces

        # Named BC sections (anything with a type, or referenced by a face).
        known_section_names = {
            n for n, _ in sections
            if n != "ATLAS-Parameters" and not n.startswith("BCB-Block")
        }
        for name, kv in sections:
            if name == "ATLAS-Parameters" or name.startswith("BCB-Block"):
                continue
            kv_dict = OrderedDict(kv)
            bc_type = kv_dict.pop("type", "wall")
            sec = BCSection(name, bc_type, list(kv_dict.items()))
            doc.add_section(sec)

        if block_map:
            nblocks = max(block_map) + 1
            ndims = []
            for b in range(nblocks):
                nf = max_face.get(b, 4)
                ndims.append(6 if nf > 4 else 4)
            doc.set_blocks(ndims)
            for b, faces in block_map.items():
                for f, val in faces.items():
                    if f in doc.block_faces[b]:
                        doc.block_faces[b][f] = val
        return doc


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
