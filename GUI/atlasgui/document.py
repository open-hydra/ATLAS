"""The shared ATLAS case document.

ATLAS runs its tools off one INI file (``ATLAS GPB BCB ICB`` reads the same
``input.ini``), so the GUI edits one document whose sections are routed to the
tool that owns them:

===========================  ==========================================
``[ATLAS-Parameters]``       global settings, shared by every tool
``[GPB-Phase<N>]``           a GPB phase            -> :mod:`gpbmodel`
``[BCB-Block<N>]``           a BCB block's faces    -> :mod:`bcmodel`
anything else named          a BC definition        -> :mod:`bcmodel`
``[ICB-*]``, ``[STB-*]``,    not edited here yet: kept verbatim so saving
``[MDB-*]``, ``[KAnT-*]``    a shared case never drops another tool's setup
===========================  ==========================================

Writing composes the file in tool order (parameters, GPB, BCB, untouched
sections last), which is the order the tools themselves run in.

No Qt here: the document can be built and serialised headlessly.
"""

from __future__ import annotations

from collections import OrderedDict

from .bcmodel import BCBDocument, _parse_ini
from .gpbmodel import GPBDocument

# Sections owned by tools this GUI does not edit yet.  They are preserved
# verbatim, including key order, so a shared input.ini survives a round trip.
FOREIGN_PREFIXES = ("ICB-", "STB-", "MDB-", "KAnT-")
assert all(p in __import__("atlasgui.bcmodel", fromlist=["x"]).TOOL_SECTION_PREFIXES
           for p in FOREIGN_PREFIXES)


def is_foreign_section(name):
    return name.startswith(FOREIGN_PREFIXES)


class AtlasDocument:
    """One ATLAS case: global parameters + the per-tool documents."""

    def __init__(self):
        self.gpb = GPBDocument()
        self.bcb = BCBDocument()
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

        for name, kv in self.foreign:
            block = [f"[{name}]"] + [f"{k} = {v}" for k, v in kv]
            parts.append("\n".join(block))

        return "\n\n".join(parts).rstrip("\n") + "\n" if parts else ""

    # -- status ----------------------------------------------------------
    def summary(self):
        """``(n_phases, n_blocks)`` for the status bar."""
        return len(self.gpb.phases), self.bcb.nblocks
