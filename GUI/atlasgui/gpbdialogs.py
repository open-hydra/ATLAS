"""Dialogs of the GPB panel.

The dense parts of a phase -- the per-material solver models, the constant
properties of a calorically-perfect gas, a mixture composition, the raw key
list -- are edited in their own window instead of crowding the phase form.
Each dialog works on a copy and writes into the phase only on OK.

The two table dialogs put the *keys down the side and the entries across*: a
phase has a handful of materials or species but up to twenty model keys, so
that way round stays readable.
"""

from __future__ import annotations

from collections import OrderedDict

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QAbstractItemView, QComboBox, QDialog, QHBoxLayout, QHeaderView, QLineEdit,
    QListWidget, QListWidgetItem, QTableWidget, QTableWidgetItem,
)

from . import database, gpbmodel
from .widgets import Dialog as _Dialog


class ColumnTableDialog(_Dialog):
    """Keys down the side, entries across: one cell per (key, entry).

    *columns* is the list of ``(key, label)`` pairs to edit, *entries* the
    material or species names.  A key with a fixed set of values gets a combo.
    """

    def __init__(self, parent, kit, phase, entries, columns, title, explanation):
        super().__init__(parent, kit, title, explanation)
        self.phase = phase
        self.entries = list(entries)
        self.columns = list(columns)

        self.table = QTableWidget(len(self.columns), len(self.entries) + 1)
        self.table.setHorizontalHeaderLabels(
            ["KEY"] + [e.upper() for e in self.entries])
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(
            0, QHeaderView.ResizeMode.ResizeToContents)
        kit.table_rows(self.table, 30)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.NoSelection)

        self._editors = {}
        for row, (key, label) in enumerate(self.columns):
            name = QTableWidgetItem(label)
            name.setFlags(Qt.ItemFlag.ItemIsEnabled)
            name.setToolTip(gpbmodel.describe(key) or key)
            self.table.setItem(row, 0, name)
            values = phase.column(key, len(self.entries))
            allowed = gpbmodel.allowed_values(key)
            for col, value in enumerate(values):
                if allowed:
                    editor = QComboBox()
                    editor.addItem("(unset)", "")
                    for option in allowed:
                        editor.addItem(option, option)
                    index = editor.findData(value.strip())
                    editor.setCurrentIndex(index if index >= 0 else 0)
                else:
                    editor = QLineEdit(value)
                    editor.setPlaceholderText(gpbmodel.default_of(key) or "unset")
                editor.setToolTip(gpbmodel.describe(key) or key)
                self.table.setCellWidget(row, col + 1, editor)
                self._editors[(key, col)] = editor
        self.layout_.addWidget(self.table, 1)
        self.add_buttons()
        self.resize(kit.px(760), kit.px(min(680, 190 + 30 * len(self.columns))))

    def values(self):
        """``{key: [value per entry]}`` as typed."""
        out = OrderedDict()
        for key, _label in self.columns:
            row = []
            for col in range(len(self.entries)):
                editor = self._editors[(key, col)]
                if isinstance(editor, QComboBox):
                    row.append(editor.currentData() or "")
                else:
                    row.append(editor.text().strip())
            out[key] = row
        return out

    def apply_to_phase(self):
        for key, values in self.values().items():
            self.phase.set_column(key, values)


class MixtureDialog(_Dialog):
    """The ``mixture = {N2: 75.4} {O2: 23.3}`` composition, as a table."""

    def __init__(self, parent, kit, phase):
        super().__init__(
            parent, kit, "Mixture composition",
            "One species standing for a mixture. The amounts are written as "
            "{species: amount} groups, in the units GPB expects (mass "
            "fractions or percentages, as in the docs).")
        self.phase = phase
        self.thermo = None      # set when the species come from another database
        self.table = QTableWidget(0, 2)
        self.table.setHorizontalHeaderLabels(["SPECIES", "AMOUNT"])
        self.table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        kit.table_rows(self.table, 28)
        for name, amount in gpbmodel.parse_mixture(phase.get("mixture")):
            self._append(name, amount)
        if self.table.rowCount() == 0:
            self._append("", "")
        self.layout_.addWidget(self.table, 1)

        row = QHBoxLayout()
        row.setSpacing(7)
        row.addWidget(kit.button("Add species", lambda: self._append("", ""), "plus"))
        row.addWidget(kit.button("From database…", self._pick, "open"))
        row.addWidget(kit.button("Remove", self._remove, "trash", "danger"))
        row.addStretch(1)
        self.layout_.addLayout(row)

        name_row = QHBoxLayout()
        name_row.addWidget(kit.section_label("MIXTURE NAME"))
        self.name_edit = QLineEdit(phase.get("mixture-name"))
        self.name_edit.setPlaceholderText(gpbmodel.default_of("mixture-name"))
        self.name_edit.setToolTip(gpbmodel.describe("mixture-name"))
        name_row.addWidget(self.name_edit, 1)
        self.layout_.addLayout(name_row)
        self.add_buttons()
        self.resize(kit.px(520), kit.px(440))

    def _append(self, name, amount):
        row = self.table.rowCount()
        self.table.insertRow(row)
        self.table.setItem(row, 0, QTableWidgetItem(name))
        self.table.setItem(row, 1, QTableWidgetItem(amount))

    def _remove(self):
        row = self.table.currentRow()
        if row >= 0:
            self.table.removeRow(row)

    def _pick(self):
        chosen, thermo = pick_from_database(
            self, self.kit, self.phase, "Add species to the mixture",
            with_mechanism=False)
        if thermo:
            self.thermo = thermo
        for name in chosen:
            self._append(name, "")

    def rows(self):
        out = []
        for row in range(self.table.rowCount()):
            name = self.table.item(row, 0)
            amount = self.table.item(row, 1)
            name = name.text().strip() if name else ""
            amount = amount.text().strip() if amount else ""
            if name:
                out.append((name, amount))
        return out

    def apply_to_phase(self):
        rows = self.rows()
        self.phase.set("mixture", gpbmodel.format_mixture(rows))
        self.phase.set("mixture-name", self.name_edit.text())
        if self.thermo:
            self.phase.set("thermo", self.thermo)


class AdvancedKeysDialog(_Dialog):
    """Every ``key = value`` line of a section, as written to the INI.

    Written for a GPB phase; another section with ``params`` (an ICB state)
    passes its own *title*, the *keys* to suggest and how to *describe* and
    give the *default* of one.
    """

    def __init__(self, parent, kit, phase, title="All keys of this phase",
                 keys=None, describe=None, default=None):
        super().__init__(
            parent, kit, title,
            "The raw INI lines. Anything the form above does not cover can be "
            "set here; the form keeps whatever it does not know about.")
        self.phase = phase
        self._describe_key = describe or gpbmodel.describe
        self._default_of = default or gpbmodel.default_of
        suggested = list(gpbmodel.KEY_INFO) if keys is None else list(keys)
        self._suggested = suggested
        self.table = QTableWidget(0, 2)
        self.table.setHorizontalHeaderLabels(["KEY", "VALUE"])
        self.table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        kit.table_rows(self.table, 28)
        for key, value in phase.params.items():
            self._append(key, value)
        self.layout_.addWidget(self.table, 1)

        row = QHBoxLayout()
        row.setSpacing(7)
        self.key_combo = QComboBox()
        self.key_combo.setEditable(True)
        self.key_combo.addItems([k for k in suggested if k not in phase.params])
        self.key_combo.setToolTip("Pick a documented key or type any key name.")
        row.addWidget(self.key_combo, 1)
        row.addWidget(kit.button("Add key", self._add, "plus"))
        row.addWidget(kit.button("Remove", self._remove, "trash", "danger"))
        self.layout_.addLayout(row)
        self.add_buttons()
        self.resize(kit.px(620), kit.px(520))
        self.table.cellChanged.connect(self._describe)

    def _append(self, key, value):
        row = self.table.rowCount()
        self.table.insertRow(row)
        item = QTableWidgetItem(str(key))
        item.setToolTip(self._describe_key(key) or "")
        self.table.setItem(row, 0, item)
        self.table.setItem(row, 1, QTableWidgetItem(str(value)))

    def _describe(self, row, column):
        if column != 0:
            return
        item = self.table.item(row, 0)
        if item is not None:
            item.setToolTip(self._describe_key(item.text().strip()) or "")

    def _canonical(self, key):
        """*key* as documented when only its letter case differs: the tools
        read keys case-sensitively (``rhok`` is no key, ``rhoK`` is)."""
        if key in self._suggested:
            return key
        same = {k for k in self._suggested if k.lower() == key.lower()}
        return same.pop() if len(same) == 1 else key

    def _add(self):
        key = self._canonical(self.key_combo.currentText().strip())
        if not key:
            return
        self._append(key, self._default_of(key))

    def _remove(self):
        row = self.table.currentRow()
        if row >= 0:
            self.table.removeRow(row)

    def apply_to_phase(self):
        params = OrderedDict()
        for row in range(self.table.rowCount()):
            key = self.table.item(row, 0)
            value = self.table.item(row, 1)
            key = self._canonical(key.text().strip()) if key else ""
            value = value.text().strip() if value else ""
            if key:
                params[key] = value
        self.phase.params = params


class SpeciesPicker(_Dialog):
    """Searchable multi-select over the names of one source at a time.

    *sources* is an ordered ``{label: loader}``: the databases -- and, for a
    gas with a mechanism, the mechanism -- the names can come from, each one
    loaded when it is chosen.  *note*, given a label, says what picking from
    that source does to the phase; *what* names the entries listed.
    """

    def __init__(self, parent, kit, title, sources, current=None,
                 explanation="", note=None, what="entries"):
        super().__init__(parent, kit, title,
                         explanation or "Type to filter, pick one or more.")
        self.sources = OrderedDict(sources)
        self.note = note
        self.what = what
        self.names = []

        row = QHBoxLayout()
        row.setSpacing(8)
        row.addWidget(kit.section_label("DATABASE"))
        self.source_combo = QComboBox()
        for label in self.sources:
            self.source_combo.addItem(label, label)
        self.source_combo.setCurrentIndex(
            max(self.source_combo.findData(current), 0))
        self.source_combo.setToolTip("Where the names come from.")
        row.addWidget(self.source_combo, 1)
        self.layout_.addLayout(row)
        self.note_label = kit.hint("")
        self.layout_.addWidget(self.note_label)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Filter…")
        self.search.textChanged.connect(self._filter)
        self.layout_.addWidget(self.search)
        self.list = QListWidget()
        self.list.setSelectionMode(
            QAbstractItemView.SelectionMode.ExtendedSelection)
        self.list.itemDoubleClicked.connect(lambda _i: self.accept())
        self.layout_.addWidget(self.list, 1)
        self.count_label = kit.hint("")
        self.layout_.addWidget(self.count_label)
        self.source_combo.currentIndexChanged.connect(lambda _i: self._load())
        self._load()
        self.add_buttons()
        self.resize(kit.px(480), kit.px(620))
        self.search.setFocus()

    def source(self):
        return self.source_combo.currentData()

    def _load(self):
        label = self.source()
        self.names = list(self.sources[label]()) if label else []
        text = self.note(label) if (self.note and label) else ""
        self.note_label.setText(text)
        self.note_label.setVisible(bool(text))
        self._filter(self.search.text())

    def _fill(self, names):
        self.list.clear()
        for name in names[:4000]:
            self.list.addItem(QListWidgetItem(name))

    def _filter(self, text):
        text = text.strip().lower()
        shown = [n for n in self.names if text in n.lower()] if text \
            else self.names
        self._fill(shown)
        label = self.source()
        if not self.names:
            message = f"{label} holds no {self.what}."
            if label == "NASA7":
                message += (" Its files come with Cantera, so they are found "
                            "only where GPB's conda environment is installed.")
            self.count_label.setText(message)
        elif text:
            self.count_label.setText(
                f"{len(shown)} of the {len(self.names)} {self.what} of {label}")
        else:
            self.count_label.setText(f"{len(self.names)} {self.what} in {label}")

    def chosen(self):
        return [item.text() for item in self.list.selectedItems()]

    @staticmethod
    def choose(parent, kit, title, sources, current=None, explanation="",
               note=None, what="entries"):
        """``(source label, [names])`` picked, or ``(None, [])``."""
        dialog = SpeciesPicker(parent, kit, title, sources, current,
                               explanation, note, what)
        if dialog.exec() == QDialog.DialogCode.Accepted and dialog.chosen():
            return dialog.source(), dialog.chosen()
        return None, []


def pick_from_database(parent, kit, phase, title, case_dir=None,
                       with_mechanism=True):
    """Pick names for *phase* out of the databases it can read.

    The picker lists one database at a time, only the states the phase type
    is made of (gases for a gas, solids for a wall), and opens on the one GPB
    will look the names up in.  GPB reads every name of the phase from that
    single database, so names taken from another one need ``thermo`` switched
    to it.

    Returns ``(names, thermo)``: *thermo* is the value the phase's ``thermo``
    key needs for those names to be found, or None when it can stay.
    """
    gas = phase.family == "gas"
    if gas and phase.has("CEA-file"):
        databases = ["NASA9"]           # CEA-file makes GPB read NASA9 only
    elif gas:
        databases = list(gpbmodel.THERMO_DATABASES)
    else:
        databases = list(gpbmodel.CONDENSED_THERMO)
    reading = phase.thermo_database()
    noun = "species" if gas else "material"

    sources = OrderedDict()
    mechanism = phase.get("reactions") if (gas and with_mechanism) else ""
    if mechanism:
        sources[f"Mechanism {mechanism}"] = \
            lambda: database.species_of_mechanism(mechanism, case_dir)
    for name in databases:
        sources[name] = \
            lambda name=name: database.species_of_database(name, phase.type)
    current = next(iter(sources)) if mechanism else (reading or "NASA9")

    def note(label):
        if label not in databases:
            return "The species of the mechanism, with the thermo the file gives them."
        if label == reading:
            if phase.get("thermo"):
                return f"GPB reads the {noun} names of this phase from {label}."
            return (f"GPB reads the {noun} names of this phase from {label}, "
                    f"its database when thermo is not set.")
        text = (f"Picking from {label} sets thermo = {label}: GPB reads every "
                f"{noun} of this phase from it.")
        if gas and phase.has("reactions") and not phase.get("thermo"):
            text += " That replaces the thermo records of the mechanism too."
        elif not gas and not reading:
            text += " Materials it does not hold keep the constants of the table."
        return text

    what = database.describe_states(phase.type)
    kind = gpbmodel.TYPE_LABEL.get(phase.type, phase.type).lower()
    article = "an" if kind[:1] in "aeiou" else "a"
    source, names = SpeciesPicker.choose(
        parent, kit, title, sources, current,
        f"Only the {what} {article} {kind} phase can hold are listed. Type to "
        f"filter, pick one or more.", note, what)
    if not names:
        return [], None
    thermo = source if (source in databases and source != reading) else None
    return names, thermo
