"""The shared ATLAS case document.

ATLAS runs its tools off one INI file (``ATLAS GPB BCB ICB`` reads the same
``input.ini``), so the GUI edits one document whose sections are routed to the
tool that owns them:

===========================  ==========================================
``[ATLAS-Parameters]``       global settings, shared by every tool
``[GPB-Phase<N>]``           a GPB phase            -> :mod:`gpbmodel`
``[BCB-Block<N>]``           a BCB block's faces    -> :mod:`bcmodel`
``[ICB-Block<N>]``           a block's initial state -> :mod:`icmodel`
a section named by an        an ICB zone            -> :mod:`icmodel`
ICB block's ``zone<n>``
anything else named          a BC definition        -> :mod:`bcmodel`
``[STB-*]``, ``[MDB-*]``,    not edited here yet: kept verbatim so saving
``[KAnT-*]``                 a shared case never drops another tool's setup
===========================  ==========================================

Writing composes the file in tool order (parameters, GPB, BCB, ICB, untouched
sections last), which is the order the tools themselves run in.

No Qt here: the document can be built and serialised headlessly.
"""

from __future__ import annotations

from collections import OrderedDict

from .bcmodel import BCBDocument, _parse_ini
from .gpbmodel import GPBDocument
from .icmodel import ICBDocument

# Sections owned by tools this GUI does not edit yet.  They are preserved
# verbatim, including key order, so a shared input.ini survives a round trip.
FOREIGN_PREFIXES = ("STB-", "MDB-", "KAnT-")
assert all(p in __import__("atlasgui.bcmodel", fromlist=["x"]).TOOL_SECTION_PREFIXES
           for p in FOREIGN_PREFIXES)


def is_foreign_section(name):
    return name.startswith(FOREIGN_PREFIXES)


class AtlasDocument:
    """One ATLAS case: global parameters + the per-tool documents."""

    def __init__(self):
        self.gpb = GPBDocument()
        self.bcb = BCBDocument()
        self.icb = ICBDocument()
        self.foreign = []          # [(section_name, [(key, value), ...])]

    # ``[ATLAS-Parameters]`` is stored once, on the BCB document, which has
    # always owned it; both panels read and write it through here.
    @property
    def parameters(self):
        return self.bcb.parameters

    @parameters.setter
    def parameters(self, value):
        self.bcb.parameters = value

    # -- parsing ---------------------------------------------------------
    @classmethod
    def from_ini(cls, text):
        doc = cls()
        sections = _parse_ini(text)

        doc.parameters = OrderedDict()
        for name, kv in sections:
            if name == "ATLAS-Parameters":
                for k, v in kv:
                    doc.parameters[k] = v

        doc.gpb = GPBDocument.from_sections(sections)
        doc.bcb = BCBDocument.from_sections(sections)
        doc.icb = ICBDocument.from_sections(sections)
        doc.foreign = [(n, list(kv)) for n, kv in sections if is_foreign_section(n)]
        return doc

    # -- serialisation ---------------------------------------------------
    def to_ini(self):
        parts = []
        params = OrderedDict(
            (k, v) for k, v in self.parameters.items() if str(v).strip() != ""
        )
        if params:
            block = ["[ATLAS-Parameters]"]
            block += [f"{k} = {v}" for k, v in params.items()]
            parts.append("\n".join(block))

        parts.extend(self.gpb.to_ini_blocks())
        parts.extend(self.bcb.to_ini_blocks())
        parts.extend(self.icb.to_ini_blocks())

        for name, kv in self.foreign:
            block = [f"[{name}]"] + [f"{k} = {v}" for k, v in kv]
            parts.append("\n".join(block))

        return "\n\n".join(parts).rstrip("\n") + "\n" if parts else ""

    def section_names(self):
        """Every section name the file holds, whichever tool owns it: a new
        section must take none of them (INI readers keep the first copy of a
        section declared twice, so a clash would lose one of the two)."""
        names = {"ATLAS-Parameters"}
        names.update(f"GPB-Phase{i + 1}" for i in range(len(self.gpb.phases)))
        names.update(f"BCB-Block{b + 1}" for b in range(self.bcb.nblocks))
        if self.bcb.wildcard:
            names.add("BCB-Block*")
        names.update(self.bcb.sections)
        names.update(self.icb.section_names())
        names.update(name for name, _kv in self.foreign)
        return names

    def strict_keys(self):
        """``strict-keys`` of [ATLAS-Parameters]: True unless set false, when
        the tools warn about a key they do not read instead of stopping."""
        value = str(self.parameters.get("strict-keys", "T")).strip()
        return value.upper() not in ("F", "FALSE", ".FALSE.", "NO", "0")

    # -- status ----------------------------------------------------------
    def summary(self):
        """``(n_phases, n_blocks)`` for the status bar."""
        return len(self.gpb.phases), self.bcb.nblocks
