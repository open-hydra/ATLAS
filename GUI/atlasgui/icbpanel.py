"""The Initial stage: the ICB part of the case.

Left: the blocks of the mesh, *All blocks* first -- the ``[ICB-Block*]`` state
that every block without a section of its own takes.  Right: the editor of the
selected state.  One section holds the state of every phase the block builds
(``T = 300`` sets the gas and the solid alike), so the editor shows a card per
thing the state gives -- the gas state, the velocity, the composition, the
turbulence, the solid, the dispersed phase, the real fluid -- for the phases of
the block, in the mode chosen: uniform, nozzle, or interpolated from an earlier
solution.

Every widget writes straight into the deck (there is no Apply button to
forget), anything the form does not model stays in the section and is
reachable through "All keys…", and the checks under the form say what ICB would
stop on before it runs.

A block can be split into zones: the block's page then holds the layout (the
letters the ranges are given along, the zones in the order ICB writes them,
their ranges and the cells each takes on the mesh), and each zone is listed
under its block and edited like a block state.  With the mesh loaded the
checks say which cells no zone writes, as ICB would (``icgeom``).

A value ICB can read cell by cell has a profile button: the profile dialog
(``icbdialogs``) gives it from a table along a letter or a Tecplot field, and
the checks read those files as ICB does (``icprofile``).

Right of the editor, the 3-D view paints every cell of the mesh in the colour
of the state ICB writes into it last (``icgeom.state_map``): the zones, the
plenum of a nozzle at rest in a lighter tint, the cells no state writes
outlined in the error colour.  The selected state is in full colour, the rest
dimmed; a click on a cell opens the state it takes.
"""

from __future__ import annotations

import math
import os
import weakref
from collections import OrderedDict

import numpy as np

from PyQt6.QtCore import QSize, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QBrush, QColor
from PyQt6.QtWidgets import (
    QAbstractItemView, QButtonGroup, QComboBox, QDialog, QFormLayout, QFrame,
    QGridLayout, QHBoxLayout, QHeaderView, QInputDialog, QLabel, QLineEdit,
    QListWidget, QListWidgetItem, QMenu, QMessageBox, QSizePolicy, QSplitter,
    QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)

from . import database, filekeys, icgeom, icmodel, icons, icprofile
from .bcmodel import KEYWORD_BCS
from .filewidgets import STATE_ICON, STATE_TOKEN, pick_value
from .gpbdialogs import AdvancedKeysDialog
from .icbdialogs import LETTER_TIPS, LETTER_UNITS, NozzlePlot, ProfileDialog, SplitDialog
from .icmodel import (GAS_PAIRS, REAL_FLUID_PAIRS, TURBULENCE_MODELS,
                      block_label)
from .viewport import StateViewport
from .widgets import Card, clear_layout

# The unit each value is given in (ICB reads every value in SI).
UNITS = {
    "p": "Pa", "p0": "Pa", "T": "K", "T0": "K", "rho": "kg/m³", "h": "J/kg",
    "mach": "", "vel": "m/s", "u": "m/s", "v": "m/s", "w": "m/s",
    "alpha": "deg", "beta": "deg",
    "nuTilde": "m²/s", "k": "m²/s²", "omega": "1/s", "Rij": "m²/s²",
    "rhoNuTilde": "kg/(m·s)", "rhoK": "kg/(m·s²)", "rhoOmega": "kg/(m³·s)",
    "rhoRij": "kg/(m·s²)", "nozzle-threshold": "m", "dp": "m", "rp": "m",
    "Pp": "Pa", "theta": "deg",
}

# What an empty field means to ICB.
PLACEHOLDERS = {
    "mach": "0 (at rest)", "vel": "0 (at rest)", "u": "0", "v": "0", "w": "0",
    "krho": "0 (no particles)", "kT": "1", "Pp": "0",
}

MODE_BLURBS = {
    "uniform": "One state for every cell. A value can also vary cell by cell, "
               "from a profile file (the profile button by the value): the state "
               "is then variable.",
    "nozzle": "Nozzle flow, a special law for one geometry: a duct about the x "
              "axis, meshed along it, with a throat. The plenum upstream of the "
              "threshold keeps p0 and T0 at rest; downstream, the quasi-1-D area "
              "law gives every row of cells its Mach number. Ideal gas only.",
    "interpolate": "The state of an earlier solution, interpolated onto this "
                   "mesh. The composition and the turbulence bands come with it.",
}

# The special initialisations in a few words, for their menu.
SPECIAL_TAGLINES = {
    "nozzle": "quasi-1-D flow from a plenum, for a nozzle along x",
}

LAW_LABELS = OrderedDict([
    ("", "Nearest cell (default)"),
    ("index", "index — same cells, index by index"),
    ("multiple", "multiple — refined or coarsened by a whole factor"),
    ("minimum_distance", "minimum_distance — nearest cell centre"),
    ("spherical_minimum_distance",
     "spherical_minimum_distance — nearest centre, searched in growing spheres"),
    ("extrude", "extrude — 2-D source revolved into a 3-D sector"),
    ("outlaw", "outlaw — the default, written out"),
])

STATUS_TOKENS = {"own": "accent", "inherited": "muted", "missing": "danger",
                 "error": "danger", "warning": "warning", "split": "accent"}

# The colours of the states in the 3-D view: the categorical hues of the
# data-viz palette in their fixed order, stepped for a light and for a dark
# background (they pass its colour-blindness checks on the backgrounds of every
# theme).  Its red is left out: it reads as the error colour, which outlines the
# cells no state writes -- those are told by the outline and their legend
# entry, never by a hue.  Past seven states the hues come round again; the
# legend and a click on a cell tell them apart.
STATE_HUES = {
    "light": ("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6"),
    "dark": ("#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300", "#9085e9"),
}
REST_TINT = 0.5        # a plenum at rest: its state's colour, this far towards white
DIM = 0.5              # a cell out of the selection: this far towards the background
SEE_THROUGH = 0.12     # opacity of a 3-D block a selected block or zone leaves out

# A range that holds every cell, for a letter added before the mesh is loaded.
UNBOUNDED = {"x": (-1e9, 1e9), "y": (-1e9, 1e9), "z": (-1e9, 1e9),
             "r": (0, 1e9), "t": (-180, 180), "i": (1, 999999), "j": (1, 999999),
             "k": (1, 999999)}


class BlockListItem(QWidget):
    """Two-line row of the block list: the block, then where its state comes
    from in one line."""

    def __init__(self, kit, title, detail, token, tip, indent=0):
        super().__init__()
        self.setObjectName("PhaseRow")
        layout = QHBoxLayout(self)
        layout.setContentsMargins(8 + kit.px(indent), 7, 8, 7)
        layout.setSpacing(9)
        dot = QLabel()
        dot.setPixmap(icons.dot_pixmap(kit.color(token), kit.px(12)))
        dot.setFixedWidth(kit.px(14))
        layout.addWidget(dot, 0, Qt.AlignmentFlag.AlignTop)
        text = QVBoxLayout()
        text.setSpacing(2)
        name = QLabel(title)
        name.setProperty("role", "value")
        text.addWidget(name)
        # The summary is elided to the width of the list: a long one must not
        # widen the row past it (the list would scroll sideways).
        self._detail = detail
        self.line = QLabel(detail)
        self.line.setProperty("role", "hint")
        self.line.setWordWrap(False)
        self.line.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
        text.addWidget(self.line)
        layout.addLayout(text, 1)
        self.setToolTip(f"{tip}\n{detail}")
        self.ensurePolished()      # see PhaseListItem: sized before shown

    def resizeEvent(self, event):
        super().resizeEvent(event)
        metrics = self.line.fontMetrics()
        self.line.setText(metrics.elidedText(
            self._detail, Qt.TextElideMode.ElideRight, max(self.line.width(), 0)))


class ICBPanel(QWidget):
    """Editor for the initial state of the blocks."""

    changed = pyqtSignal()

    def __init__(self, shell):
        super().__init__()
        self.shell = shell
        self.kit = shell.kit
        self._loading = False
        self._phases = []
        self._issues = []
        self._targets = []
        self._shown = {}           # target -> what its list row shows
        self._choices = weakref.WeakKeyDictionary()   # state -> {what: choice}
        self._cells = {}           # mesh block -> icgeom.BlockCells
        self._profiles = icprofile.Cache()
        self._maps = {}            # mesh block -> its icgeom.StateMap, as drawn
        self._hues = {}            # state key -> the slot of its colour
        self._hues_doc = None      # the document those slots are for
        self._view_mesh = None     # the mesh the 3-D view holds
        self._view_theme = None
        self._view_stale = True
        self._focus = True
        self._picked = None        # (mesh block, cell) last clicked in the view
        self._view_timer = QTimer(self)
        self._view_timer.setSingleShot(True)
        self._view_timer.setInterval(80)
        self._view_timer.timeout.connect(self._refresh_view)
        self._build_ui()

    # -- document access -------------------------------------------------
    @property
    def icb(self):
        return self.shell.doc.icb

    @property
    def case_dir(self):
        return self.shell.case_dir

    def block_count(self):
        """The blocks of the mesh, else of the BCB deck, else the highest
        block section of the ICB deck."""
        mesh = getattr(self.shell.bcb_panel, "blocks", None) or []
        if mesh:
            return len(mesh)
        if self.shell.doc.bcb.nblocks:
            return self.shell.doc.bcb.nblocks
        return max(self.icb.blocks, default=0)

    def reload_phases(self):
        """Read the phases of the case afresh: GPB may have run, or the
        Phases stage changed them.  The checks run on every keystroke, so
        they use what was read here rather than the disk."""
        case_dir = self.case_dir

        def species(phase):
            stem = phase.get("reactions") or phase.get("phase")
            return database.species_of_mechanism(stem, case_dir) if stem else []

        self._phases = icmodel.case_phases(self.shell.doc.gpb, case_dir, species)
        return self._phases

    def strict_keys(self):
        return self.shell.doc.strict_keys()

    def mesh_blocks(self):
        return getattr(self.shell.bcb_panel, "blocks", None) or []

    def validate(self):
        """The ICB checks of the case, for the Review stage too: those of the
        deck, and with the mesh loaded the cells the zones leave unwritten."""
        issues = self.icb.validate(self.block_count(), self._phases, self.strict_keys())
        mesh = self.mesh_blocks()
        if mesh:
            issues += icgeom.coverage_issues(self.icb, mesh, self._phases, self._cells,
                                             self._source_model)
            issues += icgeom.nozzle_issues(self.icb, mesh, self._phases, self._cells)
        for block in self.icb.all_blocks():
            owner = block.index
            if block.is_split:
                states = [(self.icb.zones.get(ref.section), (owner, ref.section),
                           f"{block_label(owner)}, zone [{ref.section}]", ref)
                          for ref in block.zone_refs()]
            else:
                states = [(block, owner, block_label(owner), None)]
            for state, target, where, ref in states:
                if state is None or not state.profile_keys():
                    continue
                cover = self._table_coverage(owner, block, ref) if mesh else None
                issues += icprofile.profile_issues(state, where, target, self.case_dir,
                                                   self._profiles, cover)
        return issues

    def _source_model(self, state):
        """The turbulence model ICB adopts from the old solution of *state*
        (:func:`icprofile.source_turbulence`), None when not known."""
        path = icprofile.resolve(state.get("old-solution"), self.case_dir)
        if not path.lower().endswith(".tec") or not os.path.isfile(path):
            return None
        return icprofile.source_turbulence(self._profiles.get(path, icprofile.read_field))

    # -- the cells of a state on the mesh --------------------------------------
    def _state_cells(self, owner, block, ref):
        """``[(BlockCells, mask)]``: the cells the state of *block* (or of its
        zone *ref*) writes on each mesh block it is given to."""
        pairs = []
        values = None
        if ref is not None:
            if icmodel.direction_issue(block.direction) or not block.direction:
                return []
            values = icgeom.parse_range(" ".join(ref.range), block.direction)
            if values is None:
                return []
        for b in self._users(owner):
            cells = self._cells_of(b)
            if cells is None:
                continue
            if values is None:
                mask = np.ones(cells.shape, dtype=bool)
            else:
                mask = icgeom.range_mask(cells, block.direction, values)
            pairs.append((cells, mask))
        return pairs

    def _table_coverage(self, owner, block, ref):
        """``coverage(letter, table)`` of a profile of this state: the cells
        it writes that the table misses, ``(count, first)``."""
        pairs = self._state_cells(owner, block, ref)

        def coverage(letter, table):
            count, first = 0, None
            for cells, mask in pairs:
                n, where = icprofile.table_outside(cells, mask, letter, table)
                count += n
                first = first or where
            return count, first
        return coverage

    def _span_of(self, owner, block, ref):
        """``span(letter)``: the span of the cell centres this state writes
        along a letter (t in degrees), or None without the mesh."""
        pairs = self._state_cells(owner, block, ref)

        def span(letter):
            lows, highs = [], []
            for cells, mask in pairs:
                if not mask.any():
                    continue
                here = cells.coordinate(letter)[mask]
                lows.append(float(here.min()))
                highs.append(float(here.max()))
            if not lows:
                return None
            low, high = min(lows), max(highs)
            if letter == "t":
                low, high = math.degrees(low), math.degrees(high)
            return low, high
        return span

    def current_target(self):
        row = self.block_list.currentRow()
        return self._targets[row] if 0 <= row < len(self._targets) else None

    def current_state(self):
        """The section the selected row edits: the wildcard, a block's own
        section, or a zone section; None when the block has none."""
        target = self.current_target()
        if isinstance(target, tuple):
            return self.icb.zones.get(target[1])
        if target == "*":
            return self.icb.wildcard
        return self.icb.blocks.get(target) if target is not None else None

    def _owner_section(self, owner):
        """The block section *owner* (an index or ``"*"``) edits."""
        return self.icb.wildcard if owner == "*" else self.icb.blocks.get(owner)

    def _phase_block(self, state):
        """The block whose ``phase`` key applies to *state*: the state
        itself, or for a zone the block that lists it."""
        target = self.current_target()
        if isinstance(target, tuple):
            return self._owner_section(target[0]) or state
        return state

    def _kinds(self, state):
        return icmodel.block_kinds(self._phase_block(state), self._phases)

    def _kind_phases(self, state, kind):
        return [p for p in icmodel.block_phases(self._phase_block(state), self._phases)
                if p.kind == kind]

    def _cells_of(self, index):
        """The :class:`icgeom.BlockCells` of mesh block *index*, or None."""
        mesh = self.mesh_blocks()
        if not isinstance(index, int) or not 0 < index <= len(mesh):
            return None
        block = mesh[index - 1]
        cells = self._cells.get(id(block))
        if cells is None or cells.mesh is not block:
            cells = self._cells[id(block)] = icgeom.BlockCells(block)
        return cells

    def _target_cells(self):
        """``[(block, BlockCells)]``: the mesh blocks the selected row gives
        its state to (none without the mesh)."""
        target = self.current_target()
        owner = target[0] if isinstance(target, tuple) else target
        if owner is None:
            return []
        pairs = [(b, self._cells_of(b)) for b in self._users(owner)]
        return [(b, cells) for b, cells in pairs if cells is not None]

    def _users(self, owner):
        """The mesh blocks the section *owner* gives a state to."""
        if owner != "*":
            return [owner]
        return [b for b in range(1, self.block_count() + 1) if b not in self.icb.blocks]

    def _coverages(self, owner):
        """``[(block, BlockCoverage)]`` of the split section *owner* on the
        mesh blocks it gives a state to (none without the mesh)."""
        section = self._owner_section(owner)
        if section is None or not section.is_split or \
                icmodel.direction_issue(section.direction) or not section.direction:
            return []
        kinds = icmodel.block_kinds(section, self._phases)
        result = []
        for b in self._users(owner):
            cells = self._cells_of(b)
            if cells is not None:
                result.append((b, icgeom.BlockCoverage(cells, section, self.icb.zones, kinds)))
        return result

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(9)
        splitter.addWidget(self._build_list_panel())
        splitter.addWidget(self._build_editor_panel())
        splitter.addWidget(self._build_view_panel())
        # the editor and the view share the width; past the editor's widest, the view
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 1)
        splitter.setSizes([self.kit.px(300), self.kit.px(640), self.kit.px(560)])
        root.addWidget(splitter)

    def _build_list_panel(self):
        card = Card()
        kit = self.kit
        self.count_badge = kit.badge("0")
        card.body.addLayout(kit.panel_header("cube", "BLOCKS", self.count_badge))
        self.block_list = QListWidget()
        self.block_list.setObjectName("PhaseList")     # rows carry their margins
        self.block_list.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.block_list.setSelectionMode(
            QAbstractItemView.SelectionMode.SingleSelection)
        self.block_list.currentRowChanged.connect(lambda _row: self._rebuild_editor())
        self.block_list.currentRowChanged.connect(lambda _row: self._view_timer.start())
        card.body.addWidget(self.block_list, 1)
        card.body.addWidget(kit.hint(
            "All blocks is [ICB-Block*]: the state of every block without a "
            "section of its own. A block given its own state becomes "
            "[ICB-BlockN]. ICB writes one initial field per phase into "
            "fromATLAStoSolver/."))
        return card

    def _build_editor_panel(self):
        outer = QWidget()
        outer_layout = QHBoxLayout(outer)
        outer_layout.setContentsMargins(4, 0, 4, 4)
        self.editor_host = QWidget()
        self.kit.sized(self.editor_host.setMaximumWidth, 880)
        self.kit.sized(self.editor_host.setMinimumWidth, 420)
        self.editor_layout = QVBoxLayout(self.editor_host)
        self.editor_layout.setContentsMargins(0, 0, 0, 0)
        self.editor_layout.setSpacing(10)
        outer_layout.addWidget(self.editor_host)
        area = self.kit.scrollable(outer)
        self.kit.sized(area.setMaximumWidth, 900)    # the editor and its scroll bar
        return area

    def _build_view_panel(self):
        card = Card()
        kit = self.kit
        kit.sized(card.setMinimumWidth, 320)
        card.body.addLayout(kit.panel_header("cube", "3-D VIEW"))
        frame = QFrame()
        frame.setObjectName("ViewportFrame")
        lay = QVBoxLayout(frame)
        lay.setContentsMargins(3, 3, 3, 3)
        self.view = StateViewport()
        self.view.cell_picked.connect(self._on_cell_picked)
        lay.addWidget(self.view)
        card.body.addWidget(frame, 1)
        card.body.addWidget(kit.section_label("STATE OF EVERY CELL"))
        self.legend = QListWidget()
        self.legend.setSelectionMode(QAbstractItemView.SelectionMode.NoSelection)
        self.legend.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.legend.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.legend.setTextElideMode(Qt.TextElideMode.ElideMiddle)
        self.legend.setToolTip("The state ICB writes last into the cells of each colour, "
                               "and how many cells take it. Click one to open it.")
        self.legend.itemClicked.connect(self._on_legend_clicked)
        card.body.addWidget(self.legend)
        self.pick_label = kit.hint("Click a cell to open the state ICB writes into it.")
        card.body.addWidget(self.pick_label)
        return card

    def view_tools(self):
        """The 3-D view controls, shown in the shell header for this stage."""
        bar = QWidget()
        kit = self.kit
        lay = QHBoxLayout(bar)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(8)
        seg = QHBoxLayout()
        seg.setSpacing(0)
        for text, slot, pos in [("Iso", self.view.view_isometric, "left"),
                                ("XY", self.view.view_xy, "mid"),
                                ("XZ", self.view.view_xz, "mid"),
                                ("YZ", self.view.view_yz, "right")]:
            seg.addWidget(kit.button(text, slot, None, None, seg=pos, tip=f"{text} view"))
        lay.addLayout(seg)
        lay.addWidget(kit.button("Fit", self.view.reset_camera, "fit", "ghost",
                                 tip="Fit the mesh in the view", compactable=True))
        lay.addWidget(kit.vdivider())
        lay.addWidget(kit.toggle(
            "Mesh lines", self.view.set_edges, "mesh", self.view.edges,
            tip="Draw the edges of the cells."))
        lay.addWidget(kit.toggle(
            "Focus", self._set_focus, "target", True,
            tip="The cells of the selected state in full colour, the others dimmed; "
                "in 3-D, a selected block or zone shows the other blocks see-through."))
        return bar

    def close_viewport(self):
        self._view_timer.stop()
        self.view.close()

    # -------------------------------------------------------------- refresh
    def refresh(self):
        """Rebuild the list and the editor from the document."""
        self.reload_phases()
        self._issues = self.validate()
        self._refresh_list()
        self._rebuild_editor()
        self._refresh_view()

    def showEvent(self, event):
        super().showEvent(event)
        if self._view_stale:
            self._view_timer.start()

    # ------------------------------------------------------------- 3-D view
    @staticmethod
    def _state_key(target):
        """What a state's colour follows: its section."""
        return target[1] if isinstance(target, tuple) else ("block", target)

    @staticmethod
    def _key_label(key):
        return block_label(key[1]) if isinstance(key, tuple) else f"zone [{key}]"

    def _hue(self, key, hues):
        """The colour of state *key*: the first free slot when first seen,
        then the same slot for as long as the document is open."""
        if self._hues_doc is not self.shell.doc:
            self._hues_doc, self._hues = self.shell.doc, {}
        if key not in self._hues:
            self._hues[key] = len(self._hues)
        return hues[self._hues[key] % len(hues)]

    def _set_focus(self, on):
        self._focus = bool(on)
        self._refresh_view()

    def _focus_mask(self, b, smap, writer):
        """The cells of mesh block *b* the selected row's state writes, or
        None when nothing is singled out."""
        target = self.current_target()
        if not self._focus or target is None or (target == "*" and self.icb.wildcard is None):
            return None
        block = self.icb.block(b)
        if target == "*":
            return np.full(writer.size, block is not None and block.is_wildcard)
        if not isinstance(target, tuple):
            return np.full(writer.size, b == target)
        picked = [n for n, t in enumerate(smap.targets) if t == target]
        return np.isin(writer, picked)

    def _refresh_view(self):
        """Paint every cell of the mesh with the state ICB writes into it."""
        self._view_timer.stop()
        if not self.isVisible():
            self._view_stale = True
            return
        self._view_stale = False
        theme = self.shell.theme
        if self._view_theme is not theme:
            self._view_theme = theme
            self.view.apply_theme(theme)
        mesh = self.mesh_blocks()
        if mesh is not self._view_mesh:
            self._view_mesh = mesh
            self._picked = None
            self.view.set_mesh(mesh)
        self._maps = {}
        dark = QColor(theme["viewport_bg"]).lightnessF() < 0.5
        hues = STATE_HUES["dark" if dark else "light"]
        for target in self._targets:          # new states take their slots in list order
            if isinstance(target, tuple) or (self._owner_section(target) is not None
                                             and not self._owner_section(target).is_split):
                self._hue(self._state_key(target), hues)
        background = _rgb(theme["viewport_bg"])
        void = 0.5 * (_rgb(theme["unassigned"]) + background)
        three_d = any(m.nk > 2 for m in mesh)
        legend = OrderedDict()               # key -> [colour, cells, at rest, target]
        unwritten, unplaced = 0, []
        for b, block in enumerate(mesh, start=1):
            cells = self._cells_of(b)
            smap = self._maps[b] = icgeom.state_map(self.icb, b, cells, self._phases)
            writer = smap.writer.ravel(order="F")
            rest = smap.rest.ravel(order="F")
            written = writer >= 0
            colours = np.array([_rgb(self._hue(self._state_key(t), hues))
                                for t in smap.targets] or [void])
            rgb = np.empty((writer.size, 3))
            rgb[written] = colours[writer[written]]
            rgb[rest] += (255.0 - rgb[rest]) * REST_TINT
            rgb[~written] = void if smap.placed else _rgb(theme["unassigned"])
            focus = self._focus_mask(b, smap, writer)
            opacity = 1.0
            if focus is not None:
                rgb[~focus] += (background - rgb[~focus]) * DIM
                # All blocks reaches most of a mesh: only one block opens it up
                if three_d and not focus.any() and self.current_target() != "*":
                    opacity = SEE_THROUGH
            self.view.set_colors(b - 1, np.clip(np.rint(rgb), 0, 255).astype(np.uint8))
            self.view.set_block_opacity(b - 1, opacity)
            missing = np.flatnonzero(~written) if smap.placed else []
            self.view.set_outline(b - 1, missing, theme["danger"])
            if not smap.placed:
                unplaced.append(b)
            unwritten += len(missing)
            for n, target in enumerate(smap.targets):
                mine = writer == n
                if not mine.any():
                    continue
                key = self._state_key(target)
                entry = legend.setdefault(key, [self._hue(key, hues), 0, 0, target])
                entry[1] += int(mine.sum())
                entry[2] += int((mine & rest).sum())
        self.view.redraw()
        self._fill_legend(legend, unwritten, unplaced)
        self.pick_label.setText(self._describe_pick()[0])

    def _fill_legend(self, legend, unwritten, unplaced):
        self.legend.clear()
        try:
            self._legend_items(legend, unwritten, unplaced)
        finally:
            # as tall as its rows, up to eight: the view keeps the rest
            rows = min(max(self.legend.count(), 1), 8)
            frame = 2 * self.legend.frameWidth() + 4
            self.legend.setFixedHeight(rows * max(self.legend.sizeHintForRow(0), 1) + frame)

    def _legend_items(self, legend, unwritten, unplaced):
        if not self._view_mesh:
            item = QListWidgetItem("  Load the mesh to see the state of every cell")
            item.setForeground(QBrush(QColor(self.kit.color("muted"))))
            self.legend.addItem(item)
            return
        for key, (colour, count, rest, target) in legend.items():
            item = QListWidgetItem(f"  {self._key_label(key)}   · {count:,} cell"
                                   + ("" if count == 1 else "s"))
            item.setIcon(icons.dot(colour, 11))
            item.setData(Qt.ItemDataRole.UserRole, target)
            item.setToolTip(f"{self._key_label(key)}: ICB writes it last into {count:,} "
                            "cell(s). Click to open it.")
            self.legend.addItem(item)
            if rest:
                tint = "#%02x%02x%02x" % tuple(
                    int(round(c + (255 - c) * REST_TINT)) for c in _rgb(colour))
                item = QListWidgetItem(f"      plenum at rest, p0 and T0   · {rest:,} "
                                       "of them")
                item.setIcon(icons.dot(tint, 11))
                item.setData(Qt.ItemDataRole.UserRole, target)
                item.setToolTip("The rows of cells upstream of nozzle-threshold: the "
                                "nozzle law leaves them at rest.")
                self.legend.addItem(item)
        if unwritten:
            item = QListWidgetItem(f"  No state: ICB stops   · {unwritten:,} cell"
                                   + ("" if unwritten == 1 else "s"))
            item.setIcon(self.kit.icon("alert", "danger", 14))
            item.setToolTip("Cells no zone writes, outlined in the view. The checks "
                            "name the first of them.")
            self.legend.addItem(item)
        if unplaced:
            names = ", ".join(str(b) for b in unplaced)
            item = QListWidgetItem(f"  Zones not placed: block {names}")
            item.setIcon(self.kit.icon("alert", "warning", 14))
            item.setToolTip("Their direction letters are not ones ICB reads: see the checks.")
            self.legend.addItem(item)

    def _on_legend_clicked(self, item):
        target = item.data(Qt.ItemDataRole.UserRole)
        if target is not None:
            self.select_target(target)

    def _describe_pick(self):
        """``(text, target)``: the cell last clicked and the state it takes
        now, or the invitation to click one."""
        idle = ("Click a cell to open the state ICB writes into it.", None)
        if self._picked is None:
            return idle
        b, flat = self._picked
        smap, cells = self._maps.get(b), self._cells_of(b)
        if smap is None or cells is None:
            return idle
        i, j, k = (int(n) for n in np.unravel_index(flat, cells.shape, order="F"))
        letters = "xy" if cells.pure_2d else "xyz"
        where = ", ".join(f"{c} = {float(cells.coordinate(c)[i, j, k]):.4g}" for c in letters)
        writer = int(smap.writer[i, j, k])
        block = self.icb.block(b)
        if writer >= 0:
            target = smap.targets[writer]
            what = self._key_label(self._state_key(target))
            if smap.rest[i, j, k]:
                what += ", plenum at rest"
        else:
            target = block.index if block is not None else b
            what = ("no state: ICB stops on it" if smap.placed
                    else "the zones are not placed")
        return f"Block {b}, cell ({i + 1}, {j + 1}, {k + 1}) at {where}: {what}", target

    def _on_cell_picked(self, b0, flat):
        self._picked = (b0 + 1, flat)
        text, target = self._describe_pick()
        self.pick_label.setText(text)
        if target is not None:
            self.select_target(target)

    def select_target(self, target):
        """Show block *target* (an index, or ``"*"``)."""
        if target in self._targets:
            self.block_list.setCurrentRow(self._targets.index(target))

    def _levels(self, target):
        """The levels of the issues of *target*; a block's include its zones'."""
        return {level for level, t, _m in self._issues
                if t == target or (isinstance(t, tuple) and t[0] == target)}

    def _zone_ref(self, target):
        """``(n, ICZoneRef)`` of zone target ``(owner, section)``, or None."""
        owner, section = target
        block = self._owner_section(owner)
        if block is None:
            return None
        for n, ref in zip(block.zone_numbers(), block.zone_refs()):
            if ref.section == section:
                return n, ref
        return None

    @staticmethod
    def _range_text(direction, values):
        """``x 0 … 0.005,  r 0 … 0.1`` for a zone's range."""
        if len(values) != 2 * len(direction):
            return " ".join(values) or "no range"
        return ",  ".join(f"{letter} {values[2 * n]} … {values[2 * n + 1]}"
                          for n, letter in enumerate(direction))

    def _zone_row(self, target):
        owner, section = target
        block = self._owner_section(owner)
        found = self._zone_ref(target)
        zone = self.icb.zones.get(section)
        levels = {level for level, t, _m in self._issues if t == target}
        if found is None or block is None:
            return section, "not a zone of this block", "muted", section
        n, ref = found
        where = self._range_text(block.direction, ref.range)
        detail = f"{where}  ·  {zone.summary()}" if zone else f"{where}  ·  no section"
        token = ("danger" if "error" in levels or zone is None else
                 "warning" if "warning" in levels else "accent")
        tip = f"zone{n} of {block_label(owner)}: [{section}]"
        return section, detail, token, tip

    def _row(self, target):
        """``(title, detail, token, tip)`` of the list row of *target*."""
        if isinstance(target, tuple):
            return self._zone_row(target)
        levels = self._levels(target)
        title = block_label(target)
        if target == "*":
            block = self.icb.wildcard
            if block is None:
                return title, "no default state", "muted", "No [ICB-Block*] section"
            users = [b for b in range(1, self.block_count() + 1)
                     if b not in self.icb.blocks]
            detail = (f"{len(block.zone_refs())} zone(s) along {block.direction or '?'}"
                      if block.is_split else block.summary())
            tip = (f"[ICB-Block*]: the state of {len(users)} block(s)"
                   if users else "[ICB-Block*]: every block has its own section")
            status = "split" if block.is_split else "own"
        else:
            own = self.icb.blocks.get(target)
            dims = self._dims(target)
            if own is None and self.icb.wildcard is not None:
                return (title, "same as All blocks", "muted",
                        f"No [ICB-Block{target}]: takes [ICB-Block*]{dims}")
            if own is None:
                return (title, "no initial state", "danger",
                        f"No [ICB-Block{target}] and no [ICB-Block*]: ICB stops{dims}")
            if own.is_split:
                detail = (f"{len(own.zone_refs())} zone(s) along "
                          f"{own.direction or '?'}")
                status = "split"
            else:
                detail = own.summary()
                status = "own"
            tip = f"[ICB-Block{target}]{dims}"
        if "error" in levels:
            status = "error"
        elif "warning" in levels:
            status = "warning"
        return title, detail, STATUS_TOKENS[status], tip

    def _dims(self, target):
        mesh = getattr(self.shell.bcb_panel, "blocks", None) or []
        if isinstance(target, int) and 0 < target <= len(mesh):
            return "  ·  " + " × ".join(str(n) for n in mesh[target - 1].dims) + " nodes"
        return ""

    def _zone_targets(self, owner):
        section = self._owner_section(owner)
        if section is None or not section.is_split:
            return []
        targets = []
        for ref in section.zone_refs():
            if (owner, ref.section) not in targets:
                targets.append((owner, ref.section))
        return targets

    def _refresh_list(self):
        current = self.current_target()
        count = self.block_count()
        blocks = list(range(1, count + 1)) + [b for b in self.icb.blocks if b > count]
        self._targets = ["*"] + self._zone_targets("*")
        for b in blocks:
            self._targets += [b] + self._zone_targets(b)
        self._shown = {}
        self.block_list.blockSignals(True)
        self.block_list.clear()
        for target in self._targets:
            self.block_list.addItem(QListWidgetItem())
            self._refresh_row(target)
        row = self._targets.index(current) if current in self._targets else 0
        self.block_list.setCurrentRow(row)
        self.block_list.blockSignals(False)
        self.count_badge.setText(str(count))

    def _refresh_row(self, target):
        """Redraw the row of *target* when what it shows changed: an edit
        recolours rows across the list, and a mesh may have many blocks."""
        if target not in self._targets:
            return
        info = self._row(target)
        if self._shown.get(target) == info:
            return
        self._shown[target] = info
        item = self.block_list.item(self._targets.index(target))
        widget = BlockListItem(self.kit, *info, indent=18 if isinstance(target, tuple) else 0)
        # the height only: the row takes the width of the list, its summary elided
        item.setSizeHint(QSize(0, widget.sizeHint().height()))
        self.block_list.setItemWidget(item, widget)

    def _edited(self, rebuild=False):
        """After every edit: the checks, the list rows they colour, the shell."""
        if self._loading:
            return
        self._issues = self.validate()
        if rebuild:
            self._refresh_list()
            self._rebuild_editor()
        else:
            for target in self._targets:
                self._refresh_row(target)
            self._refresh_checks()
            self._refresh_layout_stats()
        self._view_timer.start()
        self.changed.emit()

    def _set(self, key, value):
        state = self.current_state()
        if state is None or self._loading:
            return
        state.set(key, value)
        self._edited()

    # The deck says which quantities give a state only once their values are
    # typed: a choice made before (total conditions, components, the radius)
    # is remembered here, for as long as the keys of the state still fit it.
    def _choice(self, state, what, detected, fits):
        remembered = self._choices.get(state, {}).get(what)
        if remembered is not None and remembered != detected and fits(remembered):
            return remembered
        return detected

    def _remember(self, state, what, value):
        self._choices.setdefault(state, {})[what] = value

    def _pair_of(self, state, pairs):
        given = {k for _l, keys in pairs.values() for k in keys
                 if icmodel.has_value_or_file(state, k)}
        what = "gas-pair" if pairs is GAS_PAIRS else "fluid-pair"
        return self._choice(state, what, icmodel.gas_pair(state, pairs),
                            lambda name: given <= set(pairs[name][1]))

    def _velocity_of(self, state, kinds):
        speed = [icmodel.SPEED_KEY[k] for k in ("IG", "RF") if k in kinds]
        return self._choice(
            state, "velocity", icmodel.velocity_mode(state),
            lambda mode: not any(state.has(k) for k in (
                speed + list(icmodel.ANGLE_KEYS) if mode == "components"
                else icmodel.COMPONENT_KEYS)))

    def _turbulence_form_of(self, state, kinds):
        """True for the density-weighted form (the only one a real fluid takes)."""
        if "RF" in kinds:
            return True
        specific = list(icmodel.WEIGHTED_KEY)
        weighted = list(icmodel.WEIGHTED_KEY.values())
        return self._choice(
            state, "turbulence-form", icmodel.turbulence_weighted(state),
            lambda form: not any(state.has(k) for k in (specific if form else weighted)))

    def _composition_of(self, state):
        constants = [k for k in state.species_keys()
                     if not k.endswith(("-file", "-direction"))]
        return self._choice(
            state, "composition", "cea" if state.has("eq-CEA-file") else "y",
            lambda source: not (constants if source == "cea"
                                else state.has("eq-CEA-file")))

    def _size_of(self, state):
        detected = "rp" if state.has("rp") and not state.has("dp") else "dp"
        return self._choice(state, "size", detected,
                            lambda key: not state.has("rp" if key == "dp" else "dp"))

    # ---------------------------------------------------------- editor build
    def _rebuild_editor(self):
        clear_layout(self.editor_layout)
        self._checks_box = None
        target = self.current_target()
        if target is None:
            return
        self._loading = True
        self.zone_table = None
        self.nozzle_plot = None
        try:
            state = self.current_state()
            if isinstance(target, tuple):
                self.editor_layout.addWidget(self._zone_card(target, state))
                cards = self._state_cards(state, zone=True) if state is not None else []
            else:
                self.editor_layout.addWidget(self._identity_card(target, state))
                cards = []
                if state is not None and state.is_split:
                    cards = [self._phases_card(state), self._layout_card(target, state)]
                elif state is not None:
                    cards = self._state_cards(state)
            for card in cards:
                self.editor_layout.addWidget(card)
            if state is not None:
                self.editor_layout.addWidget(self._checks_card())
                self.editor_layout.addWidget(self._footer_card(state))
            self.editor_layout.addStretch(1)
        finally:
            self._loading = False

    def _state_cards(self, state, zone=False):
        kinds = self._kinds(state)
        mode = state.mode
        cards = [] if zone else [self._phases_card(state)]
        cards.append(self._mode_card(state, kinds))
        if mode == "interpolate":
            cards.append(self._interpolation_card(state, kinds))
        elif mode == "nozzle":
            cards.append(self._nozzle_card(state))
        if mode == "uniform" and "IG" in kinds:
            cards.append(self._gas_card(state))
        if mode == "uniform" and "RF" in kinds:
            cards.append(self._real_fluid_card(state))
        if mode == "uniform" and kinds & {"IG", "RF"}:
            cards.append(self._velocity_card(state, kinds))
        if mode != "interpolate" and "IG" in kinds:
            cards.append(self._composition_card(state))
        if kinds & {"IG", "RF"}:
            cards.append(self._turbulence_card(state, kinds))
        if mode != "interpolate" and "SP" in kinds:
            cards.append(self._solid_card(state))
        if mode != "interpolate" and "DP" in kinds:
            cards.append(self._dispersed_card(state))
        return cards

    # -------------------------------------------------------- field helpers
    def _mark(self, edit, text):
        """Frame *edit* in the error colour when ICB cannot read *text*."""
        bad = bool(text.strip()) and any(
            icmodel.to_float(t) is None for t in text.split())
        if edit.property("invalid") != bad:
            edit.setProperty("invalid", bad)
            edit.style().unpolish(edit)
            edit.style().polish(edit)

    def _field(self, key, kind=None, placeholder="", numeric=True):
        """A line edit bound to *key*; a value given by a profile file shows
        the file and is not edited here."""
        state = self.current_state()
        edit = QLineEdit(state.get(key))
        edit.setToolTip(icmodel.describe(key, kind) or key)
        edit.setPlaceholderText(placeholder)
        profile = state.get(f"{key}-file")
        if profile:
            direction = state.get(f"{key}-direction")
            edit.setPlaceholderText(f"profile {profile}"
                                    + (f" along {direction}" if direction else " (field)"))
            edit.setEnabled(False)
            edit.setToolTip(f"{key} comes from {profile}, cell by cell: the profile "
                            "button edits it.")
        if numeric:
            self._mark(edit, edit.text())

        def commit(text, k=key, e=edit):
            if numeric:
                self._mark(e, text)
            self._set(k, text)

        edit.textEdited.connect(commit)
        return edit

    def _angle_field(self, key):
        """An angle shown in degrees; ICB reads radians, so that is what is
        written."""
        state = self.current_state()
        raw = state.get(key)
        value = icmodel.to_float(raw)
        edit = QLineEdit(f"{math.degrees(value):.10g}" if value is not None else raw)
        edit.setPlaceholderText("0")
        edit.setToolTip((icmodel.describe(key) or key)
                        + " Shown here in degrees, written in radians.")
        self._mark(edit, edit.text())

        def commit(text, k=key, e=edit):
            self._mark(e, text)
            number = icmodel.to_float(text)
            self._set(k, format(math.radians(number), ".12g")
                      if number is not None else text)

        edit.textEdited.connect(commit)
        return edit

    def _fields(self, entries, kind=None, columns=2):
        """A grid of ``label  [value]  unit`` for *entries*: ``(key, label)``
        pairs, bare keys labelled by themselves, or None for an empty cell.
        A value ICB can read from a profile has the profile button."""
        grid = QGridLayout()
        grid.setHorizontalSpacing(8)
        grid.setVerticalSpacing(8)
        state = self.current_state()
        capable = icmodel.profile_capable(self._kinds(state)) if state is not None else []
        for i, entry in enumerate(entries):
            if entry is None:
                continue
            key, label = entry if isinstance(entry, tuple) else (entry, entry)
            row, col = divmod(i, columns)
            name = QLabel(label + ":")
            name.setToolTip(icmodel.describe(key, kind) or key)
            edit = (self._angle_field(key) if key in icmodel.ANGLE_KEYS
                    else self._field(key, kind, PLACEHOLDERS.get(key, "")))
            cell = QHBoxLayout()
            cell.setSpacing(4)
            cell.addWidget(edit, 1)
            if key in capable:
                cell.addWidget(self._profile_button(key, label))
            unit = QLabel(UNITS.get(key, ""))
            unit.setProperty("role", "muted")
            self.kit.sized(unit.setMinimumWidth, 64)
            grid.addWidget(name, row, col * 3, Qt.AlignmentFlag.AlignRight)
            grid.addLayout(cell, row, col * 3 + 1)
            grid.addWidget(unit, row, col * 3 + 2)
        for col in range(columns):
            grid.setColumnStretch(col * 3 + 1, 1)
        return grid

    def _profile_button(self, key, label):
        state = self.current_state()
        given = icmodel.profile_of(state, key)
        tip = (f"{label} varies cell by cell, from {given[0]}"
               + (f" along {given[1]}" if given[1] else "") + ": edit the profile."
               if given else f"Give {label} cell by cell, from a table or a field.")
        button = self.kit.button("", lambda: self._edit_profile(key, label), "profile",
                                 "primary" if given else None, tip=tip)
        return button

    def _edit_profile(self, key, label):
        """The profile dialog of *key* in the state being edited."""
        state = self.current_state()
        target = self.current_target()
        if isinstance(target, tuple):
            owner, section = target
            block = self._owner_section(owner)
            ref = (self._zone_ref(target) or (None, None))[1]
            where, stem = f"zone [{section}] of {block_label(owner)}", section
        else:
            owner, block, ref = target, state, None
            where = block_label(owner)
            stem = "all" if owner == "*" else f"block{owner}"
        unit = UNITS.get(key, "")
        name = "".join(c if c.isalnum() or c in "-_" else "_" for c in f"{stem}-{key}")
        dialog = ProfileDialog(self, self.kit, key, label, unit, state, self.case_dir, where,
                               self._span_of(owner, block, ref),
                               self._table_coverage(owner, block, ref), f"{name}.dat")
        if dialog.exec() == QDialog.DialogCode.Accepted and dialog.outcome:
            self._edited(rebuild=True)

    def _form(self):
        form = QFormLayout()
        form.setContentsMargins(0, 0, 0, 0)
        form.setSpacing(8)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        return form

    def _segmented(self, options, current, slot, disabled=None):
        """Exclusive buttons for *options* (``(value, label)``); *disabled*
        maps a value to the reason it cannot be chosen."""
        disabled = disabled or {}
        box = QWidget()
        row = QHBoxLayout(box)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(0)
        group = QButtonGroup(box)
        group.setExclusive(True)
        for i, (value, label) in enumerate(options):
            position = ("left" if i == 0 else
                        "right" if i == len(options) - 1 else "mid")
            button = self.kit.button(label, None, None, seg=position)
            button.setCheckable(True)
            button.setChecked(value == current)
            if value in disabled:
                button.setEnabled(False)
                button.setToolTip(disabled[value])
            button.clicked.connect(lambda _checked=False, v=value: slot(v))
            group.addButton(button)
            row.addWidget(button)
        row.addStretch(1)
        return box

    def _combo(self, key, items, current=None, editable=False):
        """A combo over ``(value, label)`` *items* writing *key*."""
        state = self.current_state()
        combo = QComboBox()
        combo.setEditable(editable)
        for value, label in items:
            combo.addItem(label, value)
        value = state.get(key) if current is None else current
        index = combo.findData(value)
        if index >= 0:
            combo.setCurrentIndex(index)
        elif value:
            combo.addItem(value, value)
            combo.setCurrentIndex(combo.count() - 1)
        combo.setToolTip(icmodel.describe(key) or key)

        def commit(_index=None, k=key, c=combo):
            data = c.currentData()
            if c.isEditable() and c.currentText() != c.itemText(c.currentIndex()):
                data = c.currentText()
            self._set(k, data or "")

        combo.currentIndexChanged.connect(commit)
        if editable:
            combo.editTextChanged.connect(lambda _t: commit())
        return combo

    def _file(self, key, items=()):
        """A file key: an editable combo, a mark saying whether ICB will find
        the file, and *Browse…* (``filekeys``, context ``icb-section``)."""
        state = self.current_state()
        role = filekeys.role_of(key, "icb-section")
        combo = QComboBox()
        combo.setEditable(True)
        for value in items:
            combo.addItem(value, value)
        combo.setCurrentText(state.get(key))
        combo.setToolTip(icmodel.describe(key) or key)
        mark = QLabel()
        mark.setFixedWidth(self.kit.px(18))

        def repaint():
            current = self.current_state()
            value = current.get(key) if current is not None else ""
            status, _path, why = filekeys.status(value, self.case_dir, role)
            mark.setPixmap(self.kit.pixmap(STATE_ICON[status], STATE_TOKEN[status], 15))
            mark.setToolTip(why or "")

        def commit(text):
            self._set(key, text)
            repaint()

        def browse():
            current = self.current_state()
            value = pick_value(self, role, current.get(key), self.case_dir)
            if value is not None:
                combo.setCurrentText(value)
                commit(value)

        combo.editTextChanged.connect(commit)
        box = QWidget()
        row = QHBoxLayout(box)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(7)
        row.addWidget(combo, 1)
        row.addWidget(mark)
        row.addWidget(self.kit.button("Browse…", browse, "open",
                                      tip=role.hint or f"Choose the {role.label}"))
        self.kit.register_repaint(repaint)
        repaint()
        return box

    def _confirm_drop(self, title, keys, why=None):
        """True when no value would be lost, or the user agrees to lose it;
        *why* says what replaces them."""
        state = self.current_state()
        lost = [f"{k} = {state.get(k)}" for k in keys if state.get(k)]
        if not lost:
            return True
        reply = QMessageBox.question(
            self, title,
            (why or "These values are not read in the new setting and will be removed:")
            + "\n\n" + "\n".join(lost[:10]) + ("\n…" if len(lost) > 10 else "")
            + "\n\nContinue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
        return reply == QMessageBox.StandardButton.Yes

    # -------------------------------------------------------------- cards
    def _identity_card(self, target, state):
        card = Card()
        kit = self.kit
        head = QHBoxLayout()
        head.setSpacing(8)
        head.addWidget(kit.icon_label("thermo", "accent", 16))
        section = "[ICB-Block*]" if target == "*" else f"[ICB-Block{target}]"
        head.addWidget(kit.section_label(f"{block_label(target).upper()}  ·  {section}"))
        head.addStretch(1)
        card.body.addLayout(head)

        actions = QHBoxLayout()
        actions.setSpacing(7)
        users = [b for b in range(1, self.block_count() + 1) if b not in self.icb.blocks]
        if target == "*":
            if state is None:
                text = ("No default state. Give one here and every block without "
                        "a section of its own takes it — the usual start.")
                actions.addWidget(kit.button("Give all blocks a state",
                                             lambda: self._create("*"), "plus", "primary"))
            else:
                text = (f"The state of {len(users)} block(s) without a section of "
                        "their own." if users else
                        "Every block has a section of its own: this state is not used.")
                if state.is_split:
                    text += self._split_text(state)
                actions.addWidget(self._split_button("*", state))
                actions.addWidget(kit.button("Remove", lambda: self._remove("*"),
                                             "trash", "danger"))
        elif state is None:
            if self.icb.wildcard is not None:
                text = "This block takes the state of All blocks."
                actions.addWidget(kit.button("Give it its own state",
                                             lambda: self._create(target, copy=True),
                                             "plus", "primary"))
                actions.addWidget(kit.button("Edit All blocks",
                                             lambda: self.select_target("*"), "pencil"))
            else:
                text = "No initial state: ICB stops on this block."
                actions.addWidget(kit.button("Give it a state",
                                             lambda: self._create(target), "plus", "primary"))
                actions.addWidget(kit.button("Give all blocks a state",
                                             lambda: self._create("*")))
        else:
            text = ("Its own state, which overrides All blocks."
                    if self.icb.wildcard is not None else "Its own state.")
            if state.is_split:
                text += self._split_text(state)
            actions.addWidget(self._split_button(target, state))
            actions.addWidget(kit.button(
                "Use All blocks instead" if self.icb.wildcard is not None else "Remove",
                lambda: self._remove(target), "trash", "danger"))
        actions.addStretch(1)
        card.body.addWidget(kit.hint(text))
        card.body.addLayout(actions)
        return card

    @staticmethod
    def _split_text(state):
        return (f" It is split into {len(state.zone_refs())} zone(s) along "
                f"{state.direction or '?'}: each takes the cells of its range, "
                "a later zone over an earlier one.")

    def _split_button(self, target, state):
        if state.is_split:
            return self.kit.button(
                "Merge the zones…", lambda: self._merge(target), "layers",
                tip="Give the block one state again: that of one of its zones.")
        return self.kit.button(
            "Split into zones…", lambda: self._split(target), "split",
            tip="Give parts of the block different states, by coordinate, "
                "radius, angle or cell index.")

    def _create(self, target, copy=False):
        block = self.icb.own_block(target)
        if copy and self.icb.wildcard is not None and not block.params:
            block.params = OrderedDict(self.icb.wildcard.params)
        self._edited(rebuild=True)

    def _remove(self, target):
        if target == "*":
            users = [b for b in range(1, self.block_count() + 1)
                     if b not in self.icb.blocks]
            text = (f"{len(users)} block(s) take this state: without it ICB stops "
                    "on them." if users else "No block takes this state.")
        else:
            text = ("The block takes the state of All blocks again."
                    if self.icb.wildcard is not None else
                    "The block is left without a state: ICB stops on it.")
        reply = QMessageBox.question(
            self, "Remove the state", text + "\n\nRemove its section?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
        if reply != QMessageBox.StandardButton.Yes:
            return
        self.icb.remove_block(target)
        self._edited(rebuild=True)

    def _phases_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("layers", "PHASES"))
        if not self._phases:
            card.body.addWidget(kit.hint(
                "No phase in the deck and no *phase.txt in the case directory: "
                "ICB then builds one unnamed ideal gas."))
            return card
        chosen = state.phases
        chips = QHBoxLayout()
        chips.setSpacing(7)
        for phase in self._phases:
            chip = kit.toggle(f"{phase.label}  ·  {icmodel.KIND_LABEL[phase.kind]}",
                              None, "check", not chosen or phase.name in chosen,
                              compactable=False)
            if not phase.name:
                chip.setEnabled(False)
                chip.setToolTip("An unnamed phase (phase.txt) cannot be named in "
                                "the phase key: a block without the key builds it.")
            else:
                chip.setToolTip(f"From {phase.source}" if phase.source != "deck"
                                else "From the Phases stage")
                chip.toggled.connect(
                    lambda on, n=phase.name: self._toggle_phase(n, on))
            chips.addWidget(chip)
        chips.addStretch(1)
        card.body.addLayout(chips)
        card.body.addWidget(kit.hint(
            "Every phase selected is the same as none: the block builds them "
            "all, as ICB does when the phase key is absent."))
        return card

    def _toggle_phase(self, name, on):
        state = self.current_state()
        named = [p.name for p in self._phases if p.name]
        chosen = state.phases or list(named)
        if on and name not in chosen:
            chosen.append(name)
        elif not on and name in chosen:
            chosen.remove(name)
        if set(chosen) >= set(named):
            chosen = []
        elif not chosen:
            QMessageBox.information(self, "Phases", "A block builds at least one phase.")
            self._rebuild_editor()
            return
        state.phases = [n for n in named if n in chosen]
        self._edited(rebuild=True)

    def _mode_card(self, state, kinds):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("sliders", "HOW THE FIELD IS BUILT"))
        row = QHBoxLayout()
        row.setSpacing(10)
        row.addWidget(self._segmented(list(icmodel.MODES.items()), state.mode,
                                      self._set_mode), 1)
        row.addWidget(self._special_button(state, kinds))
        card.body.addLayout(row)
        card.body.addWidget(kit.hint(MODE_BLURBS[state.mode]))
        return card

    def _special_button(self, state, kinds):
        """The special initialisations, apart from the general modes: laws for
        one kind of geometry, offered where the block fits them."""
        current = state.mode if state.mode in icmodel.SPECIAL_MODES else None
        button = self.kit.button(
            icmodel.SPECIAL_MODES[current] if current else "Special", None, "nozzle",
            "special", tip="Initialisations for one kind of geometry, such as the "
                           "flow of a nozzle from its plenum.")
        button.setProperty("active", bool(current))
        menu = QMenu(button)
        menu.setToolTipsVisible(True)
        for mode, label in icmodel.SPECIAL_MODES.items():
            reason = "" if mode == current else self._special_reason(kinds, mode)
            action = menu.addAction(f"{label} — {SPECIAL_TAGLINES[mode]}")
            action.setToolTip(MODE_BLURBS[mode])
            action.setCheckable(True)
            action.setChecked(mode == current)
            action.setEnabled(not reason)
            if mode == current:
                action.triggered.connect(lambda _c=False, a=action: a.setChecked(True))
            else:
                action.triggered.connect(lambda _c=False, m=mode: self._set_mode(m))
            if reason:
                menu.addAction("      " + reason).setEnabled(False)
        if current:
            menu.addSeparator()
            back = menu.addAction("Back to a uniform state")
            back.triggered.connect(lambda _c=False: self._set_mode("uniform"))
        button.setMenu(menu)
        return button

    def _special_reason(self, kinds, mode):
        """Why the special *mode* does not fit the selected row, or ""."""
        if mode == "nozzle":
            if "IG" not in kinds:
                return "the law builds an ideal gas, and this block has none"
            for b, cells in self._target_cells():
                if cells.nozzle().short:
                    return f"Block {b} is not a nozzle along x: {cells.nozzle().short}"
        return ""

    def _set_mode(self, mode):
        state = self.current_state()
        if state is None or mode == state.mode:
            return
        leaving = {"interpolate": ("old-solution", "old-block-id", "interpolation-law",
                                   "theta", "nz", "old-species"),
                   "nozzle": icmodel.NOZZLE_KEYS}.get(state.mode, ())
        if mode == "nozzle" and self._kinds(state) == {"IG"}:
            # the law sets them in every row; another phase of the block may read them
            leaving += tuple(f"{k}{suffix}" for k in icmodel.NOZZLE_SETS
                             for suffix in ("", "-file", "-direction"))
        if not self._confirm_drop("Change the mode", leaving):
            self._rebuild_editor()
            return
        state.clear(*leaving)
        state.set_mode(mode)
        self._edited(rebuild=True)

    def _gas_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("thermo", "GAS STATE"))
        pair = self._pair_of(state, GAS_PAIRS)
        combo = QComboBox()
        for name, (label, _keys) in GAS_PAIRS.items():
            combo.addItem(label, name)
        combo.setCurrentIndex(combo.findData(pair))
        combo.setToolTip("The two quantities that fix the state; ICB derives the "
                         "rest from the thermo table of the phase.")
        combo.currentIndexChanged.connect(
            lambda _i, c=combo: self._set_pair(c.currentData(), GAS_PAIRS))
        form = self._form()
        form.addRow("Given as:", combo)
        card.body.addLayout(form)
        card.body.addLayout(self._fields(GAS_PAIRS[pair][1], "IG"))
        if {"p0", "T0"} & set(GAS_PAIRS[pair][1]):
            card.body.addWidget(kit.hint(
                "Total conditions are expanded to the static state at the speed "
                "below, a Mach number or u, v, w: T from the enthalpy balance, p "
                "on the isentrope, as at the solvers' inlet."))
        elif "rho" in GAS_PAIRS[pair][1]:
            card.body.addWidget(kit.hint(
                "The third quantity follows from the ideal-gas law."))
        return card

    def _set_pair(self, name, pairs):
        state = self.current_state()
        if state is None or self._loading:
            return
        keep = set(pairs[name][1])
        dropped = [k for _label, keys in pairs.values() for k in keys if k not in keep]
        if not self._confirm_drop("Change the given quantities", sorted(set(dropped))):
            self._rebuild_editor()
            return
        icmodel.set_gas_pair(state, name, pairs)
        self._remember(state, "gas-pair" if pairs is GAS_PAIRS else "fluid-pair", name)
        self._edited(rebuild=True)

    def _real_fluid_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("palette", "REAL FLUID"))
        pair = self._pair_of(state, REAL_FLUID_PAIRS)
        combo = QComboBox()
        for name, (label, _keys) in REAL_FLUID_PAIRS.items():
            combo.addItem(label, name)
        combo.setCurrentIndex(combo.findData(pair))
        combo.currentIndexChanged.connect(
            lambda _i, c=combo: self._set_pair(c.currentData(), REAL_FLUID_PAIRS))
        form = self._form()
        form.addRow("Given as:", combo)
        card.body.addLayout(form)
        card.body.addLayout(self._fields(REAL_FLUID_PAIRS[pair][1], "RF"))
        card.body.addWidget(kit.hint(
            "The (p, h) table of the phase gives the temperature from the "
            "enthalpy, or the enthalpy from the temperature."))
        return card

    def _velocity_card(self, state, kinds):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("target", "VELOCITY"))
        mode = self._velocity_of(state, kinds)
        card.body.addWidget(self._segmented(
            [("speed", "Speed and direction"), ("components", "Components")],
            mode, lambda m: self._set_velocity_mode(m, kinds)))
        if mode == "components":
            card.body.addLayout(self._fields(icmodel.COMPONENT_KEYS, columns=3))
            card.body.addWidget(kit.hint("Cartesian components; the angles are not read."))
        else:
            speed = [(icmodel.SPEED_KEY[k], "Mach" if k == "IG" else "speed")
                     for k in ("IG", "RF") if k in kinds]
            speed += [None] * (len(speed) % 2)      # the angles share a row
            card.body.addLayout(self._fields(speed + [("alpha", "α"), ("beta", "β")]))
            card.body.addWidget(kit.hint(
                "α turns the flow in the x-y plane from x towards y, β lifts it "
                "towards z: the direction (cos α cos β, sin α cos β, sin β) of the "
                "solvers' inflow BC. Without angles the flow is along x."))
        return card

    def _set_velocity_mode(self, mode, kinds):
        state = self.current_state()
        if state is None or mode == self._velocity_of(state, kinds):
            return
        if mode == "components":
            keys = [icmodel.SPEED_KEY[k] for k in ("IG", "RF") if k in kinds]
            keys += list(icmodel.ANGLE_KEYS)
        else:
            keys = list(icmodel.COMPONENT_KEYS)
        if not self._confirm_drop("Change the velocity input", keys):
            self._rebuild_editor()
            return
        for kind in ("IG", "RF"):
            if kind in kinds:
                icmodel.set_velocity_mode(state, mode, kind)
        self._remember(state, "velocity", mode)
        self._edited(rebuild=True)

    # -- composition ------------------------------------------------------
    def _composition_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("palette", "COMPOSITION"))
        species = icmodel.gas_species(self._phase_block(state), self._phases)
        if species is not None and len(species) == 1:
            card.body.addWidget(kit.hint(
                f"One species, {species[0]}: its mass fraction is 1."))
            return card
        source = self._composition_of(state)
        card.body.addWidget(self._segmented(
            [("y", "Mass fractions"), ("cea", "CEA equilibrium")], source,
            self._set_composition_source))
        if source == "cea":
            form = self._form()
            form.addRow("CEA deck:", self._file(
                "eq-CEA-file", database.cea_files(self.case_dir)))
            form.addRow("section:", self._field("eq-CEA-section", placeholder="1"))
            card.body.addLayout(form)
            toggle = kit.toggle("Gaseous products only (eq-OG)", None, "check",
                                state.get("eq-OG").strip().upper() in ("T", "TRUE", ".TRUE."),
                                tip=icmodel.describe("eq-OG"), compactable=False)
            toggle.toggled.connect(lambda on: self._set("eq-OG", "T" if on else ""))
            row = QHBoxLayout()
            row.addWidget(toggle)
            row.addStretch(1)
            card.body.addLayout(row)
            card.body.addWidget(kit.hint(
                "The equilibrium of the CEA deck gives the mass fractions (and, "
                "in a nozzle, p0 and T0 when the deck sets them)."))
            return card
        card.body.addWidget(self._species_table(state, species))
        tools = QHBoxLayout()
        tools.setSpacing(7)
        self.sum_label = QLabel()
        tools.addWidget(self.sum_label)
        tools.addStretch(1)
        tools.addWidget(kit.button(
            "Fill to 1", self._fill_rest, "check",
            tip="Give the selected species what the others leave: 1 − Σ y."))
        tools.addWidget(kit.button(
            "Profile…", self._edit_species_profile, "profile",
            tip="Give the mass fraction of the selected species cell by cell, "
                "from a table or a field."))
        if species is None:
            tools.addWidget(kit.button(
                "Add species…", self._add_species, "plus",
                tip="The species of this gas are not known until GPB has run "
                    "(or the phase lists them): add a mass fraction by name."))
        card.body.addLayout(tools)
        self._refresh_sum()
        if species is None:
            card.body.addWidget(kit.hint(
                "The species of the gas are not known yet (run GPB, or list "
                "them in the Phases stage); the mass fractions given are kept."))
        else:
            card.body.addWidget(kit.hint(
                "A species left empty keeps 1e-20. The mass fractions must sum "
                "to 1 within 1e-3: ICB renormalises a smaller deviation."))
        return card

    def _species_table(self, state, species):
        given = state.mass_fractions()
        profiles = {icmodel.species_of_key(k): state.get(k)
                    for k in state.species_keys() if k.endswith("-file")}
        names = list(species or [])
        names += [s for s in list(given) + list(profiles) if s not in names]
        table = QTableWidget(len(names), 2)
        table.setHorizontalHeaderLabels(["SPECIES", "MASS FRACTION"])
        table.verticalHeader().setVisible(False)
        table.setShowGrid(False)
        self.kit.table_rows(table, 28)
        table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        for row, name in enumerate(names):
            item = QTableWidgetItem(name)
            item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEditable)
            if species is not None and name not in species:
                item.setForeground(self.kit.color_brush("danger_text"))
                item.setToolTip("Not a species of this gas: ICB refuses the key")
            table.setItem(row, 0, item)
            if name in profiles:
                value = QTableWidgetItem(f"profile {profiles[name]}")
                value.setFlags(value.flags() & ~Qt.ItemFlag.ItemIsEditable)
                value.setForeground(self.kit.color_brush("muted"))
            else:
                value = QTableWidgetItem(given.get(name, ""))
            table.setItem(row, 1, value)
        table.cellChanged.connect(self._commit_fraction)
        table.cellDoubleClicked.connect(
            lambda r, c: c == 1 and r < len(names) and names[r] in profiles
            and self._edit_species_profile())
        height = self.kit.px(34 + 29 * max(len(names), 1) + 6)
        table.setMinimumHeight(min(height, self.kit.px(160)))
        table.setMaximumHeight(max(min(height, self.kit.px(330)), self.kit.px(90)))
        self.species_table = table
        return table

    def _commit_fraction(self, row, column):
        if self._loading or column != 1:
            return
        name = self.species_table.item(row, 0).text()
        item = self.species_table.item(row, 1)
        if item.text().startswith("profile "):
            return
        self._set(f"y{name}", item.text().strip())
        self._refresh_sum()

    def _edit_species_profile(self):
        row = self.species_table.currentRow()
        if row < 0:
            self.shell.warn("Profile", "Select the species whose mass fraction varies.")
            return
        name = self.species_table.item(row, 0).text()
        self._edit_profile(f"y{name}", f"y{name}")

    def _refresh_sum(self):
        state = self.current_state()
        values = [icmodel.to_float(v) for v in state.mass_fractions().values()]
        if any(k.endswith("-file") for k in state.species_keys()):
            self.sum_label.setText("Σ y: ICB adds the profiles to the constants and "
                                   "checks the sum cell by cell")
            self.sum_label.setProperty("check", None)
            self.sum_label.style().unpolish(self.sum_label)
            self.sum_label.style().polish(self.sum_label)
            return
        if not values:
            text, check = "Σ y = 0 (none given)", "fail"
        elif any(v is None for v in values):
            text, check = "Σ y: a value is not a number", "fail"
        else:
            total = sum(values)
            deviation = abs(1 - total)
            text = f"Σ y = {total:.6g}"
            if deviation <= icmodel.YSUM_EPS:
                check = "pass"
            elif deviation <= icmodel.YSUM_TOL + icmodel.YSUM_EPS:
                text, check = text + " (renormalised by ICB)", "pass"
            else:
                text, check = text + " — must be 1 within 1e-3", "fail"
        self.sum_label.setText(text)
        self.sum_label.setProperty("check", check)
        self.sum_label.style().unpolish(self.sum_label)
        self.sum_label.style().polish(self.sum_label)

    def _fill_rest(self):
        state = self.current_state()
        row = self.species_table.currentRow()
        if row < 0:
            self.shell.warn("Fill to 1", "Select the species that takes the rest.")
            return
        name = self.species_table.item(row, 0).text()
        others = [icmodel.to_float(v) for s, v in state.mass_fractions().items()
                  if s != name]
        if any(v is None for v in others):
            self.shell.warn("Fill to 1", "A mass fraction is not a number.")
            return
        rest = 1.0 - sum(others)
        if rest < 0:
            self.shell.warn("Fill to 1", "The other species already exceed 1.")
            return
        state.set(f"y{name}", format(rest, ".10g"))
        self._edited(rebuild=True)

    def _add_species(self):
        name, ok = QInputDialog.getText(self, "Add species", "Species name:")
        name = name.strip()
        if not ok or not name or any(c.isspace() for c in name):
            return
        state = self.current_state()
        if not state.has(f"y{name}"):
            state.set(f"y{name}", "0")
        self._edited(rebuild=True)

    def _set_composition_source(self, source):
        state = self.current_state()
        if source == "cea":
            keys = [k for k in state.species_keys() if not k.endswith(("-file", "-direction"))]
            if not self._confirm_drop("Use a CEA equilibrium", keys):
                self._rebuild_editor()
                return
            state.clear(*keys)
        else:
            keys = ["eq-CEA-file", "eq-CEA-section", "eq-OG"]
            if not self._confirm_drop("Give mass fractions", keys):
                self._rebuild_editor()
                return
            state.clear(*keys)
        self._remember(state, "composition", source)
        self._edited(rebuild=True)

    # -- turbulence -------------------------------------------------------
    def _turbulence_card(self, state, kinds):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("sliders", "TURBULENCE"))
        model = icmodel.turbulence_model(state)
        weighted = self._turbulence_form_of(state, kinds)
        combo = QComboBox()
        for value, label in TURBULENCE_MODELS.items():
            combo.addItem(label, value)
        if combo.findData(model) < 0:
            combo.addItem(f"nrans = {model}", model)
        combo.setCurrentIndex(combo.findData(model))
        combo.setToolTip("The model the solver runs: ICB writes its bands "
                         "(nrans 1, 2 or 7).")
        combo.currentIndexChanged.connect(
            lambda _i, c=combo: self._set_turbulence(c.currentData(), None))
        form = self._form()
        form.addRow("Model:", combo)
        card.body.addLayout(form)
        if model in icmodel.TURBULENCE_SPECIFIC:
            disabled = {}
            if "RF" in kinds:
                disabled["specific"] = ("A real-fluid table carries no density: "
                                        "give the density-weighted values.")
            card.body.addWidget(self._segmented(
                [("specific", "Specific (k, ω, ν̃)"),
                 ("weighted", "Density-weighted (ρk, ρω, ρν̃)")],
                "weighted" if weighted else "specific",
                lambda form_: self._set_turbulence(model, form_ == "weighted"),
                disabled))
            card.body.addLayout(self._fields(icmodel.turbulence_keys(model, weighted)))
        hint = {
            0: "No turbulence bands.",
            1: "ν̃ is the variable the Spalart-Allmaras model transports, not the "
               "eddy viscosity; about 3 ν in the free stream.",
            2: "Both k and ω: the solvers divide by them, so ICB refuses a zero.",
            7: "The normal stresses R11 = R22 = R33 and ω; the shear stresses "
               "are set to 1e-8.",
        }.get(model, "")
        if state.mode == "interpolate":
            hint += (" A source with turbulence bands brings its own; these "
                     "values fill a laminar source.")
        card.body.addWidget(kit.hint(hint.strip()))
        return card

    def _set_turbulence(self, model, weighted):
        state = self.current_state()
        if state is None or self._loading:
            return
        switching = weighted is not None          # the form, not the model
        if weighted is None:
            weighted = self._turbulence_form_of(state, self._kinds(state))
        keep = set(icmodel.turbulence_keys(model, weighted))
        dropped = [k for k in icmodel.TURBULENCE_KEYS if k not in keep and k != "nrans"]
        why = None
        if switching:
            new = " and ".join(icmodel.turbulence_keys(model, weighted))
            old = " and ".join(icmodel.turbulence_keys(model, not weighted))
            if weighted:
                why = (f"The density-weighted form reads {new}, which are {old} times "
                       f"the density. These specific values are removed: give {new} "
                       "in their place.")
            else:
                why = (f"The specific form reads {new}, which are {old} divided by "
                       f"the density. These density-weighted values are removed: give "
                       f"{new} in their place.")
        if not self._confirm_drop("Change the turbulence input", dropped, why):
            self._rebuild_editor()
            return
        icmodel.set_turbulence(state, model, weighted)
        self._remember(state, "turbulence-form", weighted)
        self._edited(rebuild=True)

    # -- solid, dispersed --------------------------------------------------
    def _solid_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("cube", "SOLID"))
        card.body.addLayout(self._fields(["T"], "SP"))
        materials = [m for p in self._kind_phases(state, "SP") for m in p.entries]
        form = self._form()
        items = [("", "(the first material)")] + [(m, m) for m in materials]
        form.addRow("material:", self._combo("material", items, editable=not materials))
        card.body.addLayout(form)
        card.body.addWidget(kit.hint(
            "The temperature T is shared with the gas of the block, as ICB reads "
            "one section for both. The material fills every cell of the state."))
        return card

    def _dispersed_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("layers", "DISPERSED PHASE"))
        count = sum(p.population_count() for p in self._kind_phases(state, "DP"))
        card.body.addLayout(self._fields(
            [("krho", "krho"), ("kT", "kT"), ("Pp", "Pp")], "DP", columns=3))
        size = self._size_of(state)
        card.body.addWidget(self._segmented(
            [("dp", "Diameter dp"), ("rp", "Radius rp")], size, self._set_size))
        card.body.addLayout(self._fields([size], "DP", columns=2))
        per = (f"one value for all {count} populations, or {count} values "
               "(material by material)" if count > 1 else "one value")
        card.body.addWidget(kit.hint(
            f"krho is the particle density over the gas density (0: no "
            f"particles), kT the temperature ratio (default 1); {per}."))
        return card

    def _set_size(self, key):
        state = self.current_state()
        other = "dp" if key == "rp" else "rp"
        value = state.get(other)
        number = icmodel.to_float(value)
        if number is not None and len(value.split()) == 1:
            state.set(key, format(number * (2.0 if key == "dp" else 0.5), ".10g"))
        elif value:
            state.set(key, value)
        state.clear(other)
        self._remember(state, "size", key)
        self._edited(rebuild=True)

    # -- nozzle, interpolation ---------------------------------------------
    def _nozzle_card(self, state):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("nozzle", "NOZZLE FLOW", kit.badge("special")))
        card.body.addLayout(self._fields(["p0", "T0"], "IG"))
        form = self._form()
        direction = self._combo("nozzle-direction", [
            ("dx", "towards +x (dx, the default)"), ("sx", "towards −x (sx)")])
        direction.currentIndexChanged.connect(lambda _i: self._refresh_nozzle())
        form.addRow("flow:", direction)
        threshold = self._field("nozzle-threshold", "IG", "none: no plenum")
        threshold.textEdited.connect(lambda _t: self._refresh_nozzle())
        row = QHBoxLayout()
        row.addWidget(threshold, 1)
        unit = QLabel("m")
        unit.setProperty("role", "muted")
        row.addWidget(unit)
        form.addRow("plenum ends at x:", row)
        card.body.addLayout(form)
        self.nozzle_plot = NozzlePlot(kit)
        card.body.addWidget(self.nozzle_plot)
        self.nozzle_check = QLabel()
        self.nozzle_check.setWordWrap(True)
        card.body.addWidget(self.nozzle_check)
        card.body.addWidget(kit.hint(
            "Every row of cells i is a cross-section, between the walls j = 1 and "
            "j = J; the throat is the smallest. The plenum is every row centred "
            "upstream of the threshold (below it towards +x, above it towards -x), "
            "over the whole cross-section of the block (also outside the range of a "
            "zone); without a threshold there is no plenum. The law "
            "gives every other row the Mach number of its A/A*: subsonic upstream "
            "of the throat, sonic at it, supersonic downstream, the velocity along "
            "the i lines."))
        self._refresh_nozzle()
        return card

    def _refresh_nozzle(self):
        """The cross-sections and the verdict of the nozzle card, after an edit."""
        plot = getattr(self, "nozzle_plot", None)
        state = self.current_state()
        if plot is None or state is None:
            return
        label = self.nozzle_check
        towards_minus = state.get("nozzle-direction").strip() == "sx"
        blocks = self._target_cells()
        label.setProperty("role", None)
        if not blocks:
            plot.set_data(None, None, towards_minus)
            label.setText("Load the mesh (Boundaries) to see the cross-sections of "
                          "the block and check that it is a nozzle.")
            label.setProperty("check", None)
            label.setProperty("role", "muted")
        else:
            b, cells = blocks[0]
            geometry = cells.nozzle()
            plenum = icgeom.plenum_rows(cells, state)
            plot.set_data(geometry, plenum, towards_minus,
                          icmodel.to_float(state.get("nozzle-threshold")))
            bad = [(n, c.nozzle()) for n, c in blocks if c.nozzle().problem]
            if bad:
                n, wrong = bad[0]
                label.setText(f"✗  Block {n} is not a nozzle along x: {wrong.problem}. "
                              "ICB stops on it: build it as a uniform state."
                              + (f" So do {len(bad) - 1} more block(s)." if len(bad) > 1
                                 else ""))
                label.setProperty("check", "fail")
            else:
                label.setText(self._nozzle_verdict(b, geometry, plenum, len(blocks)))
                label.setProperty("check", "pass")
        label.style().unpolish(label)
        label.style().polish(label)

    @staticmethod
    def _nozzle_verdict(b, geometry, at_rest, blocks):
        rows = geometry.rows
        throat = geometry.throat
        text = (f"✓  Block {b} is a nozzle along x: the throat at x = "
                f"{geometry.x[throat]:.4g} m (row {throat + 1} of {rows}), A/A* = "
                f"{geometry.ratio[0]:.3g} at the first row and {geometry.ratio[-1]:.3g} "
                "at the last.")
        if not at_rest.any():
            text += " No plenum: the law takes every row."
        elif at_rest.all():
            text += (" Every row is plenum, at rest: the whole block lies upstream of "
                     "the threshold.")
        else:
            first, last = (int(n) + 1 for n in np.flatnonzero(at_rest)[[0, -1]])
            text += (f" The plenum: row{'s' if last > first else ''} {first}"
                     + (f"–{last}" if last > first else "") + ", at rest at p0 and T0.")
        if throat in (0, rows - 1):
            text += (f" The throat is the {'first' if throat == 0 else 'last'} row: if "
                     "the nozzle goes on in another block, its narrowest section must "
                     "be in this one.")
        if blocks > 1:
            text += f" The other {blocks - 1} block(s) are nozzles too."
        return text

    def _interpolation_card(self, state, kinds):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("copy", "INTERPOLATION"))
        form = self._form()
        form.addRow("old solution:", self._file("old-solution"))
        law = state.get("interpolation-law")
        form.addRow("law:", self._combo("interpolation-law", list(LAW_LABELS.items())))
        block = self._field("old-block-id", placeholder="0 = every block")
        form.addRow("source block:", block)
        if law == "extrude":
            form.addRow("sector θ [deg]:", self._field("theta", placeholder="90"))
            form.addRow("sector cells:", self._field("nz", placeholder="4"))
        if "IG" in kinds:
            form.addRow("old species:", self._file("old-species"))
        card.body.addLayout(form)
        hints = ["The source is a Tecplot or VTK solution; its species are matched "
                 "by name through the phase file that old species locates "
                 "(a directory such as old/)."]
        if law == "extrude":
            hints.append("extrude revolves a 2-D source about x into a θ-degree "
                         "sector of nz cells, then each cell takes the nearest one.")
        card.body.addWidget(kit.hint(" ".join(hints)))
        return card

    # -- zones ---------------------------------------------------------------
    def _taken_names(self):
        """Names a new zone section cannot take: every section of the case,
        and the keyword BCs (BCB would read a section of that name)."""
        return self.shell.doc.section_names() | set(KEYWORD_BCS)

    @staticmethod
    def _zone_base(owner):
        return "all-zone" if owner == "*" else f"block{owner}-zone"

    def _default_pair(self, owner, letter):
        """``(low, high)`` along *letter* holding every cell of the blocks
        *owner* gives a state to: their extent on the mesh, else a range that
        holds any cell."""
        extents = [cells.extent(letter) for cells in
                   (self._cells_of(b) for b in self._users(owner)) if cells is not None]
        if not extents:
            low, high = UNBOUNDED[letter]
            return str(low), str(high)
        low, high = min(e[0] for e in extents), max(e[1] for e in extents)
        if letter in icgeom.INDEX_LETTERS or letter == "t":
            return str(int(low)), str(int(high))
        return icgeom.outward_limit(low, False), icgeom.outward_limit(high, True)

    def _count_cells(self, owner, direction, values):
        """The cells of the range *values* on the blocks of *owner*, or None
        without the mesh."""
        counts = [int(icgeom.range_mask(cells, direction, values).sum()) for cells in
                  (self._cells_of(b) for b in self._users(owner)) if cells is not None]
        return sum(counts) if counts else None

    def _zone_stats(self, owner):
        """``{section: (cells, kept)}`` of the zones of *owner* on the mesh."""
        stats = {}
        for _b, cover in self._coverages(owner):
            for zone in cover.zones:
                cells, kept = stats.get(zone.section, (0, 0))
                stats[zone.section] = (cells + zone.cells, kept + zone.kept)
        return stats

    def _zone_card(self, target, state):
        owner, section = target
        block = self._owner_section(owner)
        card = Card()
        kit = self.kit
        head = QHBoxLayout()
        head.setSpacing(8)
        head.addWidget(kit.icon_label("split", "accent", 16))
        head.addWidget(kit.section_label(f"ZONE  ·  [{section}]"))
        head.addStretch(1)
        card.body.addLayout(head)
        found = self._zone_ref(target)
        if found is None or block is None:
            card.body.addWidget(kit.hint("This zone is no longer listed by its block."))
            return card
        n, ref = found
        text = (f"Zone {n} of {len(block.zone_refs())} of {block_label(owner)}: the "
                f"cells with {self._range_text(block.direction, ref.range)}.")
        stats = self._zone_stats(owner).get(section)
        if stats:
            cells, kept = stats
            text += f" {cells:,} cells"
            text += (f", {cells - kept:,} of them written again by later zones."
                     if kept < cells else ".")
        others = [b for b in self.icb.blocks_naming_zone(section) if b is not block]
        if others:
            text += (" The same section is a zone of "
                     + ", ".join(block_label(b.index) for b in others)
                     + " too: an edit here changes it there.")
        if state is None:
            text = (f"zone{n} of {block_label(owner)} names [{section}], which is "
                    "not in the deck.")
        card.body.addWidget(kit.hint(text))
        actions = QHBoxLayout()
        actions.setSpacing(7)
        if state is None:
            actions.addWidget(kit.button("Create the section",
                                         lambda: self._create_zone_section(target),
                                         "plus", "primary"))
        else:
            actions.addWidget(kit.button("Rename…", lambda: self._ask_rename(target),
                                         "pencil"))
        actions.addWidget(kit.button(f"{block_label(owner)} layout",
                                     lambda: self.select_target(owner), "split",
                                     tip="The letters, the ranges and the order of the zones."))
        actions.addWidget(kit.button("Remove zone", lambda: self._remove_zone(owner, section),
                                     "trash", "danger"))
        actions.addStretch(1)
        card.body.addLayout(actions)
        return card

    def _layout_card(self, owner, block):
        card = Card()
        kit = self.kit
        refs = block.zone_refs()
        card.body.addLayout(kit.panel_header("split", "ZONES", kit.badge(str(len(refs)))))
        direction = block.direction
        letters = "".join(c for c in icgeom.LETTERS if c in direction)

        row = QHBoxLayout()
        row.setSpacing(8)
        row.addWidget(QLabel("Ranges along:"))
        box = QWidget()
        chips = QHBoxLayout(box)
        chips.setContentsMargins(0, 0, 0, 0)
        chips.setSpacing(0)
        for i, letter in enumerate(icgeom.LETTERS):
            position = ("left" if i == 0 else
                        "right" if i == len(icgeom.LETTERS) - 1 else "mid")
            unit = LETTER_UNITS.get(letter)
            tip = f"{letter}: {LETTER_TIPS[letter]}" + (f" [{unit}]" if unit else "")
            button = kit.button(letter, None, None, seg=position, tip=tip)
            button.setCheckable(True)
            button.setChecked(letter in letters)
            if len(letters) >= icgeom.MAX_LETTERS and letter not in letters:
                button.setEnabled(False)
                button.setToolTip(tip + "\nICB compares three letters at most.")
            button.toggled.connect(
                lambda on, c=letter: self._toggle_letter(owner, c, on))
            chips.addWidget(button)
        row.addWidget(box)
        row.addStretch(1)
        card.body.addLayout(row)

        columns = ["Zone"]
        for letter in direction:
            unit = LETTER_UNITS.get(letter)
            suffix = f" [{unit}]" if unit else ""
            columns += [f"{letter} from{suffix}", f"{letter} to{suffix}"]
        columns += ["Cells", "State"]
        table = QTableWidget(len(refs), len(columns))
        table.setHorizontalHeaderLabels(columns)
        table.verticalHeader().setVisible(False)
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        header = table.horizontalHeader()
        for col in range(len(columns)):
            header.setSectionResizeMode(col, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(len(columns) - 1, QHeaderView.ResizeMode.Stretch)
        kit.table_rows(table, 30)
        readonly = Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled
        for r, ref in enumerate(refs):
            zone = self.icb.zones.get(ref.section)
            table.setItem(r, 0, QTableWidgetItem(ref.section))
            values = list(ref.range) + [""] * max(0, 2 * len(direction) - len(ref.range))
            for c in range(2 * len(direction)):
                item = QTableWidgetItem(values[c])
                item.setTextAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
                table.setItem(r, 1 + c, item)
            cells = QTableWidgetItem("—")
            cells.setFlags(readonly)
            cells.setTextAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
            table.setItem(r, len(columns) - 2, cells)
            summary = QTableWidgetItem(zone.summary() if zone else "no section")
            summary.setFlags(readonly)
            summary.setToolTip("Double-click to edit the state of this zone.")
            table.setItem(r, len(columns) - 1, summary)
        table.itemChanged.connect(self._zone_item_changed)
        table.cellDoubleClicked.connect(
            lambda r, c: c >= len(columns) - 2 and self._open_zone(owner, r))
        height = (table.horizontalHeader().sizeHint().height()
                  + kit.px(30) * max(len(refs), 1) + 2 * table.frameWidth() + kit.px(14))
        table.setFixedHeight(height)
        if refs:
            table.selectRow(0)
        self.zone_table = table
        self._zone_owner = owner
        card.body.addWidget(table)

        tools = QHBoxLayout()
        tools.setSpacing(7)
        tools.addWidget(kit.button(
            "Add zone", lambda: self._add_zone(owner), "plus",
            tip="A copy of the selected zone, after it: then change its range "
                "and its state."))
        tools.addWidget(kit.button(
            "", lambda: self._move_zone(owner, -1), "chevron-up",
            tip="Write the selected zone earlier: the zones after it win the "
                "cells they share with it."))
        tools.addWidget(kit.button(
            "", lambda: self._move_zone(owner, 1), "chevron-down",
            tip="Write the selected zone later: it wins the cells it shares "
                "with the zones before it."))
        tools.addWidget(kit.button(
            "Remove", lambda: self._remove_zone(owner), "trash", "danger"))
        tools.addStretch(1)
        tools.addWidget(kit.button(
            "Edit its state", lambda: self._open_zone(owner), "pencil", "primary"))
        card.body.addLayout(tools)

        self.coverage_label = QLabel()
        self.coverage_label.setWordWrap(True)
        card.body.addWidget(self.coverage_label)
        self.extent_hint = kit.hint("")
        card.body.addWidget(self.extent_hint)
        card.body.addWidget(kit.hint(
            "ICB writes the zones in this order: a cell in two ranges takes the "
            "state of the later zone. The limits are included; x, y, z, r and t "
            "compare the cell centre, i, j and k the cell index."))
        self._refresh_layout_stats()
        return card

    def _refresh_layout_stats(self):
        """The cells of every zone and the coverage line, after an edit."""
        table = getattr(self, "zone_table", None)
        if table is None:
            return
        owner = self._zone_owner
        block = self._owner_section(owner)
        if block is None or not block.is_split:
            return
        covers = self._coverages(owner)
        stats = self._zone_stats(owner)
        column = table.columnCount() - 2
        self._loading = True
        try:
            for r, ref in enumerate(block.zone_refs()):
                item = table.item(r, column)
                if item is None:
                    continue
                zone = self.icb.zones.get(ref.section)
                summary = table.item(r, column + 1)
                if summary is not None:
                    summary.setText(zone.summary() if zone else "no section")
                cells, kept = stats.get(ref.section, (None, None))
                if cells is None:
                    item.setText("—")
                    item.setToolTip("Load the mesh to count the cells of this zone."
                                    if not self.mesh_blocks() else
                                    "The range cannot be read.")
                else:
                    item.setText(f"{cells:,}" if kept == cells else f"{cells:,} ({kept:,})")
                    item.setToolTip(f"{cells:,} cells in the range, {kept:,} of them "
                                    "not written again by a later zone.")
        finally:
            self._loading = False
        label = self.coverage_label
        if not self.mesh_blocks():
            label.setText("Load the mesh (Boundaries) to see which cells each zone "
                          "takes and whether every cell has one.")
            label.setProperty("check", None)
            label.setProperty("role", "muted")
        elif not covers:
            label.setText("The letters cannot be read: the cells of the zones are "
                          "counted once they are.")
            label.setProperty("check", "fail")
        else:
            gaps = [(b, cover, kind, count, first) for b, cover in covers
                    for kind, (count, first) in cover.unwritten.items()]
            if gaps:
                b, cover, _kind, count, first = gaps[0]
                more = len({g[0] for g in gaps}) - 1
                label.setText(
                    f"✗  {count:,} of {cover.total:,} cells of Block {b} are in no "
                    f"zone (the first is cell {first}): ICB stops on them."
                    + (f" So do {more} more block(s)." if more > 0 else ""))
                label.setProperty("check", "fail")
            else:
                total = sum(cover.total for _b, cover in covers)
                where = (f"Block {covers[0][0]}" if len(covers) == 1
                         else f"the {len(covers)} blocks")
                label.setText(f"✓  Every cell of {where} ({total:,} cells) is in a zone.")
                label.setProperty("check", "pass")
        label.style().unpolish(label)
        label.style().polish(label)
        if covers:
            cells = [self._cells_of(b) for b, _c in covers]
            parts = []
            for letter in block.direction:
                low, high = self._default_pair(owner, letter)
                unit = LETTER_UNITS.get(letter, "")
                parts.append(f"{letter} {low} … {high}{' ' + unit if unit else ''}")
            if len(cells) == 1:
                shape = " × ".join(str(n) for n in cells[0].shape) + " cells"
            else:
                shape = f"{len(cells)} blocks, {sum(c.count for c in cells):,} cells"
            flat = any(c.pure_2d for c in cells)
            self.extent_hint.setText(
                f"Extent: {',  '.join(parts)}  ·  {shape}"
                + (" (2-D: r and t in the x-y plane)" if flat else ""))
            self.extent_hint.show()
        else:
            self.extent_hint.hide()

    def _selected_zone_row(self):
        table = getattr(self, "zone_table", None)
        if table is None:
            return -1
        rows = table.selectionModel().selectedRows()
        return rows[0].row() if rows else table.currentRow()

    def _zone_item_changed(self, item):
        if self._loading:
            return
        owner = self._zone_owner
        block = self._owner_section(owner)
        refs, numbers = block.zone_refs(), block.zone_numbers()
        row, col = item.row(), item.column()
        if row >= len(refs):
            return
        ref, n = refs[row], numbers[row]
        if col == 0:
            if not self._rename_zone(ref.section, item.text().strip()):
                self._loading = True
                item.setText(ref.section)
                self._loading = False
            return
        width = 2 * len(block.direction)
        if 1 <= col <= width:
            values = list(ref.range) + [""] * max(0, width - len(ref.range))
            values[col - 1] = item.text().strip()
            bad = bool(values[col - 1]) and icmodel.to_float(values[col - 1]) is None
            item.setForeground(QBrush(QColor(self.kit.color("danger"))) if bad else
                               self.zone_table.palette().text())
            block.set(f"range{n}", " ".join(v for v in values if v))
            self._edited()
            self._refresh_row((owner, ref.section))

    def _open_zone(self, owner, row=None):
        block = self._owner_section(owner)
        refs = block.zone_refs() if block is not None else []
        row = self._selected_zone_row() if row is None else row
        if 0 <= row < len(refs):
            self.select_target((owner, refs[row].section))

    def _valid_zone_name(self, name, old=None):
        """``""`` when *name* can name a zone section, else why not."""
        if not name:
            return "A zone needs a name."
        if any(c in name for c in " \t[]=;#,"):
            return "A section name has no blanks and none of [ ] = ; # ,"
        if "Block" in name:
            return "ICB reads a section whose name holds 'Block' as a block, never as a zone."
        if name != old and name in self._taken_names():
            return f"[{name}] is already a section of the case."
        return ""

    def _rename_zone(self, old, new):
        if new == old:
            return True
        reason = self._valid_zone_name(new, old)
        if reason:
            QMessageBox.information(self, "Rename the zone", reason)
            return False
        self.icb.rename_zone(old, new)
        target = self.current_target()
        self._edited(rebuild=True)
        if isinstance(target, tuple) and target[1] == old:
            self.select_target((target[0], new))
        return True

    def _ask_rename(self, target):
        owner, section = target
        name, ok = QInputDialog.getText(self, "Rename the zone",
                                        f"New name of [{section}]:", text=section)
        if ok and self._rename_zone(section, name.strip()):
            self.select_target((owner, name.strip()))

    def _create_zone_section(self, target):
        self.icb.add_zone(target[1])
        self._edited(rebuild=True)
        self.select_target(target)

    def _toggle_letter(self, owner, letter, on):
        if self._loading:
            return
        block = self._owner_section(owner)
        current = "".join(c for c in icgeom.LETTERS if c in block.direction)
        new = "".join(c for c in icgeom.LETTERS
                      if (c in current and c != letter) or (c == letter and on))
        if not new:
            QMessageBox.information(
                self, "Zones", "The ranges of the zones are given along one letter "
                "at least. To give the block one state, merge its zones.")
            self._rebuild_editor()
            return
        if not on:
            reply = QMessageBox.question(
                self, "Zones", f"The ranges along {letter} are removed from every zone. "
                "Continue?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
            if reply != QMessageBox.StandardButton.Yes:
                self._rebuild_editor()
                return
        block.set_direction(new, lambda c: self._default_pair(owner, c))
        self._edited(rebuild=True)

    def _add_zone(self, owner):
        block = self._owner_section(owner)
        refs = block.zone_refs()
        row = self._selected_zone_row()
        row = row if 0 <= row < len(refs) else len(refs) - 1
        source = refs[row] if refs else None
        name = icmodel.unique_name(self._zone_base(owner), self._taken_names())
        state = self.icb.zones.get(source.section) if source else None
        self.icb.add_zone(name, icmodel.ICState(state.params if state else None))
        values = list(source.range) if source else []
        if not values:
            for letter in block.direction:
                values += list(self._default_pair(owner, letter))
        refs.insert(row + 1, icmodel.ICZoneRef(name, values))
        block.set_zones(block.direction, refs)
        self._edited(rebuild=True)
        if self.zone_table is not None:
            self.zone_table.selectRow(row + 1)

    def _move_zone(self, owner, step):
        block = self._owner_section(owner)
        refs = block.zone_refs()
        row = self._selected_zone_row()
        other = row + step
        if not (0 <= row < len(refs) and 0 <= other < len(refs)):
            return
        refs[row], refs[other] = refs[other], refs[row]
        block.set_zones(block.direction, refs)
        self._edited(rebuild=True)
        if self.zone_table is not None:
            self.zone_table.selectRow(other)

    def _remove_zone(self, owner, section=None):
        block = self._owner_section(owner)
        refs = block.zone_refs()
        if section is None:
            row = self._selected_zone_row()
            if not 0 <= row < len(refs):
                return
            section = refs[row].section
        if len(refs) <= 1:
            QMessageBox.information(
                self, "Remove the zone", "A split block keeps one zone at least. "
                "To give the block one state, merge its zones.")
            return
        shared = len(self.icb.blocks_naming_zone(section)) > 1
        reply = QMessageBox.question(
            self, "Remove the zone",
            f"Remove [{section}] from the zones of {block_label(owner)}? Its cells "
            "are left to the other zones whose ranges hold them."
            + ("" if shared else " Its section is removed with it."),
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
        if reply != QMessageBox.StandardButton.Yes:
            return
        block.set_zones(block.direction, [r for r in refs if r.section != section])
        self.icb.drop_unused_zones()
        if self.current_target() == (owner, section):
            self.select_target(owner)
        self._edited(rebuild=True)

    def _split(self, target):
        block = self._owner_section(target)
        dialog = SplitDialog(
            self, self.kit, block_label(target),
            lambda c: self._default_pair(target, c),
            lambda d, v: self._count_cells(target, d, v),
            self._zone_base(target), self._taken_names())
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        direction, ranges, names = dialog.result_values()
        self.icb.split_block(block, direction, ranges, names)
        self._edited(rebuild=True)

    def _merge(self, target):
        block = self._owner_section(target)
        refs = [r for r in block.zone_refs() if r.section in self.icb.zones]
        section = None
        if refs:
            items = [f"[{r.section}]  {self.icb.zones[r.section].summary()}" for r in refs]
            choice, ok = QInputDialog.getItem(
                self, "Merge the zones",
                f"{block_label(target)} takes one state again. Whose?", items, 0, False)
            if not ok:
                return
            section = refs[items.index(choice)].section
            lost = [r.section for r in refs if r.section != section
                    and len(self.icb.blocks_naming_zone(r.section)) == 1]
            if lost:
                reply = QMessageBox.question(
                    self, "Merge the zones",
                    "The states of " + ", ".join(f"[{n}]" for n in lost)
                    + " are removed with their sections. Continue?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
                if reply != QMessageBox.StandardButton.Yes:
                    return
        self.icb.merge_zones(block, section)
        self._edited(rebuild=True)

    # -- checks, footer -----------------------------------------------------
    def _checks_card(self):
        card = Card()
        card.body.addLayout(self.kit.panel_header("check", "CHECKS"))
        self._checks_box = QVBoxLayout()
        self._checks_box.setSpacing(5)
        card.body.addLayout(self._checks_box)
        self._refresh_checks()
        return card

    def _refresh_checks(self):
        box = getattr(self, "_checks_box", None)
        if box is None:
            return
        clear_layout(box)
        target = self.current_target()
        mine = [(level, message) for level, t, message in self._issues if t == target]
        if not isinstance(target, tuple):
            # a split block lists the issues of its zones too, named
            mine = [(level, m.split(": ", 1)[-1]) for level, m in mine]
            mine += [(level, f"[{t[1]}] " + m.split(": ", 1)[-1])
                     for level, t, m in self._issues
                     if isinstance(t, tuple) and t[0] == target]
        else:
            mine = [(level, m.split(": ", 1)[-1]) for level, m in mine]
        if not mine:
            label = QLabel("Nothing ICB would stop on in this state.")
            label.setProperty("check", "pass")
            box.addWidget(label)
            return
        order = {"error": 0, "warning": 1, "info": 2}
        for level, message in sorted(mine, key=lambda m: order[m[0]]):
            row = QHBoxLayout()
            row.setSpacing(8)
            dot = QLabel()
            dot.setPixmap(icons.dot_pixmap(
                self.kit.color("danger" if level == "error" else "warning"),
                self.kit.px(10)))
            row.addWidget(dot, 0, Qt.AlignmentFlag.AlignTop)
            text = self.kit.hint(message)
            text.setProperty("role", "value" if level == "error" else "hint")
            row.addWidget(text, 1)
            box.addLayout(row)

    def _footer_card(self, state):
        card = Card(margins=(12, 8, 12, 8))
        row = QHBoxLayout()
        row.setSpacing(8)
        row.addWidget(self.kit.icon_label("code", "muted", 15))
        row.addWidget(self.kit.hint(f"{len(state.params)} key(s) in this section"))
        row.addStretch(1)
        row.addWidget(self.kit.button("All keys…", self._edit_advanced, "sliders",
                                      tip="Edit the raw INI lines of this section."))
        card.body.addLayout(row)
        return card

    def _edit_advanced(self):
        state = self.current_state()
        keys = []
        for table in [icmodel.BLOCK_TABLE, icmodel.COMPOSITION_TABLE] + \
                list(icmodel.KIND_TABLES.values()):
            keys += [k for k in icmodel.REFERENCE.get(table, {})
                     if k not in keys and not k.startswith("yspecies")]
        dialog = AdvancedKeysDialog(
            self, self.kit, state, "All keys of this state", keys,
            lambda k: icmodel.describe(k), lambda k: icmodel.default_of(k))
        if dialog.exec() == QDialog.DialogCode.Accepted:
            dialog.apply_to_phase()
            self._edited(rebuild=True)


def _rgb(hex_colour):
    """``#rrggbb`` as an array of three floats from 0 to 255."""
    colour = QColor(hex_colour)
    return np.array([colour.red(), colour.green(), colour.blue()], dtype=float)
