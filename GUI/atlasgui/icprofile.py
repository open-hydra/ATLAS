"""The profile files of ICB states (``<key>-file``), read as ICB reads them.

A value of a state can vary cell by cell: ``<key>-file`` names either

* a **table** of two columns, coordinate and value, along ``<key>-direction``
  (x, y, z, r or t, t in degrees), interpolated linearly at the cell centres
  of the zone -- ``read_ascii_table`` and ``assign_from_1D_table`` in ICB; or
* a **Tecplot field** on a structured grid (``.tec``, ``.szplt``): each cell
  takes the first variable after the coordinates at the nearest cell of the
  file, which must be cell-centred (``interpolate_from_file``).

:func:`read_table` follows ``read_ascii_table`` line by line (comments, rows
that are not two numbers, the monotone coordinate, a decreasing one reversed);
:func:`read_field` reads the header of an ASCII Tecplot file only.  With the
mesh, :func:`table_outside` gives the cells of a zone a table does not reach
(``icgeom`` puts the cells on the mesh).  :func:`profile_issues` turns all of
it into the checks of the Initial stage.  No Qt.
"""

from __future__ import annotations

import os
import re

from . import icmodel

TECPLOT_SUFFIXES = (".tec", ".szplt")
_COMMENT = ("#", "!")


def _numbers(line):
    """The leading numbers of a row as a Fortran list-directed read takes
    them: blanks or commas between values, a repeat count ``2*x``."""
    values = []
    for token in re.split(r"[\s,]+", line.strip()):
        if not token:
            continue
        count, star, rest = token.partition("*")
        number = icmodel.to_float(rest if star else token)
        if number is None or (star and not count.isdigit()):
            break
        values += [number] * (int(count) if star else 1)
        if len(values) >= 3:
            break
    return values


class Table:
    """A two-column profile table.

    * ``coords``, ``values`` -- the rows, the coordinate increasing (a
      decreasing file is given back reversed, as ICB does);
    * ``problems``           -- ``[(level, text)]``: ``error`` where ICB
      stops, ``warning`` where it warns (rows skipped, extra columns).
    """

    def __init__(self, coords=(), values=(), problems=()):
        self.coords = list(coords)
        self.values = list(values)
        self.problems = list(problems)

    @property
    def ok(self):
        return not any(level == "error" for level, _t in self.problems)

    def span(self):
        return (self.coords[0], self.coords[-1]) if self.coords else None


def parse_table(text):
    """:class:`Table` of the content *text* of a table file."""
    coords, values, problems, skipped = [], [], [], []
    for n, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith(_COMMENT):
            continue
        numbers = _numbers(line)
        if len(numbers) < 2:
            skipped.append(n)
            continue
        if len(numbers) > 2:
            problems.append(("warning", f"row {n} holds more than two numbers: "
                                        "ICB reads the first two"))
        coords.append(numbers[0])
        values.append(numbers[1])
    if skipped:
        rows = ", ".join(str(n) for n in skipped[:4]) + (" …" if len(skipped) > 4 else "")
        problems.append(("warning", f"line(s) {rows} are not two numbers: ICB "
                                    "skips them (start a comment with #)"))
    if not coords:
        problems.append(("error", "no row of two numbers (coordinate value)"))
        return Table(problems=problems)
    if len(coords) > 2:
        up = coords[-1] >= coords[0]
        for i in range(1, len(coords)):
            if (up and coords[i] < coords[i - 1]) or (not up and coords[i] > coords[i - 1]):
                problems.append(("error", f"the coordinate column is not monotone at "
                                          f"row {i + 1} ({coords[i]:g} after "
                                          f"{coords[i - 1]:g})"))
                return Table(coords, values, problems)
    if len(coords) > 1 and coords[-1] < coords[0]:
        coords, values = coords[::-1], values[::-1]
    if len(coords) < 2:
        problems.append(("error", "one row: a profile needs two points at least"))
    return Table(coords, values, problems)


def read_table(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return parse_table(handle.read())
    except OSError as exc:
        return Table(problems=[("error", f"cannot be read ({exc.strerror})")])


def write_table(path, coords, values, header=""):
    """Write a two-column table ICB reads: *header* as ``#`` comment lines."""
    lines = [f"# {h}" for h in header.splitlines() if h.strip()]
    lines += [f"{c!r} {v!r}" for c, v in zip(coords, values)]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


class Field:
    """The header of a Tecplot field file.

    * ``variables`` -- the names, ``coordinates`` how many lead (x, y[, z]);
    * ``zones``     -- ``[(I, J, K)]`` node counts;
    * ``value``     -- the variable ICB takes (the first after the
      coordinates), ``cell_centred`` whether the file says so;
    * ``problems``  -- as for :class:`Table`.
    """

    def __init__(self):
        self.variables, self.coordinates, self.zones = [], 0, []
        self.value, self.cell_centred, self.binary = "", False, False
        self.problems = []

    @property
    def ok(self):
        return not any(level == "error" for level, _t in self.problems)


def _zone_value(header, key):
    match = re.search(rf"(?<![A-Za-z]){key}\s*=\s*(\d+)", header, re.IGNORECASE)
    return int(match.group(1)) if match else None


def read_field(path):
    """:class:`Field` of the Tecplot file *path* (its header lines only)."""
    field = Field()
    suffix = os.path.splitext(path)[1].lower()
    numbered = re.search(r"\.(tec|szplt)\.\d+$", path.lower())
    if suffix not in TECPLOT_SUFFIXES and not numbered:
        field.problems.append(("error", "ICB reads a field from a Tecplot file "
                                        "(.tec or .szplt)"))
        return field
    if suffix == ".szplt" or (numbered and numbered.group(1) == "szplt"):
        field.binary = True
        field.problems.append(("info", "a binary Tecplot file: ICB reads it when "
                                       "built with TecIO"))
        return field
    try:
        handle = open(path, encoding="utf-8", errors="replace")
    except OSError as exc:
        field.problems.append(("error", f"cannot be read ({exc.strerror})"))
        return field
    locations = []
    with handle:
        for line in handle:
            head = line.lstrip()
            upper = head[:9].upper()
            if upper.startswith("VARIABLES"):
                field.variables = re.findall(r'"([^"]*)"|(\S+)', head.split("=", 1)[1])
                field.variables = [a or b for a, b in field.variables if (a or b) != ","]
                field.variables = [v.strip(",") for v in field.variables if v.strip(",")]
            elif upper.startswith("ZONE"):
                dims = tuple(_zone_value(head, c) or 1 for c in "IJK")
                field.zones.append(dims)
                locations.append(head.upper())
    names = [v.lower() for v in field.variables]
    field.coordinates = 0
    for name in ("x", "y", "z"):
        if field.coordinates < len(names) and names[field.coordinates] == name:
            field.coordinates += 1
    if not field.zones:
        field.problems.append(("error", "no ZONE: not a Tecplot field"))
        return field
    if field.coordinates < 2 or len(field.variables) <= field.coordinates:
        field.problems.append(("error", "ICB needs the coordinates (x, y[, z]) and "
                                        "a variable after them"))
        return field
    field.value = field.variables[field.coordinates]
    index = field.coordinates + 1
    field.cell_centred = all(_cell_centred(header, index) for header in locations)
    if not field.cell_centred:
        field.problems.append(("error", f"{field.value} is not cell-centred: ICB reads "
                                        "the value of each cell (write VARLOCATION=(["
                                        f"{index}]=CELLCENTERED))"))
    elif len(field.variables) > field.coordinates + 1:
        field.problems.append(("info", f"ICB takes {field.value}, the first variable "
                                       "after the coordinates"))
    return field


def _cell_centred(header, index):
    """True when VARLOCATION of the zone *header* lists variable *index* as
    CELLCENTERED (``[3]``, ``[3-5]``, ``[1,3]``)."""
    match = re.search(r"VARLOCATION\s*=\s*\((.*?)\)\s*(,|$)", header)
    if not match:
        return False
    for group, where in re.findall(r"\[([^\]]*)\]\s*=\s*(\w+)", match.group(1)):
        if where != "CELLCENTERED":
            continue
        for part in group.split(","):
            low, _dash, high = part.strip().partition("-")
            try:
                if int(low) <= index <= int(high or low):
                    return True
            except ValueError:
                continue
    return False


def table_outside(cells, mask, letter, table):
    """``(count, (i, j, k) of the first)`` of the cells of *mask* whose
    centre the *table* along *letter* does not hold, as ICB interpolates:
    from the first point (included) to the last."""
    import math

    import numpy as np
    low, high = table.span()
    if letter == "t":
        low, high = low * math.pi / 180.0, high * math.pi / 180.0
    here = cells.coordinate(letter)
    outside = mask & ~((here >= low) & (here <= high))
    count = int(outside.sum())
    return count, (cells.first_index(outside) if count else None)


class Cache:
    """Tables and field headers read once per file version: the checks run
    on every keystroke."""

    def __init__(self):
        self._seen = {}

    def get(self, path, reader):
        try:
            stamp = os.stat(path).st_mtime_ns
        except OSError:
            stamp = None
        key = (path, reader.__name__)
        hit = self._seen.get(key)
        if hit is None or hit[0] != stamp:
            hit = (stamp, reader(path))
            self._seen[key] = hit
        return hit[1]


def resolve(value, case_dir):
    """The path ICB opens for *value*: relative to the case directory."""
    value = (value or "").strip()
    if not value:
        return ""
    return value if os.path.isabs(value) else os.path.join(case_dir or os.getcwd(), value)


def profile_issues(state, where, target, case_dir, cache, coverage=None):
    """``[(level, target, message)]`` of the profile files of *state*: what
    their content makes ICB stop on.  *coverage(letter, table)* gives the
    cells of the zone a table misses on the mesh, ``(count, first)``, or None
    without the mesh.  A missing file is left to the file checks."""
    issues = []
    for key in list(state.params):
        if not key.endswith("-file") or key == "eq-CEA-file":
            continue
        path = resolve(state.get(key), case_dir)
        if not path or not os.path.isfile(path):
            continue
        name = state.get(key).strip()
        direction = state.get(f"{key[:-5]}-direction").strip()
        if direction:
            table = cache.get(path, read_table)
            for level, text in table.problems:
                issues.append((level, target, f"{where}: {key} {name}: {text}"))
            if table.ok and coverage is not None and direction in icmodel.PROFILE_DIRECTIONS:
                missed = coverage(direction, table)
                if missed and missed[0]:
                    count, first = missed
                    low, high = table.span()
                    issues.append(("error", target, (
                        f"{where}: {key} {name}: {count} cell(s) of the zone lie "
                        f"outside the table along {direction} ({low:g} … {high:g}), the "
                        f"first is cell {first}: ICB stops on them")))
        else:
            field = cache.get(path, read_field)
            for level, text in field.problems:
                if level != "info":
                    issues.append((level, target, f"{where}: {key} {name}: {text}"))
    return issues
