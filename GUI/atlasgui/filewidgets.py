"""Choosing a file for an INI key: the field, the table column, the dialog.

Three pieces, all driven by :mod:`.filekeys`:

:class:`FileField`
    a path with a *Browse* button and a found / missing mark.
:class:`FileColumn`
    gives an existing KEY / VALUE table a browse column, so any key that takes
    a file can be filled without typing.
:class:`FilesDialog`
    the files of one section in one window: every key of that kind, whether or
    not it is set yet.

What is written into the INI is decided by :func:`filekeys.value_for`: a path
relative to the case directory when the file is inside it, the bare stem for a
key that takes one.  The tools run in the case directory and the solvers read
some of these names verbatim, so a file outside it is worth a word with the
user -- that is :func:`pick_value`, which offers to copy it in.
"""

from __future__ import annotations

import os
import shutil

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QComboBox, QFileDialog, QFormLayout, QHBoxLayout, QHeaderView, QLabel,
    QLineEdit, QMessageBox, QWidget,
)

from . import filekeys
from .widgets import Dialog

#: colour token per state of a stored value
STATE_TOKEN = {
    "found": "success",
    "missing": "danger_text",
    "too-long": "danger_text",
    "keyword": "text_dim",
    "empty": "muted",
}
STATE_ICON = {
    "found": "check",
    "missing": "alert",
    "too-long": "alert",
    "keyword": "info",
    "empty": "file",
}


def _case_dir_of(provider):
    return provider() if callable(provider) else (provider or os.getcwd())


def _start_dir(value, case_dir, role):
    """Where the file dialog should open."""
    state, path, _why = filekeys.status(value, case_dir, role)
    if state == "found":
        return path if role.kind in (filekeys.DIR, filekeys.PREFIX) \
            else os.path.dirname(path)
    return case_dir


def _offer_copy(parent, path, case_dir, title, question):
    """Ask whether to copy *path* into the case directory; return the path to use."""
    box = QMessageBox(parent)
    box.setWindowTitle(title)
    box.setIcon(QMessageBox.Icon.Question)
    box.setText(question)
    box.setInformativeText(f"Case directory: {case_dir}")
    copy = box.addButton("Copy it here", QMessageBox.ButtonRole.AcceptRole)
    keep = box.addButton("Use the path as it is", QMessageBox.ButtonRole.ActionRole)
    box.addButton(QMessageBox.StandardButton.Cancel)
    box.setDefaultButton(copy)
    box.exec()
    clicked = box.clickedButton()
    if clicked is keep:
        return path
    if clicked is not copy:
        return None
    target = os.path.join(case_dir, os.path.basename(path))
    if os.path.exists(target) and not os.path.samefile(path, target):
        if QMessageBox.question(
                parent, "Replace file",
                f"{os.path.basename(path)} already exists in the case "
                "directory. Replace it?") != QMessageBox.StandardButton.Yes:
            return None
    try:
        if not os.path.exists(target) or not os.path.samefile(path, target):
            shutil.copy2(path, target)
    except OSError as error:
        QMessageBox.warning(parent, "Copy failed", str(error))
        return None
    return target


def pick_value(parent, role, current, case_dir):
    """Run the chooser for *role* and return the value to store, or ``None``.

    Where the tool would not find the file -- a stem outside the search path,
    a series name too long for the BC record -- the user is offered a copy into
    the case directory instead of being left with a path that fails at run time.
    """
    start = _start_dir(current, case_dir, role)
    if role.kind == filekeys.DIR:
        path = QFileDialog.getExistingDirectory(
            parent, f"Choose the {role.label}", start)
    elif role.kind == filekeys.PREFIX:
        path = QFileDialog.getExistingDirectory(
            parent, f"Choose the {role.label} directory", start)
    else:
        path, _filter = QFileDialog.getOpenFileName(
            parent, f"Choose the {role.label}", start, ";;".join(role.filters))
    if not path:
        return None
    path = os.path.abspath(path)

    if role.kind == filekeys.STEM and \
            not filekeys.in_search_path(path, case_dir, role):
        where = " or ".join(["the case directory"] + [
            os.path.relpath(d, filekeys.ATLAS_ROOT) for d in role.search])
        path = _offer_copy(
            parent, path, case_dir, "Outside the search path",
            f"{os.path.basename(path)} is not in {where}, and the key names "
            "the file without its directory, so the tool would not find it.")
        if path is None:
            return None

    value = filekeys.value_for(path, case_dir, role)
    if role.max_len and len(value) > role.max_len:
        path = _offer_copy(
            parent, path, case_dir, "Name too long",
            f"The boundary record keeps {role.max_len} characters of this "
            f"name and '{value}' is {len(value)}, so the solver would look for "
            "a file that does not exist.")
        if path is None:
            return None
        value = filekeys.value_for(path, case_dir, role)
    return value


class FileField(QWidget):
    """A path for one key: line edit, found/missing mark, *Browse*."""

    changed = pyqtSignal(str)

    def __init__(self, kit, role, value="", case_dir=".", parent=None,
                 browse_text="Browse…"):
        super().__init__(parent)
        self.kit = kit
        self.role = role
        self._case_dir = case_dir
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(7)
        self.edit = QLineEdit(value or "")
        self.edit.setPlaceholderText(role.label)
        self.edit.setToolTip(role.hint or role.label)
        self.edit.textEdited.connect(self._on_typed)
        self.mark = QLabel()
        self.mark.setFixedWidth(18)
        button = kit.button(browse_text, self._browse, "open",
                            tip=role.hint or f"Choose the {role.label}")
        row.addWidget(self.edit, 1)
        row.addWidget(self.mark)
        row.addWidget(button)
        kit.register_repaint(self._paint_mark)
        self._paint_mark()

    # -- value ----------------------------------------------------------
    def value(self):
        return self.edit.text().strip()

    def set_value(self, value):
        self.edit.setText(value or "")
        self._paint_mark()

    def case_dir(self):
        return _case_dir_of(self._case_dir)

    def _on_typed(self, text):
        self._paint_mark()
        self.changed.emit(text.strip())

    def _browse(self):
        value = pick_value(self, self.role, self.value(), self.case_dir())
        if value is None:
            return
        self.edit.setText(value)
        self._paint_mark()
        self.changed.emit(value)

    def _paint_mark(self):
        state, _path, why = filekeys.status(
            self.value(), self.case_dir(), self.role)
        self.mark.setPixmap(self.kit.pixmap(
            STATE_ICON[state], STATE_TOKEN[state], 15))
        self.mark.setToolTip(why or "")


class FileColumn:
    """A browse column on a KEY / VALUE table, for the rows that take a file.

    The table keeps its own editing: this only adds the button and marks a
    value that does not resolve, so a hand-typed path is checked too.
    """

    WIDTH = 34

    def __init__(self, table, kit, context, case_dir, on_change=None):
        self.table = table
        self.kit = kit
        self.context = context
        self._case_dir = case_dir
        self.on_change = on_change
        table.setColumnCount(3)
        header = table.horizontalHeader()
        labels = [table.horizontalHeaderItem(i).text() if
                  table.horizontalHeaderItem(i) else "" for i in range(2)]
        table.setHorizontalHeaderLabels(labels + [""])
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        table.setColumnWidth(2, self.WIDTH)
        kit.register_repaint(self.refresh)

    def case_dir(self):
        return _case_dir_of(self._case_dir)

    def role_of_row(self, row):
        item = self.table.item(row, 0)
        return filekeys.role_of(item.text() if item else "", self.context)

    def refresh(self):
        """Put a button on every file row and mark the values. Signal-safe."""
        table = self.table
        blocked = table.signalsBlocked()
        table.blockSignals(True)
        for row in range(table.rowCount()):
            role = self.role_of_row(row)
            if role is None:
                if table.cellWidget(row, 2) is not None:
                    table.removeCellWidget(row, 2)
                self._mark(row, None)
                continue
            if table.cellWidget(row, 2) is None:
                button = self.kit.button("", None, "open",
                                         tip=f"Choose the {role.label}")
                button.setFixedWidth(self.WIDTH - 6)
                button.clicked.connect(
                    lambda _checked=False, r=row: self.browse(r))
                table.setCellWidget(row, 2, button)
            self._mark(row, role)
        table.blockSignals(blocked)

    def _mark(self, row, role):
        item = self.table.item(row, 1)
        if item is None:
            return
        if role is None:
            item.setData(Qt.ItemDataRole.ForegroundRole, None)
            return
        state, _path, why = filekeys.status(
            item.text().strip(), self.case_dir(), role)
        item.setForeground(
            self.kit.color_brush(STATE_TOKEN[state])
            if state in ("missing", "too-long") else
            self.kit.color_brush("text"))
        item.setToolTip(why or role.hint or "")

    def browse(self, row):
        role = self.role_of_row(row)
        if role is None:
            return
        item = self.table.item(row, 1)
        current = item.text().strip() if item else ""
        value = pick_value(self.table, role, current, self.case_dir())
        if value is None:
            return
        if item is None:
            from PyQt6.QtWidgets import QTableWidgetItem
            item = QTableWidgetItem("")
            self.table.setItem(row, 1, item)
        item.setText(value)              # fires cellChanged: the panel commits
        if self.on_change is not None:
            self.on_change()
        self.refresh()


class FilesDialog(Dialog):
    """Every file one section can take, in one window.

    *params* is the key/value mapping of the section; a row writes into it as
    soon as it changes (and clearing a row removes the key), like the rest of
    the GUI, so the only button needed is *Close*.
    """

    def __init__(self, parent, kit, title, explanation, params, rows,
                 extra_keys=(), case_dir=".", on_change=None):
        super().__init__(parent, kit, title, explanation, icon="file")
        self.params = params
        self.case_dir = case_dir
        self.on_change = on_change
        self._fields = {}

        self.form = QFormLayout()
        self.form.setSpacing(8)
        self.form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        self.layout_.addLayout(self.form)
        for key, role in rows:
            self._add_row(key, role)

        self._extra = [(k, r) for k, r in extra_keys if k not in self._fields]
        if self._extra:
            add = QHBoxLayout()
            add.setSpacing(7)
            self.combo = QComboBox()
            for key, role in self._extra:
                self.combo.addItem(f"{key}   ·   {role.label}", key)
            add.addWidget(kit.section_label("ANOTHER KEY"))
            add.addWidget(self.combo, 1)
            add.addWidget(kit.button("Add", self._add_chosen, "plus"))
            self.layout_.addLayout(add)
        self.layout_.addStretch(1)
        self.add_buttons(close_only=True)
        self.resize(760, 0)

    def _add_row(self, key, role):
        field = FileField(self.kit, role, self.params.get(key, ""),
                          self.case_dir, self)
        field.changed.connect(lambda value, k=key: self._commit(k, value))
        label = QLabel(key + ":")
        label.setToolTip(role.hint or role.label)
        self.form.addRow(label, field)
        self._fields[key] = field
        return field

    def _add_chosen(self):
        key = self.combo.currentData()
        role = dict(self._extra).get(key)
        if key is None or key in self._fields:
            return
        index = self.combo.currentIndex()
        self.combo.removeItem(index)
        self._extra = [(k, r) for k, r in self._extra if k != key]
        field = self._add_row(key, role)
        field._browse()
        if self.combo.count() == 0:
            self.combo.setEnabled(False)

    def _commit(self, key, value):
        if value:
            self.params[key] = value
        else:
            self.params.pop(key, None)
        if self.on_change is not None:
            self.on_change()
