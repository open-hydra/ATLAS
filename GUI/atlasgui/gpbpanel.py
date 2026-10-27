"""The Phases stage: the GPB part of the case.

Left: the phases of the deck, in the order GPB reads them.  Right: the editor
of the selected phase, which follows its ``type`` -- a gas phase is built from
*composition sources* (mechanism, phase file, equilibrium, mixture, explicit
species) that GPB lets you combine, a condensed or solid phase from a table of
materials, a real fluid from a (p, T) grid.

Every widget writes straight into the phase (there is no Apply button to
forget), and anything the form does not model stays in the phase untouched and
is reachable through "All keys…".
"""

from __future__ import annotations

import weakref

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QAbstractItemView, QComboBox, QDialog, QFormLayout, QGridLayout,
    QHBoxLayout, QHeaderView, QLabel, QLineEdit, QListWidget, QListWidgetItem,
    QMenu, QMessageBox, QSplitter, QTableWidget, QTableWidgetItem, QVBoxLayout,
    QWidget,
)

from . import database, filekeys, gpbmodel, icons
from .filewidgets import STATE_ICON, STATE_TOKEN, pick_value
from .gpbdialogs import (AdvancedKeysDialog, ColumnTableDialog, MixtureDialog,
                         pick_from_database)
from .gpbmodel import (FIXED_GAS_COLUMNS, GAS_SOURCES, GPBPhase,
                       MODEL_COLUMNS, PHASE_TYPES, join_tokens, split_tokens)
from .widgets import Card, clear_layout

# One hue per phase family, used by the phase list and the stage badges.
FAMILY_COLORS = {
    "gas": "#4a90d9",
    "condensed": "#e0803c",
    "solid": "#8e7ae0",
    "real-fluid": "#2bb3a3",
}
FAMILY_ICONS = {
    "gas": "mesh", "condensed": "layers", "solid": "cube", "real-fluid": "palette",
}
# Name given to a new phase of each family (made unique by a suffix).
DEFAULT_PHASE_NAMES = {
    "gas": "gas", "condensed": "particles", "solid": "wall", "real-fluid": "fluid",
}


def _column_header(label):
    """``"rho [kg/m3]"`` -> ``"RHO"`` over ``"[kg/m3]"``, ``"psat vapour"`` ->
    ``"PSAT"`` over ``"VAPOUR"``: two short lines keep a narrow column
    readable, and the unit keeps its case."""
    name, _sep, unit = label.partition(" [")
    return name.upper().replace(" ", "\n") + (f"\n[{unit}" if unit else "")


class PhaseListItem(QWidget):
    """Two-line row of the phase list: name, then type and a one-line summary."""

    def __init__(self, kit, phase, index):
        super().__init__()
        self.setObjectName("PhaseRow")
        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 7, 8, 7)
        layout.setSpacing(9)
        family = phase.family
        dot = QLabel()
        dot.setPixmap(icons.dot_pixmap(FAMILY_COLORS.get(family, "#888"),
                                       kit.px(12)))
        dot.setFixedWidth(kit.px(14))
        layout.addWidget(dot, 0, Qt.AlignmentFlag.AlignTop)

        text = QVBoxLayout()
        text.setSpacing(2)
        name = QLabel(phase.display_name(index))
        name.setProperty("role", "value")
        text.addWidget(name)
        detail = QLabel(f"{gpbmodel.TYPE_LABEL.get(phase.type, phase.type)}"
                        f"  ·  {phase.summary()}")
        detail.setProperty("role", "hint")
        detail.setWordWrap(False)
        text.addWidget(detail)
        layout.addLayout(text, 1)
        self.setToolTip(f"[GPB-Phase{index + 1}]  {phase.type}")
        # The row is sized from sizeHint() before the list shows it: polish
        # now, so the hint counts the stylesheet's fonts and the two lines
        # are not clipped.
        self.ensurePolished()


class GPBPanel(QWidget):
    """Editor for the GPB phases of the case."""

    changed = pyqtSignal()

    def __init__(self, shell):
        super().__init__()
        self.shell = shell
        self.kit = shell.kit
        self._loading = False
        self._editor_widgets = []
        # phase -> the name the BCB blocks list it under (see _follow_rename)
        self._block_names = weakref.WeakKeyDictionary()
        self._build_ui()

    # -- document access -------------------------------------------------
    @property
    def gpb(self):
        return self.shell.doc.gpb

    @property
    def case_dir(self):
        return self.shell.case_dir

    def current_index(self):
        return self.phase_list.currentRow()

    def current_phase(self):
        index = self.current_index()
        if 0 <= index < len(self.gpb.phases):
            return self.gpb.phases[index]
        return None

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
        card.body.addLayout(kit.panel_header("layers", "PHASES", self.count_badge))

        self.phase_list = QListWidget()
        # Its rows are PhaseListItem widgets, which carry their own margins:
        # the stylesheet gives this list no item padding (see theme.py).
        self.phase_list.setObjectName("PhaseList")
        self.phase_list.setSelectionMode(
            QAbstractItemView.SelectionMode.SingleSelection)
        self.phase_list.currentRowChanged.connect(self._on_phase_selected)
        self.phase_list.setToolTip(
            "GPB builds the phases in this order; they become [GPB-Phase1], "
            "[GPB-Phase2], …")
        card.body.addWidget(self.phase_list, 1)

        add_row = QHBoxLayout()
        add_row.setSpacing(7)
        add_button = kit.button("Add phase", None, "plus", "primary")
        menu = QMenu(add_button)
        for value, label, _family, blurb in PHASE_TYPES:
            action = menu.addAction(label)
            action.setToolTip(blurb)
            action.triggered.connect(
                lambda _checked=False, v=value: self._add_phase(v))
        add_button.setMenu(menu)
        add_row.addWidget(add_button, 1)
        card.body.addLayout(add_row)

        tools = QHBoxLayout()
        tools.setSpacing(7)
        tools.addWidget(kit.button("Copy", self._duplicate_phase, "copy",
                                   tip="Duplicate the selected phase"))
        tools.addWidget(kit.button("Up", lambda: self._move_phase(-1), None,
                                   tip="Move earlier in the deck"))
        tools.addWidget(kit.button("Down", lambda: self._move_phase(1), None,
                                   tip="Move later in the deck"))
        tools.addWidget(kit.button("Remove", self._remove_phase, "trash",
                                   "danger"))
        card.body.addLayout(tools)
        card.body.addWidget(kit.hint(
            "A phase becomes one property table in fromATLAStoSolver/, named "
            "after its name."))
        return card

    def _build_editor_panel(self):
        # A form reads badly when it is 1000 px wide: the column is capped and
        # centred, the way a document is.
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
        outer_layout.addStretch(1)   # the column hugs the phase list
        return self.kit.scrollable(outer)

    # -------------------------------------------------------------- refresh
    def refresh(self):
        """Rebuild the list and the editor from the document."""
        self._refresh_list()
        self._rebuild_editor()

    def _refresh_list(self):
        index = self.current_index()
        self.phase_list.blockSignals(True)
        self.phase_list.clear()
        for i, phase in enumerate(self.gpb.phases):
            item = QListWidgetItem()
            widget = PhaseListItem(self.kit, phase, i)
            item.setSizeHint(widget.sizeHint())
            self.phase_list.addItem(item)
            self.phase_list.setItemWidget(item, widget)
        if self.gpb.phases:
            index = min(max(index, 0), len(self.gpb.phases) - 1)
            self.phase_list.setCurrentRow(index)
        self.phase_list.blockSignals(False)
        self.count_badge.setText(str(len(self.gpb.phases)))

    def _refresh_current_row(self):
        """Repaint just the selected row (name/type/summary changed)."""
        index = self.current_index()
        if not (0 <= index < len(self.gpb.phases)):
            return
        item = self.phase_list.item(index)
        widget = PhaseListItem(self.kit, self.gpb.phases[index], index)
        item.setSizeHint(widget.sizeHint())
        self.phase_list.setItemWidget(item, widget)

    def _on_phase_selected(self, _row):
        self._rebuild_editor()

    def _select(self, row):
        """Make *row* the current phase and open its editor.

        setCurrentRow() signals only a change of row, and after
        _refresh_list() the row asked for may already be current -- the
        first phase added to an empty list is row 0 then -- so the editor is
        rebuilt here, not left to the signal.
        """
        self.phase_list.blockSignals(True)
        self.phase_list.setCurrentRow(row)
        self.phase_list.blockSignals(False)
        self._rebuild_editor()

    def _edited(self, relist=True):
        """Called after every edit: refresh chrome and tell the shell."""
        if self._loading:
            return
        if relist:
            self._refresh_current_row()
        self.changed.emit()

    # ---------------------------------------------------------- list actions
    def _unique_name(self, base):
        """*base*, or *base* with the first free numeric suffix: the name is
        the prefix of the phase's output files, so two phases must not share it."""
        existing = {p.name for p in self.gpb.phases}
        name = base
        suffix = 2
        while name in existing:
            name = f"{base}{suffix}"
            suffix += 1
        return name

    def _add_phase(self, phase_type):
        phase = GPBPhase([("type", phase_type)])
        phase.set("name", self._unique_name(
            DEFAULT_PHASE_NAMES[gpbmodel.family_of(phase_type)]))
        if gpbmodel.family_of(phase_type) in ("condensed", "solid"):
            phase.set("material", "material1")
        self.gpb.add_phase(phase)
        self._refresh_list()
        self._select(len(self.gpb.phases) - 1)
        self.changed.emit()

    def _duplicate_phase(self):
        phase = self.current_phase()
        if phase is None:
            return
        clone = phase.clone()
        base = phase.name or DEFAULT_PHASE_NAMES[phase.family]
        clone.set("name", self._unique_name(base + "_copy"))
        self.gpb.add_phase(clone, self.current_index() + 1)
        self._refresh_list()
        self._select(self.current_index() + 1)
        self.changed.emit()

    def _remove_phase(self):
        index = self.current_index()
        if index < 0:
            return
        if not self._release_block_phase(self.gpb.phases[index]):
            return
        self.gpb.remove_phase(index)
        self._refresh_list()
        self._rebuild_editor()
        self.changed.emit()

    def _move_phase(self, delta):
        index = self.current_index()
        if index < 0:
            return
        new_index = self.gpb.move_phase(index, delta)
        self._refresh_list()
        self._select(new_index)
        self.changed.emit()

    # --------------------------------------------------------- field helpers
    def _set(self, key, value, relist=True):
        phase = self.current_phase()
        if phase is None or self._loading:
            return
        if key == "name":
            self._follow_rename(phase, str(value).strip())
        phase.set(key, value)
        self._edited(relist)

    # ------------------------------------------------- phases of the blocks
    # A [BCB-BlockN] lists the phases present in it by name (phase = ...), and
    # BCB matches them against the names of the phases: a rename or a removal
    # here has to reach those lists, or the block names a phase that is gone.
    def _follow_rename(self, phase, new):
        """Carry a rename into the ``phase`` key of the blocks.

        The name field commits on every keystroke, so the name the blocks
        hold is tracked per phase: an empty name, or one another phase already
        has, is not carried over (the blocks keep the last unique name) and
        the next valid one is.
        """
        held = self._block_names.get(phase, phase.name)
        others = {p.name for p in self.gpb.phases if p is not phase}
        if not new or new == held or new in others:
            return
        if held:
            self.shell.doc.bcb.rename_phase(held, new)
            self.shell.doc.icb.rename_phase(held, new)
        self._block_names[phase] = new

    def _release_block_phase(self, phase):
        """Before removing *phase*: take it out of the blocks that list it,
        once the user agrees.  False when the removal is cancelled."""
        name = self._block_names.get(phase, phase.name)
        if name in {p.name for p in self.gpb.phases if p is not phase}:
            return True     # another phase still answers to the name
        bcb = self.shell.doc.bcb
        icb = self.shell.doc.icb
        blocks = bcb.blocks_listing_phase(name) if name else []
        initial = icb.blocks_listing_phase(name) if name else []
        if not blocks and not initial:
            if name:
                bcb.drop_phase(name)    # the wildcard block, if not expanded
            return True
        sections = [f"[BCB-Block{b + 1}]" for b in blocks]
        sections += [f"[{block.section_name}]" for block in initial]
        listing = ", ".join(sections[:8]) + (", ..." if len(sections) > 8 else "")
        text = (f"Phase '{name}' is listed in the phase key of {listing}; "
                f"removing the phase removes it from those sections too.")
        alone = (sum(1 for b in blocks if bcb.block_phases(b) == [name])
                 + sum(1 for block in initial if block.phases == [name]))
        if alone:
            text += (f"\n\n{alone} of them list no other phase: without a "
                     f"phase key, a block gets every phase of the deck.")
        reply = QMessageBox.question(
            self, "Remove phase", text + "\n\nRemove the phase?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
        if reply != QMessageBox.StandardButton.Yes:
            return False
        bcb.drop_phase(name)
        icb.drop_phase(name)
        return True

    def _line(self, key, placeholder=None, width=None, relist=True):
        phase = self.current_phase()
        edit = QLineEdit(phase.get(key) if phase else "")
        edit.setPlaceholderText(
            placeholder if placeholder is not None
            else (gpbmodel.default_of(key) or ""))
        edit.setToolTip(gpbmodel.describe(key) or key)
        if width:
            edit.setMaximumWidth(self.kit.px(width))
        edit.textEdited.connect(lambda text, k=key: self._set(k, text, relist))
        return edit

    def _combo(self, key, values, editable=False, empty="(not set)",
               relist=True, width=None):
        phase = self.current_phase()
        combo = QComboBox()
        combo.setEditable(editable)
        if empty is not None:
            combo.addItem(empty, "")
        for value in values:
            combo.addItem(str(value), str(value))
        current = phase.get(key) if phase else ""
        index = combo.findData(current)
        if index >= 0:
            combo.setCurrentIndex(index)
        elif editable:
            combo.setCurrentText(current)
        combo.setToolTip(gpbmodel.describe(key) or key)
        if width:
            combo.setMaximumWidth(self.kit.px(width))

        def commit(_index=None, k=key, c=combo):
            value = c.currentData() if not c.isEditable() else c.currentText()
            if c.isEditable() and c.currentIndex() >= 0 and \
                    c.currentText() == c.itemText(c.currentIndex()):
                value = c.currentData()
            self._set(k, "" if value in (None, empty) else value, relist)

        combo.currentIndexChanged.connect(commit)
        if editable:
            combo.editTextChanged.connect(lambda _t: commit())
        return combo

    def _with_browse(self, key, combo):
        """A database picker plus *Browse…*, for a key that names a file.

        The combo offers what the ATLAS database and the case directory hold;
        the button reaches any other file, and the mark says whether the value
        resolves where GPB will look for it (``filekeys``).
        """
        role = filekeys.role_of(key, "gpb-phase")
        if role is None:
            return combo
        box = QWidget()
        row = QHBoxLayout(box)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(7)
        mark = QLabel()
        mark.setFixedWidth(self.kit.px(18))

        def repaint():
            phase = self.current_phase()
            value = phase.get(key) if phase else ""
            state, _path, why = filekeys.status(value, self.case_dir, role)
            mark.setPixmap(self.kit.pixmap(
                STATE_ICON[state], STATE_TOKEN[state], 15))
            mark.setToolTip(why or "")

        def browse():
            phase = self.current_phase()
            if phase is None:
                return
            value = pick_value(self, role, phase.get(key), self.case_dir)
            if value is None:
                return
            if combo.findText(value) < 0:
                combo.insertItem(0, value, value)
            combo.setCurrentText(value)      # the combo commits the value
            self._set(key, value)
            repaint()

        if combo.isEditable():
            combo.editTextChanged.connect(lambda _text: repaint())
        combo.currentIndexChanged.connect(lambda _index: repaint())
        row.addWidget(combo, 1)
        row.addWidget(mark)
        row.addWidget(self.kit.button(
            "Browse…", browse, "open",
            tip=role.hint or f"Choose the {role.label}"))
        self.kit.register_repaint(repaint)
        repaint()
        return box

    def _bool_toggle(self, key, label):
        phase = self.current_phase()
        button = self.kit.toggle(
            label, None, "check", bool(phase and phase.bool_of(key)),
            tip=gpbmodel.describe(key) or key, compactable=False)
        button.toggled.connect(
            lambda on, k=key: self._set(k, "true" if on else "", False))
        return button

    def _form(self):
        form = QFormLayout()
        form.setContentsMargins(0, 0, 0, 0)
        form.setSpacing(8)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        return form

    def _labelled(self, key, text=None):
        label = QLabel((text or key) + ":")
        label.setToolTip(gpbmodel.describe(key) or key)
        return label

    # ---------------------------------------------------------- editor build
    def _rebuild_editor(self):
        clear_layout(self.editor_layout)
        phase = self.current_phase()
        if phase is None:
            empty = Card()
            empty.body.addWidget(self.kit.title("No phase yet"))
            empty.body.addWidget(self.kit.hint(
                "Add a phase to describe what the solver transports: a gas, a "
                "dispersed condensed phase, a solid material or a real fluid. "
                "Each one becomes a [GPB-PhaseN] section of the case file."))
            self.editor_layout.addWidget(empty)
            self.editor_layout.addStretch(1)
            return

        self._loading = True
        try:
            self.editor_layout.addWidget(self._identity_card(phase))
            family = phase.family
            if family in ("condensed", "solid"):
                self.editor_layout.addWidget(self._materials_card(phase))
            elif family == "real-fluid":
                self.editor_layout.addWidget(self._real_fluid_card(phase))
            else:
                self.editor_layout.addWidget(self._composition_card(phase))
                self.editor_layout.addWidget(self._gas_properties_card(phase))
            if family != "real-fluid":
                self.editor_layout.addWidget(self._tabulation_card(phase))
            self.editor_layout.addWidget(self._footer_card(phase))
            self.editor_layout.addStretch(1)
        finally:
            self._loading = False

    def _identity_card(self, phase):
        card = Card()
        kit = self.kit
        family = phase.family
        head = QHBoxLayout()
        head.setSpacing(8)
        dot = QLabel()
        dot.setPixmap(icons.dot_pixmap(FAMILY_COLORS.get(family, "#888"), 13))
        head.addWidget(dot)
        head.addWidget(kit.section_label(
            f"PHASE {self.current_index() + 1}  ·  [GPB-Phase{self.current_index() + 1}]"))
        head.addStretch(1)
        card.body.addLayout(head)

        form = self._form()
        name_edit = self._line("name", placeholder="prefix of the output files")
        form.addRow(self._labelled("name"), name_edit)

        type_combo = QComboBox()
        for value, label, _family, _blurb in PHASE_TYPES:
            type_combo.addItem(label, value)
        index = type_combo.findData(phase.type)
        if index >= 0:
            type_combo.setCurrentIndex(index)
        type_combo.setToolTip(gpbmodel.describe("type"))
        type_combo.currentIndexChanged.connect(self._on_type_changed)
        self.type_combo = type_combo
        form.addRow(self._labelled("type"), type_combo)

        if family in ("condensed", "solid"):
            form.addRow(self._labelled("modeling"),
                        self._combo("modeling", gpbmodel.MODELING,
                                    empty="(solver default)"))
        card.body.addLayout(form)
        card.body.addWidget(kit.hint(gpbmodel.TYPE_BLURB.get(phase.type, "")))
        return card

    def _on_type_changed(self, _index):
        if self._loading:
            return
        phase = self.current_phase()
        if phase is None:
            return
        new_type = self.type_combo.currentData()
        old_family, new_family = phase.family, gpbmodel.family_of(new_type)
        phase.set("type", new_type)
        if old_family != new_family and new_family in ("condensed", "solid") \
                and not phase.get("material"):
            phase.set("material", "material1")
        self._edited()
        self._rebuild_editor()

    # -- gas -------------------------------------------------------------
    def _composition_card(self, phase):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("palette", "COMPOSITION"))
        card.body.addWidget(kit.hint(
            "Where the species come from. GPB combines these, so a mechanism "
            "can be extended with extra species or compared against an "
            "equilibrium composition."))

        for name, spec in GAS_SOURCES.items():
            active = phase.has_source(name)
            row = QHBoxLayout()
            row.setSpacing(8)
            toggle = kit.toggle(spec["label"], None, "check", active,
                                tip=spec["blurb"], compactable=False)
            toggle.toggled.connect(
                lambda on, n=name: self._toggle_source(n, on))
            row.addWidget(toggle)
            row.addStretch(1)
            card.body.addLayout(row)
            if active:
                body = self._source_body(phase, name)
                if body is not None:
                    card.body.addWidget(body)
        return card

    def _toggle_source(self, name, on):
        phase = self.current_phase()
        if phase is None or self._loading:
            return
        if on:
            defaults = {
                "mechanism": [("reactions", "")],
                "phase-file": [("phase", "")],
                "cea": [("CEA-file", "")],
                "cantera-eq": [("eq-fuel", ""), ("eq-oxidizer", ""), ("eq-of", "")],
                "mixture": [("mixture", "")],
                "species": [("species", "")],
            }[name]
            # An empty value would be dropped by set(), so seed the keys with a
            # placeholder the user replaces; keep them visible in the form.
            for key, value in defaults:
                phase.params.setdefault(key, value)
        else:
            phase.drop_source(name)
        self._edited()
        self._rebuild_editor()

    def _source_body(self, phase, name):
        kit = self.kit
        box = QWidget()
        layout = QVBoxLayout(box)
        layout.setContentsMargins(26, 0, 0, 6)
        layout.setSpacing(7)
        form = self._form()

        if name == "mechanism":
            stems, local = database.mechanism_files(self.case_dir)
            combo = self._combo("reactions", local + stems, editable=True,
                                empty=None)
            form.addRow(self._labelled("reactions", "mechanism"),
                        self._with_browse("reactions", combo))
            layout.addLayout(form)
            species = database.species_of_mechanism(
                phase.get("reactions"), self.case_dir)
            if species:
                layout.addWidget(kit.hint(
                    f"{len(species)} species: " + ", ".join(species[:10])
                    + (" …" if len(species) > 10 else "")))
        elif name == "phase-file":
            stems, local = database.mechanism_files(self.case_dir)
            form.addRow(self._labelled("phase", "phase file"),
                        self._with_browse("phase", self._combo(
                            "phase", local + stems, editable=True, empty=None)))
            layout.addLayout(form)
            layout.addWidget(kit.hint(
                "The file is imported as it is: thermo, transport and "
                "reactions keys are ignored."))
        elif name == "cea":
            files = database.cea_files(self.case_dir)
            form.addRow(self._labelled("CEA-file", "CEA input"),
                        self._with_browse("CEA-file", self._combo(
                            "CEA-file", files, editable=True, empty=None)))
            form.addRow(self._labelled("CEA-section", "section"),
                        self._line("CEA-section", width=90))
            layout.addLayout(form)
        elif name == "cantera-eq":
            grid = QGridLayout()
            grid.setHorizontalSpacing(10)
            grid.setVerticalSpacing(8)
            fields = [("eq-fuel", "fuel"), ("eq-fuel-T", "fuel T [K]"),
                      ("eq-oxidizer", "oxidizer"), ("eq-oxidizer-T", "oxidizer T [K]"),
                      ("eq-of", "O/F ratio"), ("eq-pressure", "pressure")]
            for i, (key, label) in enumerate(fields):
                grid.addWidget(self._labelled(key, label), i // 2, (i % 2) * 2)
                grid.addWidget(self._line(key), i // 2, (i % 2) * 2 + 1)
            layout.addLayout(grid)
            layout.addWidget(kit.hint(
                "Pressure takes a value and a unit, e.g. 3000 psi."))
        elif name == "mixture":
            rows = gpbmodel.parse_mixture(phase.get("mixture"))
            summary = ", ".join(f"{s}: {a}" for s, a in rows) or "no species yet"
            label = kit.hint(f"{phase.get('mixture-name') or 'mix'} — {summary}")
            layout.addWidget(label)
            button_row = QHBoxLayout()
            button_row.addWidget(kit.button("Edit composition…",
                                            self._edit_mixture, "pencil"))
            button_row.addStretch(1)
            layout.addLayout(button_row)
        elif name == "species":
            form.addRow(self._labelled("species"), self._line("species"))
            form.addRow(self._labelled("add-species", "add-species"),
                        self._line("add-species"))
            layout.addLayout(form)
            button_row = QHBoxLayout()
            button_row.setSpacing(7)
            button_row.addWidget(kit.button(
                "Pick species…", self._pick_species, "open",
                tip="Pick gaseous species from the mechanism or from NASA7, "
                    "NASA9 or Burcat."))
            button_row.addWidget(kit.button(
                "Constant properties…", self._edit_fixed_gas, "sliders",
                tip="Give each species a constant cp/cv/gamma/R/mw and its "
                    "transport properties (calorically-perfect gas)."))
            button_row.addStretch(1)
            layout.addLayout(button_row)
            if phase.is_fixed_gas():
                layout.addWidget(kit.hint(
                    "Constant properties are set: this is a "
                    "calorically-perfect gas."))
        return box

    def _gas_properties_card(self, phase):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("sliders", "DATABASES"))
        form = self._form()
        form.addRow(self._labelled("thermo"),
                    self._combo("thermo", gpbmodel.THERMO_DATABASES,
                                empty="(from the file)"))
        form.addRow(self._labelled("transport"),
                    self._combo("transport", gpbmodel.TRANSPORT_SOURCES,
                                empty="(none)"))
        card.body.addLayout(form)
        flags = QHBoxLayout()
        flags.setSpacing(8)
        flags.addWidget(self._bool_toggle("inerts-mixing", "inerts-mixing"))
        flags.addWidget(self._bool_toggle("strict-thermo", "strict-thermo"))
        flags.addStretch(1)
        card.body.addLayout(flags)
        return card

    def _edit_mixture(self):
        phase = self.current_phase()
        dialog = MixtureDialog(self, self.kit, phase)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            dialog.apply_to_phase()
            self._edited()
            self._rebuild_editor()

    def _pick_species(self):
        phase = self.current_phase()
        chosen, thermo = pick_from_database(
            self, self.kit, phase, "Add species", self.case_dir)
        if not chosen:
            return
        if thermo:
            phase.set("thermo", thermo)
        current = split_tokens(phase.get("species"))
        for name in chosen:
            if name not in current:
                current.append(name)
        phase.set("species", join_tokens(current))
        self._edited()
        self._rebuild_editor()

    def _edit_fixed_gas(self):
        phase = self.current_phase()
        species = split_tokens(phase.get("species"))
        if not species:
            self.shell.warn("No species",
                            "Add a species to the list before giving it "
                            "constant properties.")
            return
        dialog = ColumnTableDialog(
            self, self.kit, phase, species, FIXED_GAS_COLUMNS,
            "Constant species properties",
            "A calorically-perfect gas: give each species two of cp, cv, "
            "gamma, R, mw (the rest follow) and, when wanted, its viscosity, "
            "conductivity and Prandtl number.")
        if dialog.exec() == QDialog.DialogCode.Accepted:
            dialog.apply_to_phase()
            self._edited()
            self._rebuild_editor()

    # -- condensed / solid ------------------------------------------------
    def _material_columns(self, phase):
        if phase.family == "solid":
            return [(k, label) for k, label in gpbmodel.MATERIAL_COLUMNS
                    if k not in ("groups", "psat-vapour", "psat-liquid")]
        return list(gpbmodel.MATERIAL_COLUMNS)

    def _materials_card(self, phase):
        card = Card()
        kit = self.kit
        materials = phase.entries()
        self.material_badge = kit.badge(str(len(materials)))
        card.body.addLayout(
            kit.panel_header("cube", "MATERIALS", self.material_badge))

        # The database first: it is where the materials below are looked up.
        form = self._form()
        form.addRow(self._labelled("thermo"),
                    self._combo("thermo", gpbmodel.CONDENSED_THERMO,
                                empty="(NASA9 when no cp is given)"))
        card.body.addLayout(form)

        columns = self._material_columns(phase)
        table = QTableWidget(len(materials), len(columns) + 1)
        table.setHorizontalHeaderLabels(
            ["MATERIAL"] + [_column_header(label) for _k, label in columns])
        table.verticalHeader().setVisible(False)
        table.setShowGrid(False)
        kit.table_rows(table, 28)
        table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        table.horizontalHeader().setSectionResizeMode(
            0, QHeaderView.ResizeMode.ResizeToContents)
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        for row, material in enumerate(materials):
            table.setItem(row, 0, QTableWidgetItem(material))
            for col, (key, _label) in enumerate(columns):
                value = phase.column(key, len(materials))[row]
                item = QTableWidgetItem(value)
                item.setToolTip(gpbmodel.describe(key) or key)
                table.setItem(row, col + 1, item)
        table.cellChanged.connect(lambda *_: self._commit_materials())
        rows_height = kit.px(56 + 29 * max(len(materials), 1) + 8)   # 2-line header
        table.setMinimumHeight(min(rows_height, kit.px(150)))
        table.setMaximumHeight(max(rows_height, kit.px(90)))
        self.material_table = table
        card.body.addWidget(table)

        tools = QHBoxLayout()
        tools.setSpacing(7)
        tools.addWidget(kit.button("Add material", self._add_material, "plus"))
        tools.addWidget(kit.button(
            "From database…", self._pick_material, "open",
            tip="Pick materials from NASA7, NASA9, Burcat or the SP-database; "
                "only the states this phase type takes are listed."))
        tools.addWidget(kit.button("Remove", self._remove_material, "trash",
                                   "danger"))
        tools.addStretch(1)
        if phase.family == "condensed":
            tools.addWidget(kit.button(
                "Per-material models…", self._edit_models, "sliders",
                tip="Evaporation, interface, combustion and the other "
                    "solver models, per material."))
        card.body.addLayout(tools)
        card.body.addWidget(kit.hint(
            "With a database, every material it holds is temperature "
            "dependent and the others fall back to the constants in the "
            "table; give h0 to put a constant-property material on the "
            "database's absolute enthalpy scale. A value left empty is not "
            "written, and a column with the same value everywhere is written "
            "once and broadcast by GPB."))
        return card

    def _commit_materials(self):
        if self._loading:
            return
        phase = self.current_phase()
        table = self.material_table
        columns = self._material_columns(phase)
        names = []
        for row in range(table.rowCount()):
            item = table.item(row, 0)
            names.append(item.text().strip() if item else "")
        phase.set("material", join_tokens(names))
        for col, (key, _label) in enumerate(columns):
            values = []
            for row in range(table.rowCount()):
                item = table.item(row, col + 1)
                values.append(item.text().strip() if item else "")
            phase.set_column(key, values)
        self.material_badge.setText(str(len([n for n in names if n])))
        self._edited()

    def _add_material(self, name="material"):
        phase = self.current_phase()
        materials = phase.entries()
        base = name if isinstance(name, str) and name else "material"
        candidate, suffix = base, 2
        while candidate in materials:
            candidate = f"{base}{suffix}"
            suffix += 1
        materials.append(candidate)
        phase.set("material", join_tokens(materials))
        self._edited()
        self._rebuild_editor()

    def _pick_material(self):
        phase = self.current_phase()
        chosen, thermo = pick_from_database(
            self, self.kit, phase, "Add material", self.case_dir)
        if not chosen:
            return
        if thermo:
            phase.set("thermo", thermo)
        materials = phase.entries()
        for name in chosen:
            if name not in materials:
                materials.append(name)
        phase.set("material", join_tokens(materials))
        self._edited()
        self._rebuild_editor()

    def _remove_material(self):
        phase = self.current_phase()
        row = self.material_table.currentRow()
        materials = phase.entries()
        if row < 0 or row >= len(materials):
            return
        # Every per-material key, not only the displayed ones: a solid phase
        # hides groups and psat-*, but a loaded deck may still carry them.
        columns = list(gpbmodel.MATERIAL_COLUMNS) + list(MODEL_COLUMNS)
        for key, _label in columns:
            if phase.has(key):
                values = phase.column(key, len(materials))
                del values[row]
                phase.set_column(key, values)
        del materials[row]
        phase.set("material", join_tokens(materials))
        self._edited()
        self._rebuild_editor()

    def _edit_models(self):
        phase = self.current_phase()
        materials = phase.entries()
        if not materials:
            self.shell.warn("No material", "Add a material first.")
            return
        dialog = ColumnTableDialog(
            self, self.kit, phase, materials, MODEL_COLUMNS,
            "Per-material solver models",
            "Written after the material name on its line of <name>phase.txt "
            "and read by the Lagrangian solver; ATLAS itself ignores them. An "
            "unset key leaves the solver default in place.")
        if dialog.exec() == QDialog.DialogCode.Accepted:
            dialog.apply_to_phase()
            self._edited()
            self._rebuild_editor()

    # -- real fluid -------------------------------------------------------
    def _real_fluid_card(self, phase):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("palette", "FLUID AND TABLE GRID"))
        form = self._form()
        form.addRow(self._labelled("model", "EOS model"),
                    self._combo("model", gpbmodel.REAL_FLUID_MODELS,
                                empty="(coolprop)"))
        form.addRow(self._labelled("fluid"),
                    self._combo("fluid", database.coolprop_fluids(),
                                editable=True, empty=None))
        card.body.addLayout(form)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(8)
        fields = [("pmin", "pmin [Pa]"), ("pmax", "pmax [Pa]"),
                  ("Tmin", "Tmin [K]"), ("Tmax", "Tmax [K]"),
                  ("NP", "pressure points"), ("NH", "enthalpy points")]
        for i, (key, label) in enumerate(fields):
            grid.addWidget(self._labelled(key, label), i // 2, (i % 2) * 2)
            grid.addWidget(self._line(key, relist=(key in ("fluid",))),
                           i // 2, (i % 2) * 2 + 1)
        card.body.addLayout(grid)
        card.body.addWidget(kit.hint(
            "The table is built on a (p, h) grid between these bounds; "
            "CoolProp is the accurate backend, the cubic equations of state "
            "are quick checks."))
        return card

    # -- shared -----------------------------------------------------------
    def _tabulation_card(self, phase):
        card = Card()
        kit = self.kit
        card.body.addLayout(kit.panel_header("sliders", "TABULATION RANGE"))
        row = QHBoxLayout()
        row.setSpacing(10)
        row.addWidget(self._labelled("Tmin", "Tmin [K]"))
        row.addWidget(self._line("Tmin", width=110, relist=False))
        row.addWidget(self._labelled("Tmax", "Tmax [K]"))
        row.addWidget(self._line("Tmax", width=110, relist=False))
        row.addStretch(1)
        card.body.addLayout(row)
        card.body.addWidget(kit.hint(
            "Integer kelvin: the tables run from Tmin to Tmax with a 1 K step "
            "(defaults 1 K and 5000 K)."))
        return card

    def _footer_card(self, phase):
        card = Card(margins=(12, 8, 12, 8))
        row = QHBoxLayout()
        row.setSpacing(8)
        row.addWidget(self.kit.icon_label("code", "muted", 15))
        row.addWidget(self.kit.hint(
            f"{len(phase.params)} key(s) in this section"))
        row.addStretch(1)
        row.addWidget(self.kit.button("All keys…", self._edit_advanced, "sliders",
                                      tip="Edit the raw INI lines of this phase."))
        card.body.addLayout(row)
        return card

    def _edit_advanced(self):
        phase = self.current_phase()
        dialog = AdvancedKeysDialog(self, self.kit, phase)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            dialog.apply_to_phase()
            self._edited()
            self._rebuild_editor()
