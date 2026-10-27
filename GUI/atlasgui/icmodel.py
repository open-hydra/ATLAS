"""Data model for the ICB part of an ATLAS case.

An ICB deck gives the initial state of every mesh block:

* ``[ICB-Block<N>]`` -- the state of block N, or the zones it is split into;
* ``[ICB-Block*]``   -- the same for every block without a section of its own;
* zone sections      -- named freely (``[plenum]``, ``[hot]``), each the state of
  one part of a block, which lists it as ``zone<n> = plenum`` with the part in
  ``range<n>`` along the letters of its ``direction``.

A *state* is one flat list of keys that every phase of the block reads at the
same time: ``T = 300`` sets the gas and the solid alike.  :class:`ICState` keeps
those keys as the source of truth -- a key the GUI has no widget for is still
written back -- and reads the structure the editor needs from them: the mode
(uniform, nozzle, interpolate), the profiles (``<key>-file``), the species
mass fractions (``y<species>``).

Zone sections carry no prefix, like the BC sections of BCB: a section belongs
to ICB when an ICB block names it in a ``zone<n>`` key
(:func:`zone_section_names`), and BCB does not claim it.

The key schema (descriptions, defaults, allowed values, the phase each key is
read for) comes from ICB's input reference, which ``ICB --write-config-doc``
generates from the tool's own registry, so the GUI cannot drift from the tool.

No Qt here: the model can be built and serialised headlessly.
"""

from __future__ import annotations

import os
import re
from collections import OrderedDict

# --------------------------------------------------------------- the schema
_HERE = os.path.dirname(os.path.abspath(__file__))
ATLAS_ROOT = os.path.abspath(os.path.join(_HERE, os.pardir, os.pardir))
_REFERENCE_PATH = os.path.join(ATLAS_ROOT, "docs", "user-guide", "icb",
                               "input-reference.md")

# The tables of the input reference: phase-independent ones, then one per
# phase kind.  A state key belongs to every kind whose table lists it.
GLOBAL_TABLE = "ATLAS-Parameters"
BLOCK_TABLE = "ICB-Block*"
COMPOSITION_TABLE = "ICB-Composition"
KIND_TABLES = OrderedDict([("IG", "ICB-IG"), ("RF", "ICB-RF"),
                           ("SP", "ICB-SP"), ("DP", "ICB-DP")])


def _load_reference(path=_REFERENCE_PATH):
    """``{table: {key: info}}`` from the generated markdown reference.

    Each table row is ``| key | default | allowed | required | description |``;
    the allowed column separates names with ``<br>`` or commas, or holds a
    numeric constraint such as ``>=0``.
    """
    tables = OrderedDict()
    current = None
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:                                     # pragma: no cover
        return tables
    for line in lines:
        heading = re.fullmatch(r"##\s+(\S+)\s*", line)
        if heading:
            current = tables.setdefault(heading.group(1), OrderedDict())
            continue
        if current is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 5 or cells[0] in ("Parameter", "") or set(cells[0]) <= {"-"}:
            continue
        allowed = cells[2]
        constraint = allowed if allowed[:1] in ("<", ">", "=") else ""
        choices = [] if constraint else [
            a.strip() for a in re.split(r"<br>|,", allowed) if a.strip()]
        current[cells[0]] = {"default": cells[1], "allowed": choices,
                             "constraint": constraint, "description": cells[4]}
    return tables


REFERENCE = _load_reference()
SCHEMA_FOUND = bool(REFERENCE)


def key_info(key, kind=None):
    """What the reference says of *key*: in *kind*'s table when given, else
    in the first table that lists it.  ``y<species>`` keys read as the
    reference's ``yspecies`` rows."""
    generic = species_key_pattern(key)
    tables = [KIND_TABLES[kind]] if kind in KIND_TABLES else list(REFERENCE)
    tables += [BLOCK_TABLE, COMPOSITION_TABLE, GLOBAL_TABLE]
    for table in tables:
        rows = REFERENCE.get(table, {})
        if key in rows:
            return rows[key]
        if generic and generic in rows:
            return rows[generic]
    return None


def describe(key, kind=None):
    info = key_info(key, kind)
    return info["description"] if info else ""


def allowed_values(key, kind=None):
    info = key_info(key, kind)
    return list(info["allowed"]) if info else []


def default_of(key, kind=None):
    info = key_info(key, kind)
    return info["default"] if info else ""


def kind_keys(kind):
    """The state keys ICB reads for a phase of *kind* (IG, RF, SP, DP)."""
    keys = list(REFERENCE.get(KIND_TABLES.get(kind, ""), {}))
    if kind == "IG":
        keys += [k for k in REFERENCE.get(COMPOSITION_TABLE, {}) if k not in keys]
    return keys


# ------------------------------------------------------------ phase kinds
# GPB phase types -> the kind ICB reads (src/common/read_phase.f90).
KIND_OF_TYPE = {
    "ideal-gas": "IG", "heavy-gas": "IG",
    "condensed-dispersed": "DP", "liquid-dispersed": "DP", "solid-dispersed": "DP",
    "solid": "SP", "solid-bulk": "SP",
    "real-fluid": "RF",
}
KIND_LABEL = {"IG": "Ideal gas", "RF": "Real fluid", "SP": "Solid",
              "DP": "Dispersed"}


def kind_of(phase_type):
    return KIND_OF_TYPE.get((phase_type or "").strip(), "IG")


# --------------------------------------------------------------- the keys
# Keys of a block section that shape it rather than give a state.  A block
# split into zones carries only these (ICB refuses a state key next to zones).
STRUCTURAL_KEYS = ("phase", "type", "direction")
_ZONE_KEY = re.compile(r"zone(\d+)")
_RANGE_KEY = re.compile(r"range(\d+)")

# Letters of direction, in the order ICB reads the pairs of range<n>.
DIRECTION_LETTERS = "xyzrtijk"
PROFILE_DIRECTIONS = ("x", "y", "z", "r", "t")

# Scalar fields that a file can replace (<key>-file, <key>-direction).
PROFILE_FIELDS = OrderedDict([
    ("IG", ("mach", "p0", "T0", "p", "T", "rho")),
    ("RF", ("p", "T", "h", "vel")),
    ("SP", ("T",)),
])

INTERPOLATION_KEYS = ("old-solution", "old-block-id", "interpolation-law",
                      "theta", "nz", "old-species")
NOZZLE_KEYS = ("nozzle-direction", "nozzle-threshold")

# The modes a state is edited in.  ICB's own type follows from them: a
# uniform state with a profile is 'variable', and old-solution makes any
# state 'interpolation' whatever its type says.
MODES = OrderedDict([
    ("uniform", "Uniform"),
    ("nozzle", "Nozzle"),
    ("interpolate", "Interpolate"),
])
ICB_TYPES = ("homogeneous", "variable", "interpolation", "nozzle", "multizone")


def is_structural(key):
    return (key in STRUCTURAL_KEYS or bool(_ZONE_KEY.fullmatch(key))
            or bool(_RANGE_KEY.fullmatch(key)) or key.startswith("ignore-"))


def species_key_pattern(key):
    """The reference row a species key reads as: ``yspecies`` for ``yN2``,
    ``yspecies-file`` for ``yN2-file``, ...; ``""`` for any other key."""
    match = re.fullmatch(r"y([A-Za-z(][^\s=]*?)(-file|-direction)?", key)
    if not match or key in ("y", "y-file", "y-direction"):
        return ""
    return "yspecies" + (match.group(2) or "")


def species_of_key(key):
    """``N2`` for ``yN2``, ``yN2-file`` and ``yN2-direction``; ``""`` otherwise."""
    if not species_key_pattern(key):
        return ""
    name = key[1:]
    for suffix in ("-file", "-direction"):
        if name.endswith(suffix):
            return name[:-len(suffix)]
    return name


def split_values(value):
    return (value or "").split()


# ---------------------------------------------------------------- a state
class ICState:
    """The keys of one state: a block section or a zone section."""

    def __init__(self, params=None):
        self.params = OrderedDict(params or [])

    # -- raw access ------------------------------------------------------
    def get(self, key, default=""):
        value = self.params.get(key)
        return default if value is None else value

    def set(self, key, value):
        """Set *key*; an empty value removes the line."""
        if value is None or str(value).strip() == "":
            self.params.pop(key, None)
        else:
            self.params[key] = str(value).strip()

    def has(self, key):
        return key in self.params

    def clear(self, *keys):
        for key in keys:
            self.params.pop(key, None)

    def state_keys(self):
        """The keys that give the state (every key but the structural ones)."""
        return [k for k in self.params if not is_structural(k)]

    # -- what the keys mean ----------------------------------------------
    @property
    def mode(self):
        """``uniform``, ``nozzle`` or ``interpolate``, as ICB resolves it:
        ``old-solution`` wins over the type, and a profile in a nozzle state
        still leaves it a nozzle state (ICB then warns and drops the law)."""
        icb_type = self.get("type").strip()
        if self.has("old-solution") or icb_type == "interpolation":
            return "interpolate"
        if icb_type == "nozzle":
            return "nozzle"
        return "uniform"

    def set_mode(self, mode):
        """Switch to *mode*, writing the type ICB needs; the keys that only
        the other modes read are left to the caller (the editor asks)."""
        if mode == "interpolate":
            self.set("type", "interpolation")
        elif mode == "nozzle":
            self.set("type", "nozzle")
            self.clear("old-solution")
        elif mode == "uniform":
            self.clear("old-solution")
            if self.get("type").strip() in ("interpolation", "nozzle"):
                self.clear("type")
        else:
            raise ValueError(f"unknown mode {mode!r}")

    def profile_keys(self):
        """The ``<key>-file`` keys of the state (species profiles included)."""
        return [k for k in self.params if k.endswith("-file")
                and k not in ("eq-CEA-file",)]

    def is_variable(self):
        """True when ICB builds this state as ``variable``: a profile is given
        (outside an interpolation, which takes everything from its source)."""
        return self.mode != "interpolate" and bool(self.profile_keys())

    def mass_fractions(self):
        """``{species: value}`` of the constant ``y<species>`` keys, as written."""
        return OrderedDict((species_of_key(k), v) for k, v in self.params.items()
                           if species_key_pattern(k) == "yspecies")

    def species_keys(self):
        """Every ``y<species>``, ``y<species>-file`` and ``-direction`` key."""
        return [k for k in self.params if species_key_pattern(k)]


# ---------------------------------------------------------------- a block
class ICZoneRef:
    """One ``zone<n> = <section>`` of a block and its ``range<n>``."""

    def __init__(self, section, range_values=()):
        self.section = section
        self.range = list(range_values)

    def __repr__(self):
        return f"ICZoneRef({self.section!r}, {self.range!r})"

    def __eq__(self, other):
        return (isinstance(other, ICZoneRef) and self.section == other.section
                and self.range == other.range)


class ICBlock(ICState):
    """An ``[ICB-Block<N>]`` section, or ``[ICB-Block*]`` (``index = "*"``)."""

    def __init__(self, index, params=None):
        super().__init__(params)
        self.index = index

    @property
    def section_name(self):
        return f"ICB-Block{self.index}"

    @property
    def is_wildcard(self):
        return self.index == "*"

    # -- phases ----------------------------------------------------------
    @property
    def phases(self):
        """The phase names the block builds; empty means all of them."""
        return split_values(self.get("phase"))

    @phases.setter
    def phases(self, names):
        self.set("phase", " ".join(n for n in names if n))

    # -- zones -----------------------------------------------------------
    @property
    def direction(self):
        return self.get("direction").strip()

    @property
    def is_split(self):
        """True when the block takes its state from zones (ICB: the key
        ``direction`` alone makes a block multizone)."""
        return (self.has("direction") or self.get("type").strip() == "multizone"
                or any(_ZONE_KEY.fullmatch(k) for k in self.params))

    def zone_refs(self):
        """The zones of the block, ``zone1`` first.  A gap in the numbering
        is kept: ICB reads up to the first missing index, and the editor says
        so rather than renumbering behind the user's back."""
        numbered = []
        for key, value in self.params.items():
            match = _ZONE_KEY.fullmatch(key)
            if match:
                n = int(match.group(1))
                numbered.append((n, ICZoneRef(value.strip(),
                                              split_values(self.get(f"range{n}")))))
        numbered.sort(key=lambda item: item[0])
        return [ref for _n, ref in numbered]

    def zone_numbers(self):
        return sorted(int(m.group(1)) for m in
                      (_ZONE_KEY.fullmatch(k) for k in self.params) if m)

    def set_zones(self, direction, refs):
        """Split the block into *refs* along *direction*: ``zone1``,
        ``range1``, ... in the order given (the order ICB writes them in).
        The state keys of the block move nowhere: a split block carries
        none, so the caller moves them into a zone first."""
        kept = [(k, v) for k, v in self.params.items()
                if not (_ZONE_KEY.fullmatch(k) or _RANGE_KEY.fullmatch(k)
                        or k == "direction")]
        self.params = OrderedDict(kept)
        if not refs:
            if self.get("type").strip() == "multizone":
                self.clear("type")
            return
        self.params["direction"] = direction
        for n, ref in enumerate(refs, start=1):
            self.params[f"zone{n}"] = ref.section
            self.params[f"range{n}"] = " ".join(str(v) for v in ref.range)

    def rename_zone(self, old, new):
        for key, value in self.params.items():
            if _ZONE_KEY.fullmatch(key) and value.strip() == old:
                self.params[key] = new


# -------------------------------------------------------------- the deck
def _block_index(name):
    """``3`` for ``ICB-Block3``, ``"*"`` for ``ICB-Block*``, else None."""
    match = re.fullmatch(r"ICB-Block(\d+|\*)", name.strip())
    if not match:
        return None
    token = match.group(1)
    return token if token == "*" else int(token)


# Sections a zone<n> can never claim: they belong to another tool, and ICB
# never reads a section whose name holds 'Block' as a zone (it refuses it).
_OTHER_TOOL_PREFIXES = ("ATLAS-", "GPB-", "BCB-", "STB-", "MDB-", "KAnT-")


def _claimable(name):
    return bool(name) and "Block" not in name and not name.startswith(_OTHER_TOOL_PREFIXES)


def zone_section_names(sections):
    """The sections that ICB blocks name as zones, in the order first named.

    *sections* is ``[(name, [(key, value), ...]), ...]``.  Every ``zone<n>``
    key counts, also one ICB would not read (after a gap): the section is
    an initial state either way, never a BC.
    """
    names = []
    for name, kv in sections:
        if _block_index(name) is None:
            continue
        refs = []
        for key, value in kv:
            match = _ZONE_KEY.fullmatch(key.strip())
            if match:
                refs.append((int(match.group(1)), value.strip()))
        for _n, zone in sorted(refs):
            if _claimable(zone) and zone not in names:
                names.append(zone)
    return names


class ICBDocument:
    """The ICB sections of a case.

    * ``wildcard`` -- the ``[ICB-Block*]`` section, or None;
    * ``blocks``   -- ``{index: ICBlock}`` for the ``[ICB-Block<N>]`` sections;
    * ``zones``    -- ``{name: ICState}`` for the zone sections, in the order
      the blocks name them;
    * ``kept``     -- sections written back as read: an ``ICB-`` section that
      is no block, and the second copy of a section declared twice (ICB
      reads the first and reports the second, so it must not vanish here).
    """

    def __init__(self):
        self.wildcard = None
        self.blocks = OrderedDict()
        self.zones = OrderedDict()
        self.kept = []

    # -- parsing ---------------------------------------------------------
    @classmethod
    def from_sections(cls, sections):
        doc = cls()
        zone_names = zone_section_names(sections)
        seen = set()
        for name, kv in sections:
            index = _block_index(name)
            if index is None and name not in zone_names:
                if name.strip().startswith("ICB-"):
                    doc.kept.append((name, list(kv)))
                continue
            if name in seen:
                doc.kept.append((name, list(kv)))
                continue
            seen.add(name)
            if index == "*":
                doc.wildcard = ICBlock("*", kv)
            elif index is not None:
                doc.blocks[index] = ICBlock(index, kv)
        for zone in zone_names:
            for name, kv in sections:
                if name == zone:
                    doc.zones[zone] = ICState(kv)
                    break
        doc.blocks = OrderedDict(sorted(doc.blocks.items()))
        return doc

    @classmethod
    def from_ini(cls, text):
        from .bcmodel import _parse_ini
        return cls.from_sections(_parse_ini(text))

    # -- blocks ----------------------------------------------------------
    def block(self, index):
        """The section that gives block *index* its state: its own, else
        ``[ICB-Block*]``, else None (ICB then stops on the block)."""
        return self.blocks.get(index) or self.wildcard

    def own_block(self, index):
        """Block *index*'s own section, made when it has none."""
        if index == "*":
            if self.wildcard is None:
                self.wildcard = ICBlock("*")
            return self.wildcard
        if index not in self.blocks:
            self.blocks[index] = ICBlock(index)
            self.blocks = OrderedDict(sorted(self.blocks.items()))
        return self.blocks[index]

    def remove_block(self, index):
        """Drop block *index*'s own section (it falls back on the wildcard)."""
        if index == "*":
            self.wildcard = None
        else:
            self.blocks.pop(index, None)
        self.drop_unused_zones()

    def all_blocks(self):
        """Every block section, the wildcard first."""
        return ([self.wildcard] if self.wildcard else []) + list(self.blocks.values())

    # -- zones -----------------------------------------------------------
    def zone_names(self):
        return list(self.zones)

    def referenced_zones(self):
        names = []
        for block in self.all_blocks():
            for ref in block.zone_refs():
                if ref.section and ref.section not in names:
                    names.append(ref.section)
        return names

    def add_zone(self, name, state=None):
        self.zones[name] = state if state is not None else ICState()
        return self.zones[name]

    def rename_zone(self, old, new):
        if old not in self.zones or new == old:
            return
        self.zones = OrderedDict((new if k == old else k, v)
                                 for k, v in self.zones.items())
        for block in self.all_blocks():
            block.rename_zone(old, new)

    def drop_unused_zones(self):
        """Remove the zone sections no block names any more."""
        used = set(self.referenced_zones())
        for name in [n for n in self.zones if n not in used]:
            del self.zones[name]

    def section_names(self):
        """Every section name this document writes."""
        return ([b.section_name for b in self.all_blocks()] + list(self.zones)
                + [name for name, _kv in self.kept])

    # -- serialisation ---------------------------------------------------
    def to_ini_blocks(self):
        def section(name, params):
            lines = [f"[{name}]"]
            lines += [f"{k} = {v}" for k, v in params if str(k).strip()]
            return "\n".join(lines)

        parts = [section(b.section_name, b.params.items()) for b in self.all_blocks()]
        ordered = self.referenced_zones()
        ordered += [n for n in self.zones if n not in ordered]
        parts += [section(n, self.zones[n].params.items())
                  for n in ordered if n in self.zones]
        parts += [section(name, kv) for name, kv in self.kept]
        return parts

    def to_ini(self):
        parts = self.to_ini_blocks()
        return ("\n\n".join(parts).rstrip("\n") + "\n") if parts else ""

    # -- status ----------------------------------------------------------
    def is_empty(self):
        return not (self.wildcard or self.blocks or self.zones or self.kept)
