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

import glob
import math
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


def to_float(text):
    """The value of one INI number as ICB reads it (a Fortran list-directed
    read): ``70d+5``, ``0.20,`` (the comma ends the value) and ``2*20e-6`` (a
    repeat count) are numbers.  None when *text* is not a finite number."""
    token = str(text).strip()
    for separator in (",", "/"):
        token = token.split(separator, 1)[0].strip()
    count, star, rest = token.partition("*")
    if star:
        if not count.isdigit() or int(count) < 1:
            return None
        token = rest
    try:
        value = float(token.replace("d", "e").replace("D", "e"))
    except ValueError:
        return None
    return value if math.isfinite(value) else None


# ------------------------------------------------------- what a state gives
# The thermodynamic state of an ideal-gas zone is fixed by a pair; ICB fills
# the rest (T from T, from T0 and the Mach number, or from p / (R rho); p
# likewise).  A key given beyond the pair is not checked against it, so the
# editor offers the pairs and nothing else.
GAS_STATE_KEYS = ("p", "T", "p0", "T0", "rho")
GAS_PAIRS = OrderedDict([
    ("p-T", ("Static p and T", ("p", "T"))),
    ("p0-T0", ("Total p0 and T0", ("p0", "T0"))),
    ("p-T0", ("Static p, total T0", ("p", "T0"))),
    ("p0-T", ("Total p0, static T", ("p0", "T"))),
    ("p-rho", ("Static p and density", ("p", "rho"))),
    ("T-rho", ("Static T and density", ("T", "rho"))),
])
REAL_FLUID_PAIRS = OrderedDict([
    ("p-T", ("Pressure and temperature", ("p", "T"))),
    ("p-h", ("Pressure and enthalpy", ("p", "h"))),
])

# The velocity: three components, or a speed (Mach number for a gas, vel for a
# real fluid) along the flow angles alpha, beta.
SPEED_KEY = {"IG": "mach", "RF": "vel"}
COMPONENT_KEYS = ("u", "v", "w")
ANGLE_KEYS = ("alpha", "beta")

# Turbulence: the model follows from the keys given (src/common/config_shared.f90)
# unless nrans names it; each quantity is given specific or density-weighted.
TURBULENCE_MODELS = OrderedDict([(0, "Laminar"), (1, "Spalart-Allmaras"),
                                 (2, "k-omega"), (7, "Reynolds stress")])
TURBULENCE_SPECIFIC = {1: ("nuTilde",), 2: ("k", "omega"), 7: ("Rij", "omega")}
WEIGHTED_KEY = {"nuTilde": "rhoNuTilde", "k": "rhoK", "omega": "rhoOmega",
                "Rij": "rhoRij"}
TURBULENCE_KEYS = tuple(WEIGHTED_KEY) + tuple(WEIGHTED_KEY.values()) + ("nrans",)


def has_value_or_file(state, key):
    return state.has(key) or state.has(f"{key}-file")


def _clear_with_profile(state, keys):
    for key in keys:
        state.clear(key, f"{key}-file", f"{key}-direction")


def gas_pair(state, pairs=GAS_PAIRS):
    """The pair of *pairs* the state gives: the one its keys match exactly,
    else the one they overlap most (the first when none is given)."""
    keys = {k for k in GAS_STATE_KEYS + ("h",) if has_value_or_file(state, k)}
    for name, (_label, pair) in pairs.items():
        if set(pair) == keys:
            return name
    names = list(pairs)
    return max(names, key=lambda n: (len(set(pairs[n][1]) & keys), -names.index(n)))


def set_gas_pair(state, name, pairs=GAS_PAIRS):
    """Keep the keys of pair *name*, drop the other state keys of *pairs*."""
    keep = set(pairs[name][1])
    others = {k for _label, pair in pairs.values() for k in pair} - keep
    _clear_with_profile(state, sorted(others))


def _nonzero(state, key):
    """*key* gives a value other than 0 (a profile file counts as one)."""
    if state.has(key + "-file"):
        return True
    value = to_float(state.get(key)) if state.has(key) else None
    return value is not None and value != 0.0


def velocity_mode(state):
    """``components`` when u, v or w is given, else ``speed``."""
    return "components" if any(state.has(k) for k in COMPONENT_KEYS) else "speed"


def set_velocity_mode(state, mode, kind="IG"):
    if mode == "components":
        _clear_with_profile(state, (SPEED_KEY[kind],) + ANGLE_KEYS)
    else:
        state.clear(*COMPONENT_KEYS)


def turbulence_model(state):
    """The model ICB runs the state with: ``nrans`` when given, else the one
    its keys imply (0 = laminar)."""
    if state.has("nrans"):
        value = to_float(state.get("nrans"))
        return int(value) if value is not None else 0
    if state.has("Rij") or state.has("rhoRij"):
        return 7
    if any(state.has(k) for k in ("k", "omega", "rhoK", "rhoOmega")):
        return 2
    if state.has("nuTilde") or state.has("rhoNuTilde"):
        return 1
    return 0


def turbulence_weighted(state):
    """True when the state gives its turbulence density-weighted."""
    return any(state.has(k) for k in WEIGHTED_KEY.values())


def turbulence_keys(model, weighted):
    keys = TURBULENCE_SPECIFIC.get(model, ())
    return tuple(WEIGHTED_KEY[k] for k in keys) if weighted else keys


def set_turbulence(state, model, weighted):
    """Model *model* given in the form *weighted*: its keys stay (the ones of
    the other form are dropped, they mean another quantity), every other
    turbulence key goes, and ``nrans`` names the model."""
    keep = set(turbulence_keys(model, weighted))
    state.clear(*[k for k in TURBULENCE_KEYS if k not in keep])
    if model:
        state.set("nrans", str(model))


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

    def summary(self):
        """One line for a list: the mode, then the values that define it."""
        mode = self.mode
        parts = [MODES[mode]]
        if mode == "interpolate":
            parts.append(os.path.basename(self.get("old-solution")) or "no source yet")
        else:
            for key in ("p0", "T0", "p", "T", "rho", "h", "mach", "vel"):
                if self.has(key):
                    parts.append(f"{key} {self.get(key)}")
                elif self.has(f"{key}-file"):
                    parts.append(f"{key} profile")
            if len(parts) == 1:
                parts.append("no state yet")
        return "  ·  ".join(parts[:4])


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

    # -- phases ----------------------------------------------------------
    def blocks_listing_phase(self, name):
        return [b for b in self.all_blocks() if name in b.phases]

    def rename_phase(self, old, new):
        for block in self.blocks_listing_phase(old):
            block.phases = [new if n == old else n for n in block.phases]

    def drop_phase(self, name):
        for block in self.blocks_listing_phase(name):
            block.phases = [n for n in block.phases if n != name]

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

    # -- checks ----------------------------------------------------------
    def validate(self, nblocks=0, phases=(), strict=True):
        """``[(level, target, message)]``: what ICB would stop on (``error``)
        or report (``warning``), checked from the deck alone.  *target* is a
        block index or ``"*"``; *nblocks* the number of mesh blocks (0 when
        unknown); *phases* the :class:`PhaseInfo` of the case; *strict* the
        ``strict-keys`` of the case (F turns an unread key into a warning)."""
        phases = list(phases)
        issues = []
        indices = list(range(1, nblocks + 1)) if nblocks else list(self.blocks)
        for b in indices:
            if self.block(b) is None:
                issues.append(("error", b, (
                    f"Block {b} has no initial state: ICB stops on it. Give the "
                    "block a state, or give All blocks one")))
        known = {p.name for p in phases}
        for block in self.all_blocks():
            where = block_label(block.index)
            target = block.index
            if not block.is_wildcard and nblocks and block.index > nblocks:
                issues.append(("warning", target, (
                    f"{where}: the mesh has {nblocks} block(s), so ICB never "
                    "reads this section")))
            if phases:
                for name in block.phases:
                    if name not in known:
                        issues.append(("error", target, (
                            f"{where}: phase '{name}' is not a phase of the case")))
            if block.is_split:
                stray = block.state_keys()
                if stray:
                    issues.append(("error", target, (
                        f"{where}: a block split into zones takes its state from "
                        f"them, so {', '.join(stray[:4])} must move into a zone")))
                for ref in block.zone_refs():
                    if ref.section not in self.zones:
                        issues.append(("error", target, (
                            f"{where}: zone [{ref.section}] has no section")))
                        continue
                    issues += _state_issues(self.zones[ref.section], block, phases,
                                            f"{where}, zone [{ref.section}]", target,
                                            strict)
            else:
                issues += _state_issues(block, block, phases, where, target, strict)
        sections = self.all_blocks()
        if phases and sections:
            for phase in phases:
                if not any(not s.phases or phase.name in s.phases for s in sections):
                    issues.append(("warning", None, (
                        f"phase '{phase.label}' is built by no block: ICB writes no "
                        "initial field for it")))
        return issues


def block_label(index):
    return "All blocks" if index == "*" else f"Block {index}"


# -------------------------------------------------------------- the phases
# Header of <name>phase.txt -> the kind ICB reads (src/common/read_phase.f90).
PHASE_FILE_KINDS = (("condensed-dispersed", "DP"), ("liquid-dispersed", "DP"),
                    ("solid-dispersed", "DP"), ("solid-bulk", "SP"),
                    ("ideal-gas", "IG"), ("real-fluid", "RF"))
OUTPUT_DIR = "fromATLAStoSolver"


class PhaseInfo:
    """A phase ICB can build.

    * ``name``        -- what a block's ``phase`` key calls it: the prefix of
      its ``<name>-phase.txt`` (``""`` for an unnamed ``phase.txt``);
    * ``kind``        -- IG, RF, SP or DP;
    * ``entries``     -- the species of a gas, the materials of a solid or a
      dispersed phase, the fluid of a real fluid; empty when not known;
    * ``populations`` -- per material of a dispersed phase, its number of
      populations (the per-population keys count them);
    * ``source``      -- the phase file the entries come from, or ``"deck"``.
    """

    def __init__(self, name, kind, entries=(), populations=(), source=""):
        self.name = name
        self.kind = kind
        self.entries = list(entries)
        self.populations = list(populations)
        self.source = source

    def __repr__(self):
        return f"PhaseInfo({self.name!r}, {self.kind!r}, {self.entries!r})"

    @property
    def label(self):
        return self.name or "(unnamed)"

    def population_count(self):
        return sum(self.populations) if self.populations else len(self.entries)


def phase_name_of_file(path):
    """``gas`` for ``gas-phase.txt``, ``""`` for ``phase.txt``."""
    base = os.path.basename(path)
    return base[:-len("phase.txt")].rstrip("-")


def read_phase_file(path):
    """``(kind, entries, populations)`` of a ``<name>phase.txt``, or None
    when the file cannot be read or its header names no kind."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.strip() for line in handle if line.strip()]
    except OSError:
        return None
    if not lines:
        return None
    header = lines[0].lower()
    kind = next((k for word, k in PHASE_FILE_KINDS if word in header), None)
    if kind is None:
        return None
    entries, populations = [], []
    for line in lines[1:]:
        tokens = line.split()
        entries.append(tokens[0])
        if kind == "DP":
            count = to_float(tokens[1]) if len(tokens) > 1 else None
            populations.append(int(count) if count and count >= 1 else 1)
    return kind, entries, populations


def _deck_entries(phase, kind, species_lookup=None):
    """What a GPB phase of the deck says of its entries, before GPB runs."""
    if kind == "IG":
        names = split_values(phase.get("species")) + split_values(phase.get("add-species"))
        if not names and species_lookup is not None:
            names = list(species_lookup(phase) or [])
        return names, []
    if kind == "RF":
        return split_values(phase.get("fluid"))[:1], []
    entries = phase.entries()
    populations = []
    if kind == "DP":
        for value in phase.column("groups", len(entries)):
            count = to_float(value)
            populations.append(int(count) if count and count >= 1 else 1)
    return entries, populations


def case_phases(gpb=None, case_dir=None, species_lookup=None):
    """The phases ICB builds for the case, the deck's GPB phases first.

    ICB reads the ``*phase.txt`` files of the case directory; GPB writes them
    into ``fromATLAStoSolver/``, which is read next.  A GPB phase of the deck
    takes its kind from the deck and its entries from its built file when
    the file has the same kind (a mechanism's species are only known once
    GPB has run), else from the deck's own lists -- or from
    *species_lookup(phase)* for a gas without one.  A phase file the deck
    does not describe follows.
    """
    files = OrderedDict()
    if case_dir:
        for directory in (case_dir, os.path.join(case_dir, OUTPUT_DIR)):
            for path in sorted(glob.glob(os.path.join(directory, "*phase.txt"))):
                name = phase_name_of_file(path)
                parsed = None if name in files else read_phase_file(path)
                if parsed:
                    files[name] = (path,) + parsed
    phases = OrderedDict()
    for phase in (gpb.phases if gpb is not None else []):
        name = phase.name
        if name in phases:
            continue
        kind = kind_of(phase.type)
        if name in files and files[name][1] == kind:
            path, _kind, entries, populations = files[name]
            phases[name] = PhaseInfo(name, kind, entries, populations, path)
        else:
            entries, populations = _deck_entries(phase, kind, species_lookup)
            phases[name] = PhaseInfo(name, kind, entries, populations, "deck")
    for name, (path, kind, entries, populations) in files.items():
        if name not in phases:
            phases[name] = PhaseInfo(name, kind, entries, populations, path)
    return list(phases.values())


def block_phases(block, phases):
    """The phases *block* builds: those its ``phase`` key names, or all."""
    names = block.phases if block is not None else []
    return [p for p in phases if not names or p.name in names]


def block_kinds(block, phases):
    """The kinds *block* builds.  Without any phase file ICB assumes one
    unnamed ideal-gas phase."""
    if not phases:
        return {"IG"}
    return {p.kind for p in block_phases(block, phases)}


def gas_species(block, phases):
    """The species of the gases *block* builds, or None when one of them
    has species the GUI does not know."""
    gases = [p for p in block_phases(block, phases) if p.kind == "IG"]
    if not gases or any(not p.entries for p in gases):
        return None
    species = []
    for gas in gases:
        species += [s for s in gas.entries if s not in species]
    return species


# --------------------------------------------------------- state checks
# Keys whose value is a number (or, for the per-population keys, numbers).
NUMERIC_KEYS = (("mach", "p0", "T0", "p", "T", "rho", "h", "vel")
                + ANGLE_KEYS + COMPONENT_KEYS + ("un",) + TURBULENCE_KEYS
                + ("old-block-id", "theta", "nz", "nozzle-threshold",
                   "eq-CEA-section", "krho", "kT", "Pp", "dp", "rp", "neuler"))
YSUM_TOL = 1.0e-3      # ICB renormalises a composition within this, refuses beyond
YSUM_EPS = 1.0e-12     # rounding of decimal constants, renormalised in silence
POSITIVE_KEYS = ("p", "T", "p0", "T0", "rho")    # ICB refuses a state that is not physical

# Keys of earlier decks, or names that are not ICB's, with what to write
# instead (docs/user-guide/icb/ic-strategies.md, "Keys of pre-2026 decks").
RENAMED_KEYS = {
    "oldsolution": "old-solution", "law": "interpolation-law",
    "oldid": "old-block-id", "CEA-CEAfile": "eq-CEA-file", "CEA-of": "eq-CEA-file",
    "CEA-section": "eq-CEA-section", "kappa": "k (or rhoK)",
    "nut": "nuTilde (the Spalart-Allmaras variable; the eddy viscosity is not an input)",
    "mut": "nuTilde (the Spalart-Allmaras variable; the eddy viscosity is not an input)",
}


def is_known_key(key):
    """True when ICB reads *key* in a block or zone section."""
    if is_structural(key) or species_key_pattern(key):
        return True
    tables = [BLOCK_TABLE, COMPOSITION_TABLE] + list(KIND_TABLES.values())
    return any(key in REFERENCE.get(table, {}) for table in tables)


def _state_issues(state, block, phases, where, target, strict=True):
    issues = []

    def add(level, text):
        issues.append((level, target, f"{where}: {text}"))

    def given(key):
        return has_value_or_file(state, key)

    kinds = block_kinds(block, phases)
    mode = state.mode
    icb_type = state.get("type").strip()
    allowed = ICB_TYPES if state is block else ICB_TYPES[:4]
    if icb_type and icb_type not in allowed:
        add("error", f"type = {icb_type} is not an ICB type ({', '.join(allowed)})")
    for key, value in state.params.items():
        if SCHEMA_FOUND and not is_known_key(key):
            hint = RENAMED_KEYS.get(key)
            add("error" if strict else "warning",
                f"ICB reads no key {key}" + (f": write {hint}" if hint else ""))
        if key in NUMERIC_KEYS or species_key_pattern(key) == "yspecies":
            tokens = split_values(value) or [""]
            if any(to_float(t) is None for t in tokens):
                add("error", f"{key} = {value} is not a number")
            elif key in POSITIVE_KEYS and to_float(tokens[0]) <= 0:
                add("error", f"{key} = {value}: the state is not physical")
    for key in ("nozzle-direction", "interpolation-law"):
        choices = allowed_values(key, "IG")
        if state.has(key) and choices and state.get(key) not in choices:
            add("error", f"{key} = {state.get(key)} is not one of {', '.join(choices)}")

    if mode == "nozzle" and "IG" not in kinds:
        add("error", "the nozzle law builds an ideal gas, and the block builds none")
    if mode == "interpolate" and not state.get("old-solution"):
        add("error", "an interpolation needs the old solution (old-solution)")

    if "IG" in kinds and mode == "nozzle":
        missing = [k for k in ("p0", "T0") if not given(k)]
        if missing:
            add("error", f"the nozzle law starts from the plenum: give {' and '.join(missing)}")
    elif "IG" in kinds and mode == "uniform":
        t_ok = given("T") or given("T0") or (given("p") and given("rho"))
        p_ok = given("p") or given("p0") or (given("T") and given("rho"))
        if not (t_ok and p_ok):
            add("error", "the gas state needs a pair: p and T, p0 and T0, or a "
                         "density with p or T")
    if "IG" in kinds and _nonzero(state, "mach") and \
            any(_nonzero(state, k) for k in COMPONENT_KEYS):
        add("error", "mach and u, v, w both give the speed: ICB stops on it. Give the "
                     "speed by mach (with the angles) or by u, v, w")
    if "IG" in kinds and mode != "interpolate":
        _composition_issues(state, gas_species(block, phases), add)

    if "RF" in kinds and mode != "interpolate":
        if not (given("p") and (given("T") or given("h"))):
            add("error", "the real-fluid state needs p and T, or p and h")
    if "RF" in kinds:
        specific = [k for k in WEIGHTED_KEY if state.has(k)]
        if specific:
            add("error", f"{', '.join(specific)}: a real-fluid table carries no "
                         f"density, give {', '.join(WEIGHTED_KEY[k] for k in specific)}")
    if "SP" in kinds and mode != "interpolate" and not given("T"):
        add("error", "the solid needs its temperature T")
    if "DP" in kinds and mode != "interpolate":
        if not (state.has("dp") or state.has("rp")):
            add("error", "the dispersed phase needs its particle size, dp or rp")
        krho = [to_float(v) for v in split_values(state.get("krho"))]
        if any(krho) and "IG" not in kinds:
            add("error", "krho derives the dispersed state from the gas of the "
                         "block, and the block builds none")

    for specific, weighted in WEIGHTED_KEY.items():
        if state.has(specific) and state.has(weighted):
            add("error", f"{specific} and {weighted} give one quantity twice")
    model = turbulence_model(state)
    if mode != "interpolate" and model in TURBULENCE_SPECIFIC:
        missing = [k for k in TURBULENCE_SPECIFIC[model]
                   if not (state.has(k) or state.has(WEIGHTED_KEY[k]))]
        if missing:
            level = "warning" if model == 1 else "error"
            add(level, f"the {TURBULENCE_MODELS[model]} model needs "
                       f"{' and '.join(missing)} (or "
                       f"{' and '.join(WEIGHTED_KEY[k] for k in missing)})")
    return issues


def _composition_issues(state, species, add):
    """The mass fractions of a gas state; *species* None when not known."""
    if state.get("eq-CEA-file"):
        return
    constants = state.mass_fractions()
    profiles = [species_of_key(k) for k in state.species_keys() if k.endswith("-file")]
    named = list(constants) + profiles
    if species is not None:
        unknown = [s for s in named if s not in species]
        if unknown:
            add("error", f"the gas declares no species {', '.join(unknown)}")
        if len(species) <= 1:
            return
    if not named:
        if species is not None:
            add("error", "no composition: give the mass fractions (y<species>) "
                         "or a CEA equilibrium")
        return
    if profiles:
        return                       # ICB checks the sum cell by cell
    values = [to_float(v) for v in constants.values()]
    if any(v is None for v in values):
        return                       # reported as not a number
    if any(v < 0 or v > 1 for v in values):
        add("error", "a mass fraction lies outside [0, 1]")
    total = sum(values)
    if abs(1 - total) > YSUM_TOL + YSUM_EPS:
        add("error", f"the mass fractions sum to {total:.6g}: they must sum to "
                     "1 within 1e-3")
    elif abs(1 - total) > YSUM_EPS:
        add("warning", f"the mass fractions sum to {total:.6g}: ICB renormalises them")
