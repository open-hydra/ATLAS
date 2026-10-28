"""Where the zones of an ICB block fall on the mesh, computed as ICB does.

ICB (``src/ICB/builder*.f90``) gives a cell to a zone when the cell lies in the
zone's range along every letter of the block's ``direction``, limits included:

* x, y, z, r, t compare the cell centre, the mean of its eight nodes; t is
  written in degrees and compared in radians;
* i, j, k compare the cell index (from 1), the range rounded to integers.

The centre's r and t are taken about the x axis (r = sqrt(y² + z²),
t = atan2(z, y)).  A pure 2-D mesh -- one node plane in K -- is one cell thick
with its centres at z = 0.5, and takes r and t in the x-y plane
(r = sqrt(x² + y²), t = atan2(y, x)).

Zones are written in order: a later zone overwrites an earlier one in the cells
they share.  A nozzle zone also writes its plenum rows whole for the gas -- the
cross-sections whose centre lies upstream of ``nozzle-threshold`` -- outside its
range too.  ICB stops when a cell of a phase
is written by no zone, and, under a k-omega or Reynolds-stress model, when the
turbulence of a cell is set by no zone.

The nozzle law reads every row of cells i as a cross-section of a duct about the
x axis (:class:`NozzleGeometry`), and ICB refuses a block that is not one.

Only numpy: the Initial stage and the tests use it without Qt.
"""

from __future__ import annotations

import math

import numpy as np

from . import icmodel

LETTERS = icmodel.DIRECTION_LETTERS        # "xyzrtijk"
INDEX_LETTERS = "ijk"
MAX_LETTERS = 3                            # ICB reads three pairs of range<n>
NOZZLE_AREA_TOL = 1.0e-3                   # a section that varies less has no throat
TURBULENCE_VALUES = tuple(k for k in icmodel.TURBULENCE_KEYS if k != "nrans")


def fortran_nint(value):
    """Fortran NINT: the nearest integer, halves away from zero."""
    return math.copysign(math.floor(abs(value) + 0.5), value)


class BlockCells:
    """The cells of one mesh block, with their coordinates along every letter,
    computed when first asked for."""

    def __init__(self, mesh_block):
        self.mesh = mesh_block
        ni, nj, nk = mesh_block.dims
        self.pure_2d = nk == 1
        self.shape = (ni - 1, nj - 1, 1 if self.pure_2d else nk - 1)
        self._coords = {}
        self.masks = {}            # (direction, values) -> cells of that range
        self._nozzle = None

    @property
    def count(self):
        return self.shape[0] * self.shape[1] * self.shape[2]

    def _nodes(self):
        x, y, z = self.mesh.xn, self.mesh.yn, self.mesh.zn
        if self.pure_2d:
            # ICB doubles the node plane at z = k (0 and 1)
            x = np.concatenate([x, x], axis=2)
            y = np.concatenate([y, y], axis=2)
            z = np.concatenate([np.zeros_like(z), np.ones_like(z)], axis=2)
        return x, y, z

    @staticmethod
    def _centre(a):
        # the eight nodes in the order of compute_centers (src/common/grid.f90)
        return 0.125 * (a[:-1, :-1, :-1] + a[1:, :-1, :-1] + a[:-1, 1:, :-1]
                        + a[:-1, :-1, 1:] + a[1:, 1:, 1:] + a[1:, 1:, :-1]
                        + a[1:, :-1, 1:] + a[:-1, 1:, 1:])

    def coordinate(self, letter):
        """The value every cell compares along *letter* (radians for t)."""
        if letter in self._coords:
            return self._coords[letter]
        if letter in INDEX_LETTERS:
            axis = INDEX_LETTERS.index(letter)
            shape = [1, 1, 1]
            shape[axis] = self.shape[axis]
            value = np.arange(1, self.shape[axis] + 1, dtype=float).reshape(shape)
            value = np.broadcast_to(value, self.shape)
        elif letter in "xyz":
            if not self._coords.get("_xyz"):
                for name, nodes in zip("xyz", self._nodes()):
                    self._coords[name] = self._centre(nodes)
                self._coords["_xyz"] = True
            return self._coords[letter]
        else:
            x, y, z = (self.coordinate(c) for c in "xyz")
            a, b = (x, y) if self.pure_2d else (y, z)
            value = np.sqrt(a ** 2 + b ** 2) if letter == "r" else np.arctan2(b, a)
        self._coords[letter] = value
        return value

    def extent(self, letter):
        """``(low, high)`` holding every cell along *letter*, in the units of
        the deck: the node extent for x, y, z (it holds every centre), 0 to
        the largest node radius for r, the full turn for t, 1 to N for i, j, k."""
        if letter in INDEX_LETTERS:
            return 1, self.shape[INDEX_LETTERS.index(letter)]
        if letter == "t":
            return -180.0, 180.0
        x, y, z = self._nodes()
        if letter == "r":
            a, b = (x, y) if self.pure_2d else (y, z)
            return 0.0, float(np.sqrt(a ** 2 + b ** 2).max())
        nodes = {"x": x, "y": y, "z": z}[letter]
        return float(nodes.min()), float(nodes.max())

    def nozzle(self):
        """The :class:`NozzleGeometry` of the block, computed once."""
        if self._nozzle is None:
            self._nozzle = NozzleGeometry(self)
        return self._nozzle

    def first_index(self, mask):
        """``(i, j, k)`` from 1 of the first True cell of *mask*, i fastest
        (the cell ICB names), or None."""
        flat = np.flatnonzero(np.asarray(mask).ravel(order="F"))
        if flat.size == 0:
            return None
        i, j, k = np.unravel_index(flat[0], self.shape, order="F")
        return int(i) + 1, int(j) + 1, int(k) + 1


def outward_limit(value, up):
    """*value* in six significant digits, rounded away from the cells it
    bounds (*up* for an upper limit): a limit written shorter still holds them."""
    if value == 0 or not math.isfinite(value):
        return "0" if value == 0 else repr(value)
    text = f"{value:.6g}"
    if (float(text) < value) if up else (float(text) > value):
        step = 10.0 ** (math.floor(math.log10(abs(value))) - 5)
        n = math.ceil(value / step) if up else math.floor(value / step)
        text = f"{n * step:.6g}"
        while (float(text) < value) if up else (float(text) > value):
            n += 1 if up else -1
            text = f"{n * step:.6g}"
    return text


def parse_range(text, direction):
    """The values of a ``range<n>`` for *direction*, or None when ICB would
    refuse them (not one number per limit, or not two per letter)."""
    tokens = str(text or "").split()
    values = [icmodel.to_float(t) for t in tokens]
    if any(v is None for v in values) or len(values) != 2 * len(direction):
        return None
    return values


def range_mask(cells, direction, values):
    """The cells of *cells* inside the range *values* along *direction*
    (cached on *cells*: the checks run on every keystroke)."""
    key = (direction, tuple(values))
    cached = cells.masks.get(key)
    if cached is not None:
        return cached
    mask = np.ones(cells.shape, dtype=bool)
    for n, letter in enumerate(direction[:MAX_LETTERS]):
        low, high = values[2 * n], values[2 * n + 1]
        if letter == "t":
            low, high = low * math.pi / 180.0, high * math.pi / 180.0
        elif letter in INDEX_LETTERS:
            low, high = fortran_nint(low), fortran_nint(high)
        here = cells.coordinate(letter)
        mask &= (here >= low) & (here <= high)
    if len(cells.masks) > 64:
        cells.masks.clear()
    cells.masks[key] = mask
    return mask


def nozzle_law(state, kinds):
    """True when ICB builds *state* with the nozzle law (and so writes its
    plenum rows): an ideal gas, type nozzle, no old solution, no profile."""
    return ("IG" in kinds and state.get("type").strip() == "nozzle"
            and not state.has("old-solution") and not state.profile_keys())


class NozzleGeometry:
    """The cross-sections the nozzle law reads in a block, as ICB takes them
    (``assign_nozzle``, ``check_nozzle_geometry``): the row of cells i is a
    section of a duct about the x axis, of area pi |r_ext² - r_int²|, the
    distances to the axis of its walls j = 1 and j = J, mid-row on the first
    node plane of k.

    * ``x``       -- the centre x of the cells (i, 1, 1), one per row;
    * ``area``    -- the area of every row, ``ratio`` it over the throat's;
    * ``throat``  -- the row of smallest area, from 0;
    * ``problem`` -- why ICB refuses the block (the first of its checks that
      fails), ``short`` the same in a few words; both "" for a nozzle.
    """

    def __init__(self, cells):
        _x, y, z = cells._nodes()

        def radius(j):
            return np.sqrt((0.5 * (y[:-1, j, 0] + y[1:, j, 0])) ** 2
                           + (0.5 * (z[:-1, j, 0] + z[1:, j, 0])) ** 2)

        self.rows = cells.shape[0]
        self.r_int, self.r_ext = radius(0), radius(-1)
        self.area = math.pi * np.abs(self.r_ext ** 2 - self.r_int ** 2)
        self.x = np.array(cells.coordinate("x")[:, 0, 0])
        self.throat = int(np.argmin(self.area))
        throat_area = self.area[self.throat]
        with np.errstate(divide="ignore", invalid="ignore"):
            self.ratio = self.area / throat_area if throat_area > 0 else np.full(self.rows, np.nan)
        self.problem, self.short = self._check()

    def _check(self):
        for n in range(1, self.rows):
            if not self.x[n] > self.x[n - 1]:
                return (f"its cell centres do not advance along +x with i: at j = 1, "
                        f"k = 1 cell i = {n + 1} lies at x = {self.x[n]:.6g}, cell "
                        f"i = {n} at x = {self.x[n - 1]:.6g}",
                        "i does not run along +x")
        for n in range(self.rows):
            if not self.area[n] > 1e-9 * math.pi * max(self.r_int[n], self.r_ext[n]) ** 2:
                return (f"the row of cells i = {n + 1} has no cross-section: its walls "
                        f"j = 1 and j = J lie at the same distance from the x axis "
                        f"({self.r_int[n]:.6g} and {self.r_ext[n]:.6g})",
                        f"row i = {n + 1} has no cross-section")
        if self.area.max() <= (1.0 + NOZZLE_AREA_TOL) * self.area.min():
            return (f"its cross-section is constant along i (A max/min = "
                    f"{self.area.max() / self.area.min():.7f}, the law needs 1.001 at "
                    "least): a duct without a throat",
                    "the cross-section is constant, no throat")
        return "", ""


def plenum_rows(cells, state):
    """Per row of cells i, whether a nozzle *state* keeps it as plenum (p0 and
    T0 at rest, the whole cross-section), as ``assign_nozzle`` does: the rows
    whose centre (at j = 1, k = 1) lies upstream of ``nozzle-threshold`` along
    the flow, x below it with ``dx``, above it with ``sx``.  The law takes
    every other row; without a threshold there is no plenum."""
    x = cells.coordinate("x")[:, 0, 0]
    threshold = icmodel.to_float(state.get("nozzle-threshold"))
    if threshold is None:
        return np.zeros(x.shape, dtype=bool)
    if state.get("nozzle-direction").strip() == "sx":
        return x > threshold
    return x < threshold


class ZoneCoverage:
    """One zone of a block on the mesh."""

    def __init__(self, number, section, state, mask, plenum=None):
        self.number = number            # n of zone<n>
        self.section = section
        self.state = state              # the ICState, or None when missing
        self.mask = mask                # cells of its range (None: range unread)
        self.plenum = plenum            # plenum rows outside its range, or None
        self.cells = int(mask.sum()) if mask is not None else 0
        self.kept = 0                   # cells it is the last zone to write
        self.overwrites = 0             # cells of earlier zones it writes again


class BlockCoverage:
    """The zones of one block on the mesh, and what they leave unwritten.

    * ``zones``     -- a :class:`ZoneCoverage` per zone, in the order ICB
      writes them;
    * ``unwritten`` -- ``{kind: (count, (i, j, k) of the first)}`` for each
      kind of phase with cells no zone writes (ICB stops);
    * ``turbulence`` -- ``(model, count, first)`` of the cells whose
      turbulence no zone sets, or None;
    * ``plenum_overwrites`` -- ``[(zone, count, earlier)]``: the cells a
      nozzle plenum and another zone both write (ICB warns, the order decides);
    * ``written_after`` -- the gas cells written once each zone is done, the
      count ICB lists when it stops on unwritten cells;
    * ``writer``    -- per cell, the order (from 1) of the zone that writes its
      gas last, the plenum rows included, 0 where none does;
    * ``rest``      -- the cells a nozzle zone writes last as plenum, at rest.
    """

    def __init__(self, cells, block, zones_by_name, kinds):
        self.cells = cells
        self.total = cells.count
        self.zones = []
        self.unwritten = {}
        self.turbulence = None
        self.plenum_overwrites = []
        self.written_after = []
        direction = block.direction
        written = np.zeros(cells.shape, dtype=bool)          # any phase, by range
        gas_written = np.zeros(cells.shape, dtype=bool)      # the gas, with plenums
        plenum_cells = np.zeros(cells.shape, dtype=bool)     # plenum rows so far
        turbulent = np.zeros(cells.shape, dtype=bool)
        models = set()
        last_writer = np.zeros(cells.shape, dtype=np.int32)  # 1-based zone order
        rest = np.zeros(cells.shape, dtype=bool)             # left at rest by a plenum
        for order, (number, ref) in enumerate(
                zip(block.zone_numbers(), block.zone_refs()), start=1):
            state = zones_by_name.get(ref.section)
            values = parse_range(" ".join(ref.range), direction)
            if state is None or values is None:
                self.zones.append(ZoneCoverage(number, ref.section, state, None))
                self.written_after.append(int(gas_written.sum()))
                continue
            mask = range_mask(cells, direction, values)
            plenum = None
            rows = None
            if nozzle_law(state, kinds):
                rows = np.broadcast_to(plenum_rows(cells, state).reshape(-1, 1, 1),
                                       cells.shape)
                plenum = rows & ~mask
            zone = ZoneCoverage(number, ref.section, state, mask, plenum)
            zone.overwrites = int((mask & written).sum())
            if "IG" in kinds and plenum_cells.any():
                hit = int((mask & plenum_cells).sum())
                if hit:
                    self.plenum_overwrites.append((zone, hit, "plenum"))
                plenum_cells &= ~mask
            if plenum is not None and plenum.any():
                hit = int((plenum & gas_written).sum())
                if hit:
                    self.plenum_overwrites.append((zone, hit, "zones"))
                plenum_cells |= plenum
                gas_written |= plenum
                last_writer[plenum] = order
            written |= mask
            gas_written |= mask
            last_writer[mask] = order
            # a nozzle zone leaves its plenum rows at rest, in its range and out of it
            rest[mask] = rows[mask] if rows is not None else False
            if plenum is not None:
                rest[plenum] = True
            if kinds & {"IG", "RF"}:
                model = icmodel.turbulence_model(state)
                if model:
                    models.add(model)
                # an interpolated zone may bring the turbulence of its source
                if any(state.has(k) for k in TURBULENCE_VALUES) or \
                        state.mode == "interpolate":
                    turbulent |= mask
            self.zones.append(zone)
            self.written_after.append(int(gas_written.sum()))
        self.writer = last_writer
        self.rest = rest
        for order, zone in enumerate(self.zones, start=1):
            if zone.mask is not None:
                zone.kept = int((last_writer == order).sum())
        for kind in sorted(kinds) or ["IG"]:
            have = gas_written if kind == "IG" else written
            if not have.all():
                self.unwritten[kind] = (int((~have).sum()), cells.first_index(~have))
        model = max(models, default=0)
        if model and not turbulent.all():
            missing = ~turbulent
            self.turbulence = (model, int(missing.sum()), cells.first_index(missing))

    @property
    def complete(self):
        return not self.unwritten


class StateMap:
    """The state ICB writes into every cell of one mesh block, for the 3-D view.

    * ``targets`` -- the sections those states are edited in, as the rows of
      the Initial stage name them: ``"*"`` or the block index for a block
      state, ``(owner, section)`` for a zone (one entry per zone, in the order
      ICB writes them);
    * ``writer``  -- per cell, the index in ``targets`` of the state written
      there last (for the gas, the plenum rows of nozzle zones included), -1
      where none is;
    * ``rest``    -- the cells a nozzle state leaves at rest, its plenum;
    * ``placed``  -- False when the zones cannot be placed (no direction, or
      letters ICB refuses): no cell has a writer then.
    """

    def __init__(self, targets, writer, rest, placed=True):
        self.targets = targets
        self.writer = writer
        self.rest = rest
        self.placed = placed


def state_map(doc, b, cells, phases):
    """The :class:`StateMap` of mesh block *b* (from 1), whose cells are
    *cells*, under the ICB deck *doc*."""
    writer = np.full(cells.shape, -1, dtype=np.int32)
    rest = np.zeros(cells.shape, dtype=bool)
    block = doc.block(b)
    if block is None:
        return StateMap([], writer, rest)
    owner = block.index
    kinds = icmodel.block_kinds(block, phases)
    if not block.is_split:
        writer[...] = 0
        if nozzle_law(block, kinds) and not cells.nozzle().problem:
            rest[...] = plenum_rows(cells, block).reshape(-1, 1, 1)
        return StateMap([owner], writer, rest)
    direction = block.direction
    if not direction or any(c not in LETTERS for c in direction) or \
            len(direction) > MAX_LETTERS:
        return StateMap([], writer, rest, placed=False)
    cover = BlockCoverage(cells, block, doc.zones, kinds)
    targets = [(owner, zone.section) for zone in cover.zones]
    return StateMap(targets, cover.writer - 1, cover.rest)


def _cells(mesh, cache):
    cells = cache.get(id(mesh))
    if cells is None or cells.mesh is not mesh:
        cells = cache[id(mesh)] = BlockCells(mesh)
    return cells


def nozzle_issues(doc, mesh_blocks, phases, cache=None):
    """``[(level, target, message)]``: the nozzle states of *doc* given to a
    mesh block that is no nozzle, on which ICB stops."""
    issues = []
    cache = cache if cache is not None else {}
    for b, mesh in enumerate(mesh_blocks, start=1):
        block = doc.block(b)
        if block is None:
            continue
        kinds = icmodel.block_kinds(block, phases)
        if block.is_split:
            states = [(doc.zones.get(ref.section), (block.index, ref.section),
                       f"{icmodel.block_label(block.index)}, zone [{ref.section}]")
                      for ref in block.zone_refs()]
        else:
            states = [(block, block.index, icmodel.block_label(block.index))]
        states = [s for s in states if s[0] is not None and nozzle_law(s[0], kinds)]
        if not states:
            continue
        problem = _cells(mesh, cache).nozzle().problem
        if not problem:
            continue
        on = f"on block {b}, " if block.is_wildcard else ""
        for _state, target, where in states:
            issues.append(("error", target, (
                f"{where}: {on}the nozzle flow needs a nozzle along x, and the block is "
                f"not one: {problem}. ICB stops on it: build the block as a uniform "
                "state")))
    return issues


def coverage_issues(doc, mesh_blocks, phases, cache=None):
    """``[(level, target, message)]`` of the zones of *doc* (an
    :class:`icmodel.ICBDocument`) on *mesh_blocks*: the cells ICB would find
    unwritten, the zones that write no cell, the plenum overlaps ICB reports.
    *cache* maps a mesh block to its :class:`BlockCells` across calls."""
    issues = []
    cache = cache if cache is not None else {}
    for b, mesh in enumerate(mesh_blocks, start=1):
        block = doc.block(b)
        if block is None or not block.is_split or not block.direction:
            continue
        if any(c not in LETTERS for c in block.direction) or \
                len(block.direction) > MAX_LETTERS:
            continue                        # the deck checks report the letters
        cells = _cells(mesh, cache)
        kinds = icmodel.block_kinds(block, phases)
        cover = BlockCoverage(cells, block, doc.zones, kinds)
        target = block.index
        where = icmodel.block_label(target)
        on = f"on block {b}, " if block.is_wildcard else ""
        for kind, (count, first) in cover.unwritten.items():
            label = icmodel.KIND_LABEL.get(kind, kind).lower()
            issues.append(("error", target, (
                f"{where}: {on}{count} of {cover.total} cells are in no zone for the "
                f"{label} (first cell {first}): ICB stops on it. Widen a range "
                "or add a zone")))
        if cover.turbulence:
            model, count, first = cover.turbulence
            name = icmodel.TURBULENCE_MODELS.get(model, str(model))
            level = "warning" if model == 1 else "error"
            tail = ("it stays 0" if model == 1 else
                    "ICB stops on it: the solver kernels divide by them")
            issues.append((level, target, (
                f"{where}: {on}the turbulence of {count} of {cover.total} cells is set "
                f"by no zone under the {name} model (first cell {first}): {tail}. "
                "Give its keys in every zone")))
        for zone in cover.zones:
            if zone.mask is None:
                continue
            if zone.cells == 0:
                issues.append(("warning", (target, zone.section), (
                    f"{where}, zone [{zone.section}]: {on}its range holds no cell "
                    "of the block")))
            elif zone.kept == 0:
                issues.append(("warning", (target, zone.section), (
                    f"{where}, zone [{zone.section}]: {on}the zones after it write "
                    f"all of its {zone.cells} cells, so it sets none")))
        for zone, count, what in cover.plenum_overwrites:
            text = ("writes again {n} cells of the plenum rows of an earlier nozzle "
                    "zone" if what == "plenum" else
                    "writes its plenum rows over {n} cells of earlier zones")
            issues.append(("warning", (target, zone.section), (
                f"{where}, zone [{zone.section}]: {on}" + text.format(n=count)
                + " (the plenum spans the whole cross-section upstream of "
                "nozzle-threshold): the zone order decides their state")))
    return issues
