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
        self.table.verticalHeader().setDefaultSectionSize(30)
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
        self.resize(760, min(680, 190 + 30 * len(self.columns)))

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
        self.table = QTableWidget(0, 2)
        self.table.setHorizontalHeaderLabels(["SPECIES", "AMOUNT"])
        self.table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.verticalHeader().setDefaultSectionSize(28)
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
        self.resize(520, 440)

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
        chosen = SpeciesPicker.choose(
            self, self.kit, "Add species to the mixture",
            database.species_of_database(self.phase.get("thermo") or "NASA9"))
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


class AdvancedKeysDialog(_Dialog):
    """Every ``key = value`` line of the phase, as written to the INI."""

    def __init__(self, parent, kit, phase):
        super().__init__(
            parent, kit, "All keys of this phase",
            "The raw INI lines. Anything the form above does not cover can be "
            "set here; the form keeps whatever it does not know about.")
        self.phase = phase
        self.table = QTableWidget(0, 2)
        self.table.setHorizontalHeaderLabels(["KEY", "VALUE"])
        self.table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.verticalHeader().setDefaultSectionSize(28)
        for key, value in phase.params.items():
            self._append(key, value)
        self.layout_.addWidget(self.table, 1)

        row = QHBoxLayout()
        row.setSpacing(7)
        self.key_combo = QComboBox()
        self.key_combo.setEditable(True)
        self.key_combo.addItems([k for k in gpbmodel.KEY_INFO
                                 if k not in phase.params])
        self.key_combo.setToolTip("Pick a documented key or type any key name.")
        row.addWidget(self.key_combo, 1)
        row.addWidget(kit.button("Add key", self._add, "plus"))
        row.addWidget(kit.button("Remove", self._remove, "trash", "danger"))
        self.layout_.addLayout(row)
        self.add_buttons()
        self.resize(620, 520)
        self.table.cellChanged.connect(self._describe)

    def _append(self, key, value):
        row = self.table.rowCount()
        self.table.insertRow(row)
        item = QTableWidgetItem(str(key))
        item.setToolTip(gpbmodel.describe(key) or "")
        self.table.setItem(row, 0, item)
        self.table.setItem(row, 1, QTableWidgetItem(str(value)))

    def _describe(self, row, column):
        if column != 0:
            return
        item = self.table.item(row, 0)
        if item is not None:
            item.setToolTip(gpbmodel.describe(item.text().strip()) or "")

    def _add(self):
        key = self.key_combo.currentText().strip()
        if not key:
            return
        self._append(key, gpbmodel.default_of(key))

    def _remove(self):
        row = self.table.currentRow()
        if row >= 0:
            self.table.removeRow(row)

    def apply_to_phase(self):
        params = OrderedDict()
        for row in range(self.table.rowCount()):
            key = self.table.item(row, 0)
            value = self.table.item(row, 1)
            key = key.text().strip() if key else ""
            value = value.text().strip() if value else ""
            if key:
                params[key] = value
        self.phase.params = params


class SpeciesPicker(_Dialog):
    """Searchable multi-select over a species or material list."""

    def __init__(self, parent, kit, title, names, explanation=""):
        super().__init__(parent, kit, title,
                         explanation or f"{len(names)} entries in the database. "
                                        "Type to filter, pick one or more.")
        self.names = list(names)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Filter…")
        self.search.textChanged.connect(self._filter)
        self.layout_.addWidget(self.search)
        self.list = QListWidget()
        self.list.setSelectionMode(
            QAbstractItemView.SelectionMode.ExtendedSelection)
        self.list.itemDoubleClicked.connect(lambda _i: self.accept())
        self.layout_.addWidget(self.list, 1)
        self._fill(self.names)
        self.add_buttons()
        self.resize(460, 560)
        self.search.setFocus()

    def _fill(self, names):
        self.list.clear()
        for name in names[:4000]:
            self.list.addItem(QListWidgetItem(name))

    def _filter(self, text):
        text = text.strip().lower()
        if not text:
            self._fill(self.names)
            return
        self._fill([n for n in self.names if text in n.lower()])

    def chosen(self):
        return [item.text() for item in self.list.selectedItems()]

    @staticmethod
    def choose(parent, kit, title, names, explanation=""):
        if not names:
            return []
        dialog = SpeciesPicker(parent, kit, title, names, explanation)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            return dialog.chosen()
        return []
