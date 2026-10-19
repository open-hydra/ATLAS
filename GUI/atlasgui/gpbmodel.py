"""Data model for the GPB part of an ATLAS case.

A GPB deck is a run of ``[GPB-Phase1]``, ``[GPB-Phase2]``, ... sections, each
one a flat list of ``key = value`` lines whose meaning depends on the phase
``type``.  :class:`GPBPhase` keeps those raw lines as the source of truth -- a
key the GUI has no widget for is still kept and written back -- and adds the
structure the editor needs on top:

* **token lists**: most condensed/solid keys hold one value per material
  (``rho = 1000 2500``), and the fixed-gas keys one per species; the editor
  shows them as a table and reads them back through :meth:`GPBPhase.column`.
* **composition sources**: the ideal-gas phase can take its species from a
  mechanism, a Cantera phase file, a CEA or Cantera equilibrium, a prescribed
  mixture or an explicit list, and those are combinable; each source is the
  presence of its keys (:data:`GAS_SOURCES`).

The schema (defaults, allowed values, one-line descriptions) is read from
GPB's own ``src/GPB/input_registry.py``, so the GUI cannot drift from the tool.

No Qt here: the model can be built and serialised headlessly.
"""

from __future__ import annotations

import os
import re
from collections import OrderedDict

# --------------------------------------------------------------- the schema
_HERE = os.path.dirname(os.path.abspath(__file__))
ATLAS_ROOT = os.path.abspath(os.path.join(_HERE, os.pardir, os.pardir))
_REGISTRY_PATH = os.path.join(ATLAS_ROOT, "src", "GPB", "input_registry.py")


def _load_registry(path=_REGISTRY_PATH):
    """Read GPB's input registry from its source (it has no GPB dependency).

    The file is compiled into a namespace of its own rather than imported, so
    loading the schema never writes a ``__pycache__`` into the source tree.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            source = handle.read()
        namespace = {"__name__": "_gpb_input_registry", "__file__": path}
        # dont_inherit: this module's "from __future__ import annotations"
        # must not reach the registry, whose dataclass resolves its fields
        # through sys.modules and would not find this synthetic namespace.
        exec(compile(source, path, "exec", dont_inherit=True), namespace)
        return list(namespace["REGISTRY_ENTRIES"])
    except Exception:                                   # pragma: no cover
        return []


REGISTRY = _load_registry()
SCHEMA_FOUND = bool(REGISTRY)

# key -> (allowed[], default, description, group); later groups do not override
# an earlier definition of the same key (Tmin/Tmax appear more than once).
KEY_INFO = OrderedDict()
for _e in REGISTRY:
    # The registry's "allowed" column holds either a list of names or a
    # numeric constraint such as ">0" or ">=2"; only the first is a choice.
    _raw = (_e.allowed or "").strip()
    _is_constraint = _raw[:1] in ("<", ">", "=")
    _choices = [] if _is_constraint else [a for a in _raw.split(",") if a]
    if _e.name in KEY_INFO:
        # The same key name under two sections (thermo of a gas and of a
        # condensed phase, which take different databases): the editor is keyed
        # by name, so it offers the union -- warning on a value no section
        # accepts, never on one that this phase's section does.
        _info = KEY_INFO[_e.name]
        for _choice in _choices:
            if _choice not in _info["allowed"]:
                _info["allowed"].append(_choice)
        continue
    KEY_INFO[_e.name] = {
        "allowed": _choices,
        "constraint": _raw if _is_constraint else "",
        "default": _e.default,
        "description": _e.description,
        "group": _e.section,
        "required": _e.required,
    }


def allowed_values(key):
    info = KEY_INFO.get(key)
    return list(info["allowed"]) if info else []


def constraint_of(key):
    """Numeric constraint of *key* (``">0"``, ``">=2"``, ...), or ``""``."""
    info = KEY_INFO.get(key)
    return info["constraint"] if info else ""


def describe(key):
    info = KEY_INFO.get(key)
    return info["description"] if info else ""


def default_of(key):
    info = KEY_INFO.get(key)
    return info["default"] if info else ""


# ---------------------------------------------------------------- phase types
# (value, label, family, blurb)
PHASE_TYPES = [
    ("ideal-gas", "Ideal gas", "gas",
     "Thermally- or calorically-perfect gas: mechanisms, databases, equilibrium."),
    ("heavy-gas", "Heavy gas", "gas",
     "Ideal-gas workflow with molecular-weight scaling, for a carrier in "
     "equilibrium with a condensed phase."),
    ("condensed-dispersed", "Condensed dispersed", "condensed",
     "Liquid droplets or solid particles carried by a gas."),
    ("liquid-dispersed", "Liquid dispersed", "condensed",
     "Dispersed liquid phase."),
    ("solid-dispersed", "Solid dispersed", "condensed",
     "Dispersed solid phase."),
    ("solid", "Solid", "solid",
     "Walls and structural materials for conjugate heat transfer."),
    ("solid-bulk", "Solid (bulk)", "solid", "Synonym of solid."),
    ("real-fluid", "Real fluid", "real-fluid",
     "High-pressure / supercritical single fluid tabulated on a (p, h) grid."),
]
TYPE_LABEL = {t: label for t, label, _f, _b in PHASE_TYPES}
TYPE_FAMILY = {t: family for t, _l, family, _b in PHASE_TYPES}
TYPE_BLURB = {t: blurb for t, _l, _f, blurb in PHASE_TYPES}
DEFAULT_TYPE = "ideal-gas"


def family_of(phase_type):
    return TYPE_FAMILY.get((phase_type or "").strip(), "gas")


# ------------------------------------------------------- ideal-gas composition
# Each source is "on" when any of its keys is present.  GPB combines them
# (a mechanism plus extra species, an equilibrium compared against a
# mechanism, ...), so these are checkboxes and not a single choice.
GAS_SOURCES = OrderedDict([
    ("mechanism", {
        "label": "Finite-rate mechanism",
        "blurb": "Species and reactions from a Cantera mechanism file.",
        "keys": ["reactions"],
    }),
    ("phase-file", {
        "label": "Cantera phase file",
        "blurb": "Full import of a yaml phase: thermo, transport and reactions "
                 "come from the file (thermo/transport/reactions are ignored).",
        "keys": ["phase"],
    }),
    ("cea", {
        "label": "CEA equilibrium",
        "blurb": "Composition from a CEA input file; thermo is NASA9.",
        "keys": ["CEA-file", "CEA-section"],
    }),
    ("cantera-eq", {
        "label": "Cantera equilibrium",
        "blurb": "Composition from a Cantera equilibrium run of a fuel/oxidizer pair.",
        "keys": ["eq-of", "eq-pressure", "eq-fuel", "eq-oxidizer",
                 "eq-fuel-T", "eq-oxidizer-T"],
    }),
    ("mixture", {
        "label": "Prescribed mixture",
        "blurb": "One species standing for a mixture of known composition.",
        "keys": ["mixture", "mixture-name"],
    }),
    ("species", {
        "label": "Explicit species",
        "blurb": "A species list written by hand, optionally with constant "
                 "properties (calorically-perfect gas).",
        "keys": ["species", "add-species"],
    }),
])

# Per-species constant properties of a calorically-perfect gas.
FIXED_GAS_COLUMNS = [
    ("cp", "cp [J/kg/K]"), ("cv", "cv [J/kg/K]"), ("gamma", "gamma"),
    ("R", "R [J/kg/K]"), ("mw", "mw [kg/kmol]"), ("mil", "mu [Pa s]"),
    ("kl", "k [W/m/K]"), ("Pr", "Pr"),
]

# Per-material columns of a condensed/solid phase: property keys first, then
# the per-material solver models (edited in their own dialog).
MATERIAL_COLUMNS = [
    ("groups", "groups"), ("rho", "rho [kg/m3]"), ("cp", "cp [J/kg/K]"),
    ("k", "k [W/m/K]"), ("h0", "h0 [J/kg]"),
    ("psat-vapour", "psat vapour"), ("psat-liquid", "psat liquid"),
]
MODEL_COLUMNS = [
    ("evaporation", "evaporation"), ("liquid-conduction", "liquid-conduction"),
    ("interface", "interface"), ("boiling", "boiling"),
    ("combustion", "combustion"), ("solidification", "solidification"),
    ("alpha-e", "alpha-e"), ("k-liq", "k-liq [W/m/K]"), ("mu-liq", "mu-liq [Pa s]"),
    ("K-burn", "K-burn"), ("n-burn", "n-burn"), ("X-eff", "X-eff"),
    ("beta-part", "beta-part"), ("xi-cap", "xi-cap"), ("T-ign", "T-ign [K]"),
    ("q-comb", "q-comb [J/kg]"), ("T-melt", "T-melt [K]"), ("h-fus", "h-fus [J/kg]"),
    ("T-nuc", "T-nuc [K]"), ("cp-solid", "cp-solid [J/kg/K]"),
]
MATERIAL_KEYS = [k for k, _ in MATERIAL_COLUMNS] + [k for k, _ in MODEL_COLUMNS]

THERMO_DATABASES = ["NASA7", "NASA9", "Burcat"]
CONDENSED_THERMO = ["NASA7", "NASA9", "Burcat", "SP-database"]
TRANSPORT_SOURCES = ["CEA", "cantera"]
REAL_FLUID_MODELS = ["coolprop", "redlich-kwong", "peng-robinson"]
MODELING = ["lagrangian", "eulerian"]

BOOL_TRUE = ("true", "yes", "on", "1", "t")
BOOL_FALSE = ("false", "no", "off", "0", "f")


def split_tokens(value):
    """Split a space-separated INI value, keeping ``{...}`` groups together."""
    if not value:
        return []
    text = str(value).strip()
    if "{" in text:
        return [t.strip() for t in re.findall(r"\{[^}]*\}|\S+", text) if t.strip()]
    return text.split()


def join_tokens(tokens):
    return " ".join(str(t).strip() for t in tokens if str(t).strip() != "")


def parse_mixture(value):
    """``{N2: 75.4} {O2: 23.3}`` -> ``[(species, amount), ...]``."""
    out = []
    for token in re.findall(r"\{([^}]*)\}", str(value or "")):
        if ":" in token:
            name, amount = token.split(":", 1)
            out.append((name.strip(), amount.strip()))
        elif token.strip():
            out.append((token.strip(), ""))
    return out


def format_mixture(rows):
    return " ".join(
        "{%s: %s}" % (name.strip(), amount.strip())
        for name, amount in rows if str(name).strip()
    )


class GPBPhase:
    """One ``[GPB-Phase<N>]`` section."""

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

    def bool_of(self, key, default=False):
        raw = str(self.get(key, "")).strip().lower()
        if raw in BOOL_TRUE:
            return True
        if raw in BOOL_FALSE:
            return False
        return default

    # -- identity --------------------------------------------------------
    @property
    def type(self):
        return (self.get("type") or DEFAULT_TYPE).strip()

    @type.setter
    def type(self, value):
        self.set("type", value)

    @property
    def family(self):
        return family_of(self.type)

    @property
    def name(self):
        return self.get("name").strip()

    @name.setter
    def name(self, value):
        self.set("name", value)

    def display_name(self, index):
        return self.name or f"Phase{index + 1}"

    # -- token columns ---------------------------------------------------
    def entries(self):
        """The rows a per-entry key applies to: materials, or species."""
        if self.family in ("condensed", "solid"):
            return split_tokens(self.get("material")) or []
        return split_tokens(self.get("species")) or []

    def column(self, key, nrows=None):
        """Values of a per-entry key, padded to *nrows* (a single value is
        broadcast by GPB, and shown broadcast here too)."""
        tokens = split_tokens(self.get(key))
        if nrows is None:
            return tokens
        if len(tokens) == 1 and nrows > 1:
            tokens = tokens * nrows
        return (tokens + [""] * nrows)[:nrows]

    def set_column(self, key, values):
        """Write a per-entry key; all-equal values collapse to the single
        value GPB broadcasts, and an all-empty column removes the key."""
        values = [str(v).strip() for v in values]
        if not any(values):
            self.params.pop(key, None)
            return
        if len(set(values)) == 1:
            self.set(key, values[0])
            return
        self.set(key, join_tokens(values))

    # -- ideal-gas composition ------------------------------------------
    def sources(self):
        """The composition sources currently switched on."""
        return [
            name for name, spec in GAS_SOURCES.items()
            if any(self.has(k) for k in spec["keys"])
        ]

    def has_source(self, name):
        return any(self.has(k) for k in GAS_SOURCES[name]["keys"])

    def drop_source(self, name):
        self.clear(*GAS_SOURCES[name]["keys"])

    def is_fixed_gas(self):
        """Calorically-perfect gas: species with constant properties."""
        return any(self.has(k) for k, _ in FIXED_GAS_COLUMNS)

    # -- summary ---------------------------------------------------------
    def summary(self):
        """One line describing the phase, for the phase list."""
        family = self.family
        if family == "real-fluid":
            fluid = self.get("fluid") or "no fluid"
            return f"{fluid} · {self.get('model') or 'coolprop'}"
        if family in ("condensed", "solid"):
            materials = self.entries()
            if not materials:
                return "no material"
            head = ", ".join(materials[:3])
            if len(materials) > 3:
                head += f", +{len(materials) - 3}"
            return head
        bits = []
        if self.has("phase"):
            bits.append(self.get("phase"))
        if self.has("reactions"):
            bits.append(self.get("reactions"))
        if self.has("CEA-file"):
            bits.append("CEA equilibrium")
        if self.has("eq-fuel") or self.has("eq-of"):
            bits.append("Cantera equilibrium")
        if self.has("mixture"):
            bits.append(self.get("mixture-name") or "mixture")
        if self.has("species") or self.has("add-species"):
            bits.append(join_tokens(
                split_tokens(self.get("species")) +
                split_tokens(self.get("add-species"))))
        return " · ".join(b for b in bits if b) or "empty phase"

    def clone(self):
        return GPBPhase(self.params)


class GPBDocument:
    """The ordered list of GPB phases of a case."""

    def __init__(self, phases=None):
        self.phases = list(phases or [])

    # -- structure -------------------------------------------------------
    def add_phase(self, phase=None, index=None):
        phase = phase or GPBPhase([("type", DEFAULT_TYPE)])
        if index is None:
            self.phases.append(phase)
        else:
            self.phases.insert(index, phase)
        return phase

    def remove_phase(self, index):
        if 0 <= index < len(self.phases):
            self.phases.pop(index)

    def move_phase(self, index, delta):
        target = index + delta
        if 0 <= index < len(self.phases) and 0 <= target < len(self.phases):
            self.phases[index], self.phases[target] = (
                self.phases[target], self.phases[index])
            return target
        return index

    def names(self):
        """Display names: an unnamed phase shows as ``Phase<N>``."""
        return [p.display_name(i) for i, p in enumerate(self.phases)]

    def phase_names(self):
        """The names a BCB block can list: BCB matches the phase's ``name``,
        so an unnamed phase has none and is left out."""
        return [p.name for p in self.phases if p.name]

    # -- parsing ---------------------------------------------------------
    @classmethod
    def from_sections(cls, sections):
        """Build from ``[(section_name, [(key, value), ...]), ...]``."""
        numbered = []
        for name, kv in sections:
            match = re.fullmatch(r"GPB-Phase(\d+)", name.strip())
            if match:
                numbered.append((int(match.group(1)), GPBPhase(kv)))
        numbered.sort(key=lambda item: item[0])
        return cls([phase for _n, phase in numbered])

    @classmethod
    def from_ini(cls, text):
        from .bcmodel import _parse_ini
        return cls.from_sections(_parse_ini(text))

    # -- serialisation ---------------------------------------------------
    def to_ini_blocks(self):
        blocks = []
        for i, phase in enumerate(self.phases):
            lines = [f"[GPB-Phase{i + 1}]"]
            for key, value in phase.params.items():
                if str(key).strip() == "":
                    continue
                lines.append(f"{key} = {value}")
            blocks.append("\n".join(lines))
        return blocks

    def to_ini(self):
        return ("\n\n".join(self.to_ini_blocks()).rstrip("\n") + "\n") \
            if self.phases else ""

    # -- validation ------------------------------------------------------
    def validate(self):
        """Return ``[(level, phase_index_or_None, message), ...]``.

        Checks what the GUI can see without running GPB: required keys,
        allowed values, per-entry value counts and the temperature range.
        """
        issues = []
        seen_names = {}
        for i, phase in enumerate(self.phases):
            tag = phase.display_name(i)
            family = phase.family

            if phase.type not in TYPE_LABEL:
                issues.append(("error", i, f"{tag}: unknown type '{phase.type}'"))
            if phase.name:
                if phase.name in seen_names:
                    issues.append(("error", i, (
                        f"{tag}: name '{phase.name}' is also used by phase "
                        f"{seen_names[phase.name] + 1}; the output files would "
                        f"overwrite each other")))
                seen_names[phase.name] = i
            else:
                issues.append(("warning", i, (
                    f"{tag}: no name, so the output files get no prefix")))

            for key in ("Tmin", "Tmax"):
                raw = phase.get(key)
                if raw:
                    try:
                        value = float(raw)
                    except ValueError:
                        issues.append(("error", i, f"{tag}: {key} = {raw} is not a number"))
                        continue
                    if family != "real-fluid" and not float(value).is_integer():
                        issues.append(("error", i, (
                            f"{tag}: {key} = {raw} is not an integer number of "
                            f"kelvin (the tables have a 1 K step)")))
                    if value <= 0:
                        issues.append(("error", i, f"{tag}: {key} = {raw} is not above 0 K"))
            tmin, tmax = phase.get("Tmin"), phase.get("Tmax")
            try:
                if tmin and tmax and float(tmin) > float(tmax):
                    issues.append(("error", i, f"{tag}: Tmin is above Tmax"))
            except ValueError:
                pass

            for key, value in phase.params.items():
                allowed = allowed_values(key)
                if not (allowed and value) or key in MATERIAL_KEYS or key == "type":
                    continue
                raw = value.strip()
                if {a.lower() for a in allowed} == {"true", "false"}:
                    # GPB reads these with get_bool: true/yes/on/1/t, either case
                    if raw.lower() in BOOL_TRUE + BOOL_FALSE:
                        continue
                elif raw in allowed:
                    continue
                if raw not in allowed:
                    issues.append(("warning", i, (
                        f"{tag}: {key} = {value} is not one of "
                        f"{', '.join(allowed)}")))

            if family == "real-fluid":
                for key in ("fluid", "pmin", "pmax", "Tmin", "Tmax"):
                    if not phase.get(key):
                        issues.append(("error", i, f"{tag}: {key} is required for a real fluid"))
                try:
                    if phase.get("pmin") and phase.get("pmax") and \
                            float(phase.get("pmin")) > float(phase.get("pmax")):
                        issues.append(("error", i, f"{tag}: pmin is above pmax"))
                except ValueError:
                    issues.append(("error", i, f"{tag}: pmin/pmax are not numbers"))

            elif family in ("condensed", "solid"):
                materials = phase.entries()
                if not materials:
                    issues.append(("error", i, f"{tag}: no material"))
                nmat = len(materials)
                for key in MATERIAL_KEYS:
                    if not phase.has(key):
                        continue
                    count = len(split_tokens(phase.get(key)))
                    if count not in (1, nmat):
                        issues.append(("error", i, (
                            f"{tag}: {key} has {count} values for {nmat} "
                            f"material(s) (give 1 or {nmat})")))
                    allowed = allowed_values(key)
                    if allowed:
                        for token in split_tokens(phase.get(key)):
                            if token not in allowed:
                                issues.append(("error", i, (
                                    f"{tag}: {key} = {token} is not one of "
                                    f"{', '.join(allowed)}")))
                if phase.has("psat-liquid") and not phase.has("psat-vapour"):
                    issues.append(("error", i, (
                        f"{tag}: psat-liquid without psat-vapour")))
                thermo = phase.get("thermo")
                if thermo and thermo not in CONDENSED_THERMO:
                    issues.append(("error", i, (
                        f"{tag}: thermo = {thermo} is not one of "
                        f"{', '.join(CONDENSED_THERMO)}")))
                if not thermo and not phase.has("cp"):
                    issues.append(("info", i, (
                        f"{tag}: neither thermo nor cp: the NASA9 database is used")))
                if phase.has("psat-vapour") and family == "solid":
                    issues.append(("error", i, (
                        f"{tag}: psat-vapour is for dispersed phases only")))

            else:   # gas
                for source in phase.sources():
                    spec = GAS_SOURCES[source]
                    if not any(str(phase.get(k)).strip() for k in spec["keys"]):
                        issues.append(("warning", i, (
                            f"{tag}: {spec['label'].lower()} is switched on but "
                            f"empty")))
                if not phase.sources():
                    issues.append(("error", i, (
                        f"{tag}: no composition source (mechanism, phase file, "
                        f"equilibrium, mixture or species)")))
                if phase.has("phase"):
                    ignored = [k for k in ("thermo", "transport", "reactions")
                               if phase.has(k)]
                    if ignored:
                        issues.append(("warning", i, (
                            f"{tag}: phase = {phase.get('phase')} ignores "
                            f"{', '.join(ignored)}")))
                if phase.is_fixed_gas():
                    species = split_tokens(phase.get("species"))
                    given = [k for k, _ in FIXED_GAS_COLUMNS
                             if phase.has(k) and k in ("cp", "cv", "gamma", "R", "mw")]
                    if len(given) < 2:
                        issues.append(("error", i, (
                            f"{tag}: a calorically-perfect gas needs two of "
                            f"cp, cv, gamma, R, mw")))
                    for key, _label in FIXED_GAS_COLUMNS:
                        if phase.has(key):
                            count = len(split_tokens(phase.get(key)))
                            if species and count not in (1, len(species)):
                                issues.append(("error", i, (
                                    f"{tag}: {key} has {count} values for "
                                    f"{len(species)} species")))
                if phase.get("thermo") and phase.get("thermo") not in THERMO_DATABASES:
                    issues.append(("error", i, (
                        f"{tag}: thermo = {phase.get('thermo')} is not a database "
                        f"({', '.join(THERMO_DATABASES)})")))
                if phase.get("thermo") in ("NASA7", "Burcat") and phase.has("CEA-file"):
                    issues.append(("warning", i, (
                        f"{tag}: thermo = {phase.get('thermo')} is ignored with "
                        f"CEA-file (the CEA species use NASA9)")))
                if phase.name == "gas":
                    issues.append(("info", i, (
                        f"{tag}: the phase name 'gas' identifies no mechanism")))
        return issues
