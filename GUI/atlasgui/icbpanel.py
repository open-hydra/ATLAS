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
stop on before it runs.  A block split into zones is listed with its zones;
editing them comes with the zone editor.
"""

from __future__ import annotations

import math
import weakref
from collections import OrderedDict

from PyQt6.QtCore import QSize, Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QAbstractItemView, QButtonGroup, QComboBox, QDialog, QFormLayout,
    QGridLayout, QHBoxLayout, QHeaderView, QInputDialog, QLabel, QLineEdit,
    QListWidget, QListWidgetItem, QMessageBox, QSizePolicy, QSplitter,
    QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)

from . import database, filekeys, icmodel, icons
from .filewidgets import STATE_ICON, STATE_TOKEN, pick_value
from .gpbdialogs import AdvancedKeysDialog
from .icmodel import (GAS_PAIRS, REAL_FLUID_PAIRS, TURBULENCE_MODELS,
                      block_label)
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
    "uniform": "One state for every cell. A value can also come from a profile "
               "file (edited with All keys… for now): the state is then "
               "variable, cell by cell.",
    "nozzle": "A de Laval nozzle along x: the plenum upstream of the threshold "
              "keeps p0 and T0, downstream the quasi-1-D area law sets the "
              "Mach number of every row of cells. Ideal gas only.",
    "interpolate": "The state of an earlier solution, interpolated onto this "
                   "mesh. The composition and the turbulence bands come with it.",
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


class BlockListItem(QWidget):
    """Two-line row of the block list: the block, then where its state comes
    from in one line."""

    def __init__(self, kit, title, detail, token, tip):
        super().__init__()
        self.setObjectName("PhaseRow")
        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 7, 8, 7)
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
        value = str(self.shell.doc.parameters.get("strict-keys", "T")).strip()
        return value.upper() not in ("F", "FALSE", ".FALSE.", "NO", "0")

    def validate(self):
        """The ICB checks of the case, for the Review stage too."""
        return self.icb.validate(self.block_count(), self._phases, self.strict_keys())

    def current_target(self):
        row = self.block_list.currentRow()
        return self._targets[row] if 0 <= row < len(self._targets) else None

    def current_state(self):
        """The section the selected row edits: the wildcard, or the block's
        own section; None when the block has none."""
        target = self.current_target()
        if target == "*":
            return self.icb.wildcard
        return self.icb.blocks.get(target) if target is not None else None

    def _kinds(self, state):
        return icmodel.block_kinds(state, self._phases)

    def _kind_phases(self, state, kind):
        return [p for p in icmodel.block_phases(state, self._phases) if p.kind == kind]

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(9)
        splitter.addWidget(self._build_list_panel())
        splitter.addWidget(self._build_editor_panel())
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([self.kit.px(330), self.kit.px(1000)])
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
        outer_layout.addWidget(self.editor_host, 6)
        outer_layout.addStretch(1)
        return self.kit.scrollable(outer)

    # -------------------------------------------------------------- refresh
    def refresh(self):
        """Rebuild the list and the editor from the document."""
        self.reload_phases()
        self._issues = self.validate()
        self._refresh_list()
        self._rebuild_editor()

    def select_target(self, target):
        """Show block *target* (an index, or ``"*"``)."""
        if target in self._targets:
            self.block_list.setCurrentRow(self._targets.index(target))

    def _row(self, target):
        """``(title, detail, token, tip)`` of the list row of *target*."""
        levels = {level for level, t, _m in self._issues if t == target}
        title = block_label(target)
        if target == "*":
            block = self.icb.wildcard
            if block is None:
                return title, "no default state", "muted", "No [ICB-Block*] section"
            users = [b for b in range(1, self.block_count() + 1)
                     if b not in self.icb.blocks]
            detail = block.summary()
            tip = (f"[ICB-Block*]: the state of {len(users)} block(s)"
                   if users else "[ICB-Block*]: every block has its own section")
            status = "own"
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

    def _refresh_list(self):
        current = self.current_target()
        count = self.block_count()
        self._targets = ["*"] + list(range(1, count + 1))
        self._targets += [b for b in self.icb.blocks if b > count]
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
        widget = BlockListItem(self.kit, *info)
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
        try:
            state = self.current_state()
            self.editor_layout.addWidget(self._identity_card(target, state))
            if state is not None:
                if state.is_split:
                    self.editor_layout.addWidget(self._zones_card(state))
                else:
                    for card in self._state_cards(state):
                        self.editor_layout.addWidget(card)
                self.editor_layout.addWidget(self._checks_card())
                self.editor_layout.addWidget(self._footer_card(state))
            self.editor_layout.addStretch(1)
        finally:
            self._loading = False

    def _state_cards(self, state):
        kinds = self._kinds(state)
        mode = state.mode
        cards = [self._phases_card(state), self._mode_card(state, kinds)]
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
                                    + (f" along {direction}" if direction else ""))
            edit.setEnabled(False)
            edit.setToolTip(f"{key} comes from {profile}. Profiles are edited "
                            "with All keys… until the profile editor comes.")
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
        pairs, bare keys labelled by themselves, or None for an empty cell."""
        grid = QGridLayout()
        grid.setHorizontalSpacing(8)
        grid.setVerticalSpacing(8)
        for i, entry in enumerate(entries):
            if entry is None:
                continue
            key, label = entry if isinstance(entry, tuple) else (entry, entry)
            row, col = divmod(i, columns)
            name = QLabel(label + ":")
            name.setToolTip(icmodel.describe(key, kind) or key)
            edit = (self._angle_field(key) if key in icmodel.ANGLE_KEYS
                    else self._field(key, kind, PLACEHOLDERS.get(key, "")))
            unit = QLabel(UNITS.get(key, ""))
            unit.setProperty("role", "muted")
            self.kit.sized(unit.setMinimumWidth, 64)
            grid.addWidget(name, row, col * 3, Qt.AlignmentFlag.AlignRight)
            grid.addWidget(edit, row, col * 3 + 1)
            grid.addWidget(unit, row, col * 3 + 2)
        for col in range(columns):
            grid.setColumnStretch(col * 3 + 1, 1)
        return grid

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

    def _confirm_drop(self, title, keys):
        """True when no value would be lost, or the user agrees to lose it."""
        state = self.current_state()
        lost = [f"{k} = {state.get(k)}" for k in keys if state.get(k)]
        if not lost:
            return True
        reply = QMessageBox.question(
            self, title,
            "These values are not read in the new setting and will be removed:"
            "\n\n" + "\n".join(lost[:10]) + ("\n…" if len(lost) > 10 else "")
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
            actions.addWidget(kit.button(
                "Use All blocks instead" if self.icb.wildcard is not None else "Remove",
                lambda: self._remove(target), "trash", "danger"))
        actions.addStretch(1)
        card.body.addWidget(kit.hint(text))
        card.body.addLayout(actions)
        return card

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
        disabled = {}
        if "IG" not in kinds:
            disabled["nozzle"] = "The nozzle law builds an ideal gas, and this block has none."
        card.body.addWidget(self._segmented(
            list(icmodel.MODES.items()), state.mode, self._set_mode, disabled))
        card.body.addWidget(kit.hint(MODE_BLURBS[state.mode]))
        return card

    def _set_mode(self, mode):
        state = self.current_state()
        if state is None or mode == state.mode:
            return
        leaving = {"interpolate": ("old-solution", "old-block-id", "interpolation-law",
                                   "theta", "nz", "old-species"),
                   "nozzle": icmodel.NOZZLE_KEYS}.get(state.mode, ())
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
                "Total conditions are expanded to the static state at the Mach "
                "number of the velocity below."))
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
        if pairs is GAS_PAIRS and {"p0", "T0"} & keep:
            # total conditions need the Mach number (see _velocity_card)
            icmodel.set_velocity_mode(state, "speed", "IG")
            self._remember(state, "velocity", "speed")
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
        disabled = {}
        if self._needs_mach(state, kinds):
            disabled["components"] = (
                "With total conditions ICB needs the Mach number: it computes the "
                "static T before it would know the speed of u, v, w.")
        card.body.addWidget(self._segmented(
            [("speed", "Speed and direction"), ("components", "Components")],
            mode, lambda m: self._set_velocity_mode(m, kinds), disabled))
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

    def _needs_mach(self, state, kinds):
        """A gas given by total conditions takes its speed as a Mach number."""
        return "IG" in kinds and bool(
            {"p0", "T0"} & set(GAS_PAIRS[self._pair_of(state, GAS_PAIRS)][1]))

    def _set_velocity_mode(self, mode, kinds):
        state = self.current_state()
        if state is None or mode == self._velocity_of(state, kinds):
            return
        if mode == "components" and self._needs_mach(state, kinds):
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
        species = icmodel.gas_species(state, self._phases)
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

    def _refresh_sum(self):
        state = self.current_state()
        values = [icmodel.to_float(v) for v in state.mass_fractions().values()]
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
        if weighted is None:
            weighted = self._turbulence_form_of(state, self._kinds(state))
        keep = set(icmodel.turbulence_keys(model, weighted))
        dropped = [k for k in icmodel.TURBULENCE_KEYS if k not in keep and k != "nrans"]
        if not self._confirm_drop("Change the turbulence input", dropped):
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
        card.body.addLayout(kit.panel_header("target", "NOZZLE"))
        card.body.addLayout(self._fields(["p0", "T0"], "IG"))
        form = self._form()
        form.addRow("marching:", self._combo("nozzle-direction", [
            ("dx", "towards +x (dx, the default)"), ("sx", "towards −x (sx)")]))
        threshold = self._field("nozzle-threshold", "IG", "the first cell")
        row = QHBoxLayout()
        row.addWidget(threshold, 1)
        unit = QLabel("m")
        unit.setProperty("role", "muted")
        row.addWidget(unit)
        form.addRow("plenum ends at x:", row)
        card.body.addLayout(form)
        card.body.addWidget(kit.hint(
            "The plenum is every row of cells upstream of the threshold, over the "
            "whole cross-section of the block. The throat is where the area of "
            "the block is smallest."))
        return card

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

    # -- zones (read-only until the zone editor) -----------------------------
    def _zones_card(self, block):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("layers", "ZONES"))
        card.body.addWidget(kit.hint(
            f"This block is split into zones along {block.direction or '?'}: each "
            "takes the cells of its range. The zone editor comes next; until "
            "then the zones are kept as they are and listed here."))
        for n, ref in zip(block.zone_numbers(), block.zone_refs()):
            zone = self.icb.zones.get(ref.section)
            text = (f"zone{n}  [{ref.section}]   range {' '.join(ref.range) or '—'}"
                    f"   ·   {zone.summary() if zone else 'no section'}")
            label = QLabel(text)
            label.setProperty("role", "value" if zone else "muted")
            card.body.addWidget(label)
        return card

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
            text = self.kit.hint(message.split(": ", 1)[-1])
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
