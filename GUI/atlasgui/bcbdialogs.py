"""Dialogs of the Boundaries stage.

Creating a boundary condition is the one step where the GUI asks questions
before it has anything to show, so it asks all of them at once: the name, the
kind of boundary, and the files that kind reads -- a wall temperature table, an
inlet time series, the CEA deck of a burning surface.  Each file is chosen
through :mod:`.filewidgets`, so the value stored is the one the tool will find.
"""

from __future__ import annotations

from collections import OrderedDict

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QComboBox, QFormLayout, QHBoxLayout, QLabel, QLineEdit, QVBoxLayout,
    QWidget,
)

from . import filekeys
from .bcmodel import TYPED_BCS, file_keys_of
from .filewidgets import pick_value
from .widgets import Dialog, clear_layout

#: One line per type, shown under the chooser.
TYPE_HINTS = {
    "wall": "Solid surface: give q or T (never both), plus ks and eps.",
    "inlet": "Inflow: total conditions (p0, T0), a mass flux (g) or a "
             "supersonic state, optionally from a time series.",
    "outlet": "Pressure outflow: p and rf. A face named 'outlet' needs no "
              "section at all.",
    "manifold": "Plenum shared with another block.",
    "gsi": "Gas-surface interaction: burning propellant, pyrolysis, "
           "melting or surface reactions.",
    "periodic": "Periodic pair: blocks and faces give the two sides.",
}


class NewBCDialog(Dialog):
    """Name, type, and the files that type reads."""

    def __init__(self, parent, kit, taken, case_dir, default_type="wall"):
        super().__init__(
            parent, kit, "New boundary condition",
            "A named [section] of the INI. Faces are assigned to it by name, "
            "so several faces can share one boundary condition.",
            icon="cube")
        self.taken = set(taken)
        self.case_dir = case_dir
        self.files = OrderedDict()

        form = QFormLayout()
        form.setSpacing(8)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        self.name_edit = QLineEdit()
        self.name_edit.setPlaceholderText("wall_chamber")
        self.name_edit.textChanged.connect(lambda _t: self._validate())
        form.addRow("name:", self.name_edit)

        self.type_combo = QComboBox()
        self.type_combo.setEditable(True)
        self.type_combo.addItems(list(TYPED_BCS.keys()))
        index = self.type_combo.findText(default_type)
        if index >= 0:
            self.type_combo.setCurrentIndex(index)
        self.type_combo.currentTextChanged.connect(self._on_type_changed)
        form.addRow("type:", self.type_combo)
        self.layout_.addLayout(form)

        self.type_hint = kit.hint("")
        self.layout_.addWidget(self.type_hint)

        self.layout_.addWidget(kit.section_label("FILES THIS BOUNDARY READS"))
        self.file_list = QVBoxLayout()
        self.file_list.setSpacing(5)
        self.layout_.addLayout(self.file_list)

        attach = QHBoxLayout()
        attach.setSpacing(7)
        self.key_combo = QComboBox()
        attach.addWidget(self.key_combo, 1)
        attach.addWidget(kit.button("Browse…", self._attach, "open",
                                    tip="Choose a file for this key"))
        self.layout_.addLayout(attach)
        self.empty_hint = kit.hint("No file attached yet. Everything here can "
                                   "also be set later, from the BC editor.")
        self.layout_.addWidget(self.empty_hint)

        self.buttons = self.add_buttons()
        self._on_type_changed(self.type_combo.currentText())
        self._validate()
        self.resize(self.kit.px(640), 0)

    # -- type -----------------------------------------------------------
    def _on_type_changed(self, text):
        self.type_hint.setText(TYPE_HINTS.get(text, ""))
        self.key_combo.clear()
        for key in file_keys_of(text):
            role = filekeys.role_of(key)
            if role is not None and key not in self.files:
                self.key_combo.addItem(f"{key}   ·   {role.label}", key)
        self.key_combo.setEnabled(self.key_combo.count() > 0)

    # -- files ----------------------------------------------------------
    def _attach(self):
        key = self.key_combo.currentData()
        if not key:
            return
        role = filekeys.role_of(key)
        value = pick_value(self, role, self.files.get(key, ""), self.case_dir)
        if value is None:
            return
        self.files[key] = value
        self._refresh_files()

    def _refresh_files(self):
        clear_layout(self.file_list)
        for key, value in self.files.items():
            row = QWidget()
            line = QHBoxLayout(row)
            line.setContentsMargins(0, 0, 0, 0)
            line.setSpacing(7)
            line.addWidget(self.kit.icon_label("file", "accent", 15))
            label = QLabel(f"{key} = {value}")
            label.setProperty("role", "value")
            line.addWidget(label, 1)
            drop = self.kit.button(
                "", lambda _checked=False, k=key: self._drop(k), "trash",
                "ghost", tip=f"Do not set {key}")
            drop.setFixedWidth(self.kit.px(32))
            line.addWidget(drop)
            self.file_list.addWidget(row)
        self.empty_hint.setVisible(not self.files)
        self._on_type_changed(self.type_combo.currentText())

    def _drop(self, key):
        self.files.pop(key, None)
        self._refresh_files()

    # -- result ---------------------------------------------------------
    def _validate(self):
        name = self.name_edit.text().strip()
        from PyQt6.QtWidgets import QDialogButtonBox
        ok = self.buttons.button(QDialogButtonBox.StandardButton.Ok)
        ok.setEnabled(bool(name) and name not in self.taken)
        if name and name in self.taken:
            self.type_hint.setText(f"'{name}' is already used.")
        elif name:
            self.type_hint.setText(
                TYPE_HINTS.get(self.type_combo.currentText(), ""))

    def result_values(self):
        """``(name, type, {key: file})``."""
        return (self.name_edit.text().strip(),
                self.type_combo.currentText().strip(),
                OrderedDict(self.files))
