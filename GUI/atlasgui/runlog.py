"""What the tools said: the errors and warnings of a run, each on what it names.

GPB, BCB and ICB print their errors and warnings as lines tagged ``[ERROR]``
and ``[WARNING]``; most name the section of the INI they are about --
``key rhoK of section [isoth]: unknown key``, ``composition of section
[injOX] ...``, ``[GPB-Phase1] FOO(L): not in nasa9.yaml``, ``block 1 has no
initial state: give a section [ICB-Block1]`` -- or a file a section names
(``table file Twall.dat: ...``).  :func:`messages` reads the lines of one tool
and gives a :class:`Message` per error or warning, placed on a target of the
GUI the way its own checks are, ``(stage, index)``:

* a section of the deck: ``[ATLAS-Parameters]`` (Case), ``[GPB-PhaseN]``,
  ``[BCB-Block*]``, a BC, ``[ICB-BlockN]``, ``[ICB-Block*]``, a zone of an ICB
  block -- the first section the message names, ``key ... of section [X]``
  first;
* else a file a section of the deck names, which is that section;
* else what the tool was building when it spoke: GPB announces each phase
  (``- Ideal-gas phase: gas``) and ICB each block (``- Initialization block
  n. = 2``) before the messages about it;
* else the phase files (``thermo file, thermo.dat not found``), which GPB
  makes, or the stage of the tool.

A message goes on over the lines indented under it (a hint, the values
involved); a Python traceback is one message, its last line; the same
message printed again (once per block, per cell) is one message with its
count.  A tool that fails without an error message gets one saying so.
No Qt here.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field

TOOL_STAGES = {"GPB": "gpb", "BCB": "bcb", "ICB": "icb"}

_TAG = re.compile(r"^\s*\[(ERROR|WARNING)\]\s*|^\s*(ERROR|WARNING)\s*:\s*")
_CRASH = re.compile(r"Fortran runtime error|^\s*forrtl: severe|Program received signal|"
                    r"Segmentation fault", re.I)
_OF_SECTION = re.compile(r"\bkeys? (\S+?)(?: and \S+?)? of section \[([^\]]+)\]")
_SECTION = re.compile(r"\bsection \[([^\]]+)\]")
_BRACKET = re.compile(r"\[([^\]\s][^\]]*)\]")
_BLOCK = re.compile(r"\bblock (?:n\. *= *)?(\d+)\b", re.I)
_GPB_PHASE = re.compile(r"^\s*- (?:Ideal-gas|Condensed-dispersed|Solid|Real-gas) phase:")
_ICB_BLOCK = re.compile(r"^\s*- Initialization block n\. *= *(\d+)")
_PHASE_FILES = re.compile(r"\b(?:phase|thermo|properties) file\b|\bphase files?\b", re.I)
_FILE_TOKEN = re.compile(r"[\w.+-]+\.\w{1,6}\b")
_CONTINUATION = 6          # a line indented this much under a message goes on with it


@dataclass
class Message:
    """One error or warning of a tool.

    ``target`` is ``(stage, index)`` as the GUI's checks have it; ``section``
    and ``key`` what the message names, when it does; ``lines`` the indexes of
    its lines in the tool's output (the first one is the message itself);
    ``count`` how many times the tool printed it."""
    tool: str
    level: str
    text: str
    target: tuple
    section: str | None = None
    key: str | None = None
    details: list = field(default_factory=list)
    lines: list = field(default_factory=list)
    count: int = 1

    @property
    def line(self):
        return self.lines[0] if self.lines else None


def target_of_section(doc, name, stage):
    """``(stage, index)`` of section *name* of *doc*; *stage* (the tool's)
    with no index when the deck has no such section."""
    if name == "ATLAS-Parameters":
        return ("case", None)
    match = re.fullmatch(r"GPB-Phase(\d+)", name)
    if match:
        return ("gpb", int(match.group(1)) - 1)
    if name.startswith("BCB-Block"):
        return ("bcb", None)
    if name == "ICB-Block*":
        return ("icb", "*")
    match = re.fullmatch(r"ICB-Block(\d+)", name)
    if match:
        return ("icb", int(match.group(1)))
    if doc is not None:
        if name in doc.bcb.sections:
            return ("bcb", name)
        if name in doc.icb.zones:
            for block in doc.icb.all_blocks():
                if any(ref.section == name for ref in block.zone_refs()):
                    return ("icb", (block.index, name))
            return ("icb", None)
    return (stage, None)


def _known_section(doc, name):
    if doc is None:
        return False
    if name == "ATLAS-Parameters" or re.fullmatch(r"(GPB-Phase|BCB-Block|ICB-Block)[\d*]+", name):
        return True
    return name in doc.section_names()


def _file_sections(doc):
    """``{file name: section}`` of the values of *doc* that name a file."""
    files = {}
    if doc is None:
        return files

    def add(section, params):
        for value in params.values():
            for token in str(value).split():
                name = os.path.basename(token)
                if "." in name:
                    files.setdefault(name, section)

    add("ATLAS-Parameters", doc.parameters)
    for index, phase in enumerate(doc.gpb.phases):
        add(f"GPB-Phase{index + 1}", phase.params)
    for name, section in doc.bcb.sections.items():
        add(name, section.params)
    for block in doc.icb.all_blocks():
        add("ICB-Block*" if block.index == "*" else f"ICB-Block{block.index}", block.params)
    for name, zone in doc.icb.zones.items():
        add(name, zone.params)
    return files


def locate(doc, tool, text, context=None):
    """``(target, section, key)`` of a message *text* of *tool*; *context*
    is the target of what the tool was building, or None."""
    stage = TOOL_STAGES.get(tool, "case")
    match = _OF_SECTION.search(text)
    if match:
        key, section = match.group(1), match.group(2)
        return target_of_section(doc, section, stage), section, key
    match = _SECTION.search(text)
    if match:
        return target_of_section(doc, match.group(1), stage), match.group(1), None
    for match in _BRACKET.finditer(text):
        if _known_section(doc, match.group(1)):
            return target_of_section(doc, match.group(1), stage), match.group(1), None
    files = _file_sections(doc)
    for token in _FILE_TOKEN.findall(text):
        section = files.get(os.path.basename(token))
        if section:
            return target_of_section(doc, section, stage), section, None
    if tool == "ICB":
        match = _BLOCK.search(text)
        if match:
            return _icb_block(doc, int(match.group(1))), None, None
    if context is not None:
        return context, None, None
    if _PHASE_FILES.search(text):
        return ("gpb", None), None, None
    return (stage, None), None, None


def _icb_block(doc, index):
    """The target of ICB block *index*: its section, else ``[ICB-Block*]``."""
    if doc is None or index in doc.icb.blocks or doc.icb.wildcard is None:
        return ("icb", index)
    return ("icb", "*")


def messages(tool, lines, doc=None, failed=False):
    """The :class:`Message` of every error and warning in *lines*, the output
    of *tool*, in the order printed (a repeated one where it first appears).
    *failed*: the tool ended with an error status, so a run without an error
    message gets one."""
    found = []
    seen = {}
    context = None
    phase = 0
    current = None
    n = 0
    while n < len(lines):
        line = lines[n]
        if tool == "GPB" and _GPB_PHASE.match(line):
            phase += 1
            context = ("gpb", phase - 1)
            current = None
        elif tool == "ICB" and _ICB_BLOCK.match(line):
            context = _icb_block(doc, int(_ICB_BLOCK.match(line).group(1)))
            current = None
        tag = _TAG.match(line)
        if line.startswith("Traceback (most recent call last)"):
            start = n
            n += 1
            while n < len(lines) and (lines[n].startswith((" ", "\t")) or not lines[n].strip()):
                n += 1
            last = lines[n].strip() if n < len(lines) else "the traceback ends here"
            current = _add(found, seen, doc, tool, "error", f"crashed: {last}", context,
                           list(range(start, min(n + 1, len(lines)))),
                           [ln.rstrip() for ln in lines[start:n]])
            n += 1
            continue
        if tag:
            level = "error" if (tag.group(1) or tag.group(2)).upper() == "ERROR" else "warning"
            current = _add(found, seen, doc, tool, level, line[tag.end():].strip(), context, [n])
        elif _CRASH.search(line):
            current = _add(found, seen, doc, tool, "error", line.strip(), context, [n])
        elif current is not None and line.strip() and \
                len(line) - len(line.lstrip()) >= _CONTINUATION and current.count == 1:
            current.details.append(line.strip())
            current.lines.append(n)
        else:
            current = None
        n += 1
    if failed and not any(m.level == "error" for m in found):
        found.append(Message(tool, "error", (
            f"{tool} stopped with an error status but printed no error message: "
            "see the end of its log"), (TOOL_STAGES.get(tool, "case"), None),
            lines=[max(len(lines) - 1, 0)]))
    return found


def _add(found, seen, doc, tool, level, text, context, lines, details=None):
    """A message, or one more count of the same message already found;
    returns the message a continuation line would go on."""
    if text.startswith(f"{tool}:"):                  # "GPB: ...": the entry names the tool
        text = text[len(tool) + 1:].strip()
    key = (level, text)
    if key in seen:
        seen[key].count += 1
        return None                     # its lines were read with its first copy
    target, section, keyname = locate(doc, tool, text, context)
    message = Message(tool, level, text, target, section, keyname,
                      details=list(details or []), lines=list(lines))
    seen[key] = message
    found.append(message)
    return message
