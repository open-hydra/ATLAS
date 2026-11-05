"""Dialogs of the Initial stage: splitting a block into zones, and the
profile of a value (``<key>-file``); the plot of a nozzle's cross-sections.

The profile dialog edits what ICB reads: a two-column table along a letter
(the rows edited here and written to the file only when they changed), or a
Tecplot field whose cell-centred variable ICB takes (``icprofile``).  A plot
shows the table against the span of the zone's cell centres on the mesh, so a
table that misses some of them -- ICB stops on those -- is seen at once.
"""

from __future__ import annotations

import os
from collections import OrderedDict

import numpy as np
from PyQt6.QtCore import QPointF, QRectF, Qt
from PyQt6.QtGui import QColor, QPainter, QPainterPath, QPen
from PyQt6.QtWidgets import (
    QAbstractItemView, QButtonGroup, QComboBox, QDialog, QDialogButtonBox,
    QFormLayout, QHBoxLayout, QHeaderView, QLabel, QLineEdit, QMessageBox,
    QStackedWidget, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)

from . import filekeys, icgeom, icmodel, icprofile
from .filewidgets import pick_value

# What a cell compares along each letter of a block's direction (ICB).
LETTER_TIPS = OrderedDict([
    ("x", "x of the cell centre"),
    ("y", "y of the cell centre"),
    ("z", "z of the cell centre"),
    ("r", "distance of the cell centre from the x axis (from the origin, in "
          "the x-y plane, on a 2-D mesh)"),
    ("t", "angle of the cell centre about the x axis, in degrees from y "
          "towards z (in the x-y plane from x towards y on a 2-D mesh)"),
    ("i", "cell index along i, from 1"),
    ("j", "cell index along j, from 1"),
    ("k", "cell index along k, from 1"),
])
LETTER_UNITS = {"x": "m", "y": "m", "z": "m", "r": "m", "t": "deg"}


class SplitDialog(QDialog):
    """Split a block into zones along one letter, cut at the values given.

    *extent(letter)* gives the ``(low, high)`` the zones span; *count(direction,
    values)* the cells of a range on the mesh (None without it); the zones are
    named *base1*, *base2*, ... avoiding *taken*.
    """

    def __init__(self, parent, kit, title, extent, count, base, taken):
        super().__init__(parent)
        self.setWindowTitle(f"Split {title} into zones")
        self.kit = kit
        self._extent, self._count = extent, count
        self._base, self._taken = base, set(taken)
        self._plan = None
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.addWidget(kit.hint(
            "Each zone takes the cells between two cuts and starts from the "
            "present state of the block; give each its own state afterwards. "
            "More letters, and ranges that are not slabs, are set in the zone "
            "table."))
        form = QFormLayout()
        form.setSpacing(8)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        self.letter = QComboBox()
        for letter, tip in LETTER_TIPS.items():
            self.letter.addItem(f"{letter}  —  {tip}", letter)
        self.cuts = QLineEdit()
        self.cuts.setPlaceholderText("the values between the zones, e.g. 0.005 0.02")
        self.span = kit.hint("")
        form.addRow("Along:", self.letter)
        form.addRow("Cut at:", self.cuts)
        form.addRow("", self.span)
        layout.addLayout(form)
        self.preview = QTableWidget(0, 4)
        self.preview.setHorizontalHeaderLabels(["Zone", "From", "To", "Cells"])
        self.preview.verticalHeader().setVisible(False)
        self.preview.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.preview.horizontalHeader().setSectionResizeMode(
            0, QHeaderView.ResizeMode.Stretch)
        kit.table_rows(self.preview, 28)
        layout.addWidget(self.preview, 1)
        self.message = QLabel()
        self.message.setWordWrap(True)
        layout.addWidget(self.message)
        self.buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok
                                        | QDialogButtonBox.StandardButton.Cancel)
        self.buttons.button(QDialogButtonBox.StandardButton.Ok).setText("Split")
        self.buttons.accepted.connect(self.accept)
        self.buttons.rejected.connect(self.reject)
        layout.addWidget(self.buttons)
        self.letter.currentIndexChanged.connect(lambda _i: self._update())
        self.cuts.textChanged.connect(lambda _t: self._update())
        self.resize(kit.px(620), kit.px(460))
        self._update()

    def _make_plan(self):
        letter = self.letter.currentData()
        low, high = self._extent(letter)
        lo, hi = icmodel.to_float(low), icmodel.to_float(high)
        tokens = self.cuts.text().replace(",", " ").split()
        values = [icmodel.to_float(t) for t in tokens]
        if any(v is None for v in values):
            return None, f"{tokens[values.index(None)]} is not a number."
        index = letter in icgeom.INDEX_LETTERS
        if index and any(v != int(v) for v in values):
            return None, f"A cut along {letter} is a cell index: a whole number."
        cuts = sorted(set(values))
        outside = [v for v in cuts if not lo < v < hi]
        if outside:
            return None, (f"{outside[0]:g} is not inside the block: {letter} runs "
                          f"from {low} to {high}.")
        if index and cuts and cuts[-1] >= hi:
            return None, f"The last cell along {letter} is {high}."
        texts = {v: t for v, t in zip(values, tokens)}
        bounds = [low] + [texts[v] if not index else str(int(v)) for v in cuts] + [high]
        ranges = []
        for n in range(len(bounds) - 1):
            start = bounds[n] if n == 0 or not index else str(int(cuts[n - 1]) + 1)
            ranges.append([start, bounds[n + 1]])
        taken, names = set(self._taken), []
        for _r in ranges:
            name = icmodel.unique_name(self._base, taken)
            taken.add(name)
            names.append(name)
        return (letter, ranges, names), ""

    def _update(self):
        letter = self.letter.currentData()
        low, high = self._extent(letter)
        self.span.setText(f"{letter} runs from {low} to {high} on this block"
                          + (f" [{LETTER_UNITS[letter]}]" if letter in LETTER_UNITS else "")
                          + ".")
        self._plan, problem = self._make_plan()
        ok = self.buttons.button(QDialogButtonBox.StandardButton.Ok)
        self.preview.setRowCount(0)
        if self._plan is None:
            self.message.setText(problem)
            self.message.setProperty("check", "fail")
            ok.setEnabled(False)
        else:
            direction, ranges, names = self._plan
            self.preview.setRowCount(len(ranges))
            for r, (values, name) in enumerate(zip(ranges, names)):
                cells = self._count(direction, [icmodel.to_float(v) for v in values])
                for c, text in enumerate([name, values[0], values[1],
                                          "—" if cells is None else f"{cells:,}"]):
                    self.preview.setItem(r, c, QTableWidgetItem(text))
            self.message.setText(
                f"{len(ranges)} zone(s)." if len(ranges) > 1 else
                "One zone, the whole block: give cut values to have more.")
            self.message.setProperty("check", "pass" if len(ranges) > 1 else None)
            ok.setEnabled(True)
        self.message.style().unpolish(self.message)
        self.message.style().polish(self.message)

    def result_values(self):
        """``(direction, ranges, names)`` of the split."""
        return self._plan



class ProfilePlot(QWidget):
    """A profile table against its coordinate, with the span of the zone's
    cell centres shaded: in the accent colour where the table holds it, in
    the danger colour where it does not (ICB stops there)."""

    def __init__(self, kit):
        super().__init__()
        self.kit = kit
        self.coords, self.values, self.span = [], [], None
        self.setMinimumHeight(kit.px(170))

    def set_data(self, coords, values, span):
        self.coords, self.values, self.span = list(coords), list(values), span
        self.update()

    def paintEvent(self, _event):
        kit = self.kit
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.fillRect(self.rect(), QColor(kit.color("surface")))
        box = QRectF(self.rect()).adjusted(kit.px(58), kit.px(10), -kit.px(14), -kit.px(26))
        painter.setPen(QPen(QColor(kit.color("border")), 1))
        painter.drawRect(box)
        painter.setPen(QColor(kit.color("muted")))
        if len(self.coords) < 1:
            painter.drawText(box, Qt.AlignmentFlag.AlignCenter, "No point yet")
            return
        xs = list(self.coords) + (list(self.span) if self.span else [])
        x0, x1 = min(xs), max(xs)
        y0, y1 = min(self.values), max(self.values)
        if x1 == x0:
            x0, x1 = x0 - 0.5, x1 + 0.5
        if y1 == y0:
            y0, y1 = y0 - (abs(y0) * 0.1 or 1.0), y1 + (abs(y1) * 0.1 or 1.0)
        pad = 0.06 * (y1 - y0)
        y0, y1 = y0 - pad, y1 + pad

        def px(x):
            return box.left() + (x - x0) / (x1 - x0) * box.width()

        def py(y):
            return box.bottom() - (y - y0) / (y1 - y0) * box.height()

        if self.span:
            low, high = self.span
            first, last = self.coords[0], self.coords[-1]
            for a, b, token in ((low, min(high, first), "danger"),
                                (max(low, first), min(high, last), "accent"),
                                (max(low, last), high, "danger")):
                if b > a or (token == "accent" and b >= a):
                    color = QColor(kit.color(token))
                    color.setAlpha(46)
                    painter.fillRect(QRectF(px(a), box.top(), max(px(b) - px(a), 1.5),
                                            box.height()), color)
        line = QPainterPath(QPointF(px(self.coords[0]), py(self.values[0])))
        for x, y in zip(self.coords[1:], self.values[1:]):
            line.lineTo(QPointF(px(x), py(y)))
        painter.setPen(QPen(QColor(kit.color("accent")), kit.px(2)))
        painter.drawPath(line)
        painter.setBrush(QColor(kit.color("accent")))
        radius = kit.px(3)
        for x, y in zip(self.coords, self.values):
            painter.drawEllipse(QPointF(px(x), py(y)), radius, radius)
        painter.setPen(QColor(kit.color("muted")))
        metrics = painter.fontMetrics()
        for value, x in ((x0, box.left()), (x1, box.right())):
            text = f"{value:.4g}"
            painter.drawText(QPointF(min(max(x - metrics.horizontalAdvance(text) / 2, 0),
                                         self.width() - metrics.horizontalAdvance(text)),
                                     box.bottom() + metrics.height()), text)
        for value, y in ((y1, box.top()), (y0, box.bottom())):
            text = f"{value:.4g}"
            painter.drawText(QPointF(box.left() - metrics.horizontalAdvance(text) - kit.px(6),
                                     y + metrics.ascent() / 2), text)


class NozzlePlot(QWidget):
    """The cross-sections of a block as the nozzle law reads them: A/A* of
    every row of cells against x, the throat marked, the plenum rows shaded,
    and the two branches of the law named -- subsonic upstream of the throat
    along the flow, supersonic downstream."""

    def __init__(self, kit):
        super().__init__()
        self.kit = kit
        self.geometry = self.plenum = self.law = self.threshold = None
        self.towards_minus = False
        self.setMinimumHeight(kit.px(180))

    def set_data(self, geometry, plenum, towards_minus, threshold=None):
        """*geometry* an :class:`icgeom.NozzleGeometry`, *plenum* its rows at
        rest (:func:`icgeom.plenum_rows`; the law takes the others), or both
        None; *threshold* the x of ``nozzle-threshold``, drawn as a line."""
        self.geometry, self.plenum, self.threshold = geometry, plenum, threshold
        self.law = None if plenum is None else ~plenum
        self.towards_minus = towards_minus
        self.update()

    def paintEvent(self, _event):
        kit = self.kit
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.fillRect(self.rect(), QColor(kit.color("surface")))
        box = QRectF(self.rect()).adjusted(kit.px(46), kit.px(24), -kit.px(14), -kit.px(26))
        painter.setPen(QPen(QColor(kit.color("border")), 1))
        painter.drawRect(box)
        painter.setPen(QColor(kit.color("muted")))
        geometry = self.geometry
        if geometry is None:
            painter.drawText(box, Qt.AlignmentFlag.AlignCenter, "Load the mesh to see the "
                             "cross-sections")
            return
        x, ratio = geometry.x, geometry.ratio
        if not np.isfinite(ratio).all():
            painter.drawText(box, Qt.AlignmentFlag.AlignCenter, "A row has no cross-section")
            return
        ordered = not geometry.short.startswith("i does not")
        x0, x1 = float(x.min()), float(x.max())
        y0, y1 = 1.0, float(ratio.max())
        if x1 == x0:
            x0, x1 = x0 - 0.5, x1 + 0.5
        if y1 - y0 < 1e-6:
            y0, y1 = 0.9, 1.1
        pad = 0.08 * (y1 - y0)
        y0, y1 = y0 - pad, y1 + pad
        if ordered and len(x) > 1:          # the rows span x from edge to edge
            half = 0.5 * np.diff(x)
            edges = np.concatenate([[x[0] - half[0]], x[:-1] + half, [x[-1] + half[-1]]])
            x0, x1 = float(edges[0]), float(edges[-1])
        else:
            edges = None

        def px(value):
            return box.left() + (value - x0) / (x1 - x0) * box.width()

        def py(value):
            return box.bottom() - (value - y0) / (y1 - y0) * box.height()

        metrics = painter.fontMetrics()
        taken = []                          # (left, right) of the words at the top
        if edges is not None and self.plenum is not None and self.plenum.any():
            shade = QColor(kit.color("muted"))
            shade.setAlpha(46)
            rows = np.flatnonzero(self.plenum)
            left, right = px(edges[rows[0]]), px(edges[rows[-1] + 1])
            painter.fillRect(QRectF(left, box.top(), right - left, box.height()), shade)
            painter.setPen(QColor(kit.color("muted")))
            # centred on its rows, inside the box when they are narrower than the word
            width = metrics.horizontalAdvance("plenum")
            middle = 0.5 * (left + right)
            tx = min(max(middle - width / 2, box.left() + kit.px(4)),
                     box.right() - width - kit.px(4))
            # at the top unless the curve climbs there: then at the bottom
            under = np.interp([x0 + (x1 - x0) * (t - box.left()) / box.width()
                               for t in (tx, tx + width)], x, ratio)
            top = py(float(under.max())) > box.top() + 2 * metrics.height()
            ty = box.top() + metrics.height() if top else box.bottom() - kit.px(6)
            painter.drawText(QPointF(tx, ty), "plenum")
            if top:
                taken.append((tx, tx + width))
        if self.threshold is not None and x0 <= self.threshold <= x1:
            # the threshold itself: the rows centred upstream of it are the plenum
            painter.setPen(QPen(QColor(kit.color("text_dim")), 1))
            tx = px(self.threshold)
            painter.drawLine(QPointF(tx, box.top()), QPointF(tx, box.bottom()))
        nozzle = not geometry.problem       # a refused block: its sections only
        throat_x = px(float(x[geometry.throat]))
        if nozzle:
            pen = QPen(QColor(kit.color("accent")), 1, Qt.PenStyle.DashLine)
            painter.setPen(pen)
            painter.drawLine(QPointF(throat_x, box.top()), QPointF(throat_x, box.bottom()))
            painter.setPen(QColor(kit.color("text_dim")))
            text = "throat"
            painter.drawText(QPointF(min(max(throat_x - metrics.horizontalAdvance(text) / 2,
                                             box.left() + metrics.horizontalAdvance("A/A*  ")),
                                         box.right() - metrics.horizontalAdvance(text)),
                                     box.top() - kit.px(6)), text)
        if nozzle and edges is not None and self.law is not None and self.law.any():
            # each branch named over the rows of the law on its side of the throat
            rows = np.arange(len(x))
            upstream = rows > geometry.throat if self.towards_minus else rows < geometry.throat
            painter.setPen(QColor(kit.color("muted")))
            for side, name in ((upstream, "subsonic"), (~upstream & (rows != geometry.throat),
                                                        "supersonic")):
                written = np.flatnonzero(side & self.law)
                if not written.size:
                    continue
                low, high = edges[written[0]], edges[written[-1] + 1]
                middle = 0.5 * (px(low) + px(high))
                width = metrics.horizontalAdvance(name)
                tx = min(max(middle - width / 2, box.left() + kit.px(4)),
                         box.right() - width - kit.px(4))
                # at the top unless the curve climbs there: then at the bottom
                under = np.interp([x0 + (x1 - x0) * (t - box.left()) / box.width()
                                   for t in (tx, tx + width)], x, ratio)
                top = py(float(under.max())) > box.top() + 2 * metrics.height()
                ty = box.top() + metrics.height() if top else box.bottom() - kit.px(6)
                gap = kit.px(8)
                for low_x, high_x in taken if top else ():
                    # a narrow plenum's word reaches over these rows: step aside
                    if tx < high_x + gap and tx + width > low_x - gap:
                        tx = (high_x + gap if middle > 0.5 * (low_x + high_x)
                              else low_x - gap - width)
                painter.drawText(QPointF(tx, ty), name)
        token = "accent" if nozzle else "danger"
        line = QPainterPath(QPointF(px(float(x[0])), py(float(ratio[0]))))
        for a, b in zip(x[1:], ratio[1:]):
            line.lineTo(QPointF(px(float(a)), py(float(b))))
        painter.setPen(QPen(QColor(kit.color(token)), kit.px(2)))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawPath(line)
        radius = kit.px(3)
        for n, (a, b) in enumerate(zip(x, ratio)):
            law = self.law is None or bool(self.law[n])
            painter.setBrush(QColor(kit.color(token if law else "surface")))
            painter.drawEllipse(QPointF(px(float(a)), py(float(b))), radius, radius)
        painter.setPen(QColor(kit.color("muted")))
        tiny = 1e-9 * (x1 - x0)
        for value, edge in ((x0, box.left()), (x1, box.right())):
            text = f"{0.0 if abs(value) < tiny else value:.4g}"
            painter.drawText(QPointF(min(max(edge - metrics.horizontalAdvance(text) / 2, 0),
                                         self.width() - metrics.horizontalAdvance(text)),
                                     box.bottom() + metrics.height()), text)
        text = "x [m]"
        painter.drawText(QPointF(box.center().x() - metrics.horizontalAdvance(text) / 2,
                                 box.bottom() + metrics.height()), text)
        for value in sorted({round(float(ratio.max()), 6), 1.0}):
            y = py(value)
            text = f"{value:.3g}"
            painter.drawText(QPointF(box.left() - metrics.horizontalAdvance(text) - kit.px(6),
                                     y + metrics.ascent() / 2), text)
        painter.drawText(QPointF(box.left(), box.top() - kit.px(6)), "A/A*")


class ProfileDialog(QDialog):
    """The profile of the value *key* of *state*.

    *span_of(letter)* gives the span of the zone's cell centres along a
    letter (t in degrees), *coverage(letter, table)* the zone cells a table
    misses ``(count, first)``; both None without the mesh.  *suggest* is the
    file name offered for a new table.  After ``exec``, :attr:`outcome` says
    what was done to the state: ``"profile"`` or ``"constant"``.
    """

    def __init__(self, parent, kit, key, label, unit, state, case_dir, where,
                 span_of, coverage, suggest):
        super().__init__(parent)
        self.setWindowTitle(f"Profile of {label}")
        self.kit, self.key, self.label, self.unit = kit, key, label, unit
        self.state, self.case_dir = state, case_dir
        self._span_of, self._coverage = span_of, coverage
        self.role = filekeys.role_of(f"{key}-file", "icb-section")
        self.outcome = None
        self._loading = False
        self._loaded = None            # (coords, values) as read from the table file
        current = icmodel.profile_of(state, key)
        file0, letter0 = current if current else ("", "")
        self.mode = "field" if current and not letter0 else "table"

        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.addWidget(kit.hint(
            f"{label}{f' [{unit}]' if unit else ''} of {where}, cell by cell, from a "
            "file: ICB reads it in place of the constant."))
        self.seg_box, self.seg_buttons = self._segmented(
            [("table", "Table along a direction"), ("field", "Tecplot field")])
        layout.addWidget(self.seg_box)
        self.pages = QStackedWidget()
        self.pages.addWidget(self._table_page(file0 if self.mode == "table" and file0
                                              else suggest, letter0 or "x"))
        self.pages.addWidget(self._field_page(file0 if self.mode == "field" else ""))
        layout.addWidget(self.pages, 1)

        bottom = QHBoxLayout()
        if current:
            bottom.addWidget(kit.button("Use a constant", self._use_constant, "reset",
                                        tip=f"Drop the profile: {key} is given as one value again."))
        bottom.addStretch(1)
        self.buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok
                                        | QDialogButtonBox.StandardButton.Cancel)
        self.buttons.button(QDialogButtonBox.StandardButton.Ok).setText("Use this profile")
        self.buttons.accepted.connect(self._accept)
        self.buttons.rejected.connect(self.reject)
        bottom.addWidget(self.buttons)
        layout.addLayout(bottom)
        self.resize(kit.px(720), kit.px(640))
        self._set_mode(self.mode)

    # -- layout ------------------------------------------------------------
    def _segmented(self, options):
        box = QWidget()
        row = QHBoxLayout(box)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(0)
        group = QButtonGroup(box)
        buttons = {}
        for i, (value, text) in enumerate(options):
            button = self.kit.button(text, None, None,
                                     seg="left" if i == 0 else "right")
            button.setCheckable(True)
            button.clicked.connect(lambda _c=False, v=value: self._set_mode(v))
            group.addButton(button)
            row.addWidget(button)
            buttons[value] = button
        row.addStretch(1)
        return box, buttons

    def _file_row(self, edit, slot):
        row = QHBoxLayout()
        row.setSpacing(7)
        row.addWidget(edit, 1)
        row.addWidget(self.kit.button("Open…", slot, "open",
                                      tip=self.role.hint if self.role else None))
        return row

    def _table_page(self, file_value, letter):
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(8)
        form = QFormLayout()
        form.setSpacing(8)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        self.letter = QComboBox()
        for name in icmodel.PROFILE_DIRECTIONS:
            self.letter.addItem(f"{name}  —  {LETTER_TIPS[name]}", name)
        self.letter.setCurrentIndex(max(self.letter.findData(letter), 0))
        self.letter.currentIndexChanged.connect(lambda _i: self._update_table())
        self.table_file = QLineEdit(file_value)
        self.table_file.setPlaceholderText("a file of the case, e.g. T-profile.dat")
        self.table_file.editingFinished.connect(lambda: self._load_table(self.table_file.text()))
        form.addRow("Along:", self.letter)
        form.addRow("File:", self._file_row(self.table_file, self._open_table))
        v.addLayout(form)
        self.grid = QTableWidget(0, 2)
        self.grid.verticalHeader().setVisible(False)
        self.grid.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.grid.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.kit.table_rows(self.grid, 26)
        self.grid.itemChanged.connect(lambda _i: self._update_table())
        tools = QHBoxLayout()
        tools.setSpacing(7)
        tools.addWidget(self.kit.button("Add row", self._add_row, "plus"))
        tools.addWidget(self.kit.button("Remove row", self._remove_row, "trash"))
        tools.addWidget(self.kit.button("Sort", self._sort_rows, "sliders",
                                        tip="Order the rows by coordinate."))
        tools.addStretch(1)
        body = QHBoxLayout()
        body.setSpacing(10)
        left = QVBoxLayout()
        left.addWidget(self.grid, 1)
        left.addLayout(tools)
        body.addLayout(left, 2)
        self.plot = ProfilePlot(self.kit)
        body.addWidget(self.plot, 3)
        v.addLayout(body, 1)
        self.table_status = QLabel()
        self.table_status.setWordWrap(True)
        v.addWidget(self.table_status)
        self._load_table(file_value)
        return page

    def _field_page(self, file_value):
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(8)
        form = QFormLayout()
        form.setSpacing(8)
        self.field_file = QLineEdit(file_value)
        self.field_file.setPlaceholderText("a Tecplot file (.tec, .szplt)")
        self.field_file.textChanged.connect(lambda _t: self._update_field())
        form.addRow("File:", self._file_row(self.field_file, self._open_field))
        v.addLayout(form)
        self.field_info = QLabel()
        self.field_info.setWordWrap(True)
        v.addWidget(self.field_info)
        v.addWidget(self.kit.hint(
            "Each cell takes the value of the nearest cell of the file: the "
            "first variable after the coordinates, which must be cell-centred. "
            "The grid of the file can be any structured grid."))
        v.addStretch(1)
        return page

    # -- behaviour -----------------------------------------------------------
    def _set_mode(self, mode):
        self.mode = mode
        for value, button in self.seg_buttons.items():
            button.setChecked(value == mode)
        self.pages.setCurrentIndex(0 if mode == "table" else 1)
        if mode == "table":
            self._update_table()
        else:
            self._update_field()

    def _path(self, value):
        return icprofile.resolve(value, self.case_dir)

    def _open_table(self):
        value = pick_value(self, self.role, self.table_file.text(), self.case_dir)
        if value is not None:
            self.table_file.setText(value)
            self._load_table(value)

    def _open_field(self):
        value = pick_value(self, self.role, self.field_file.text(), self.case_dir)
        if value is not None:
            self.field_file.setText(value)

    def _load_table(self, value):
        """Show the rows of the file *value*; keep the rows typed so far when
        it does not exist (they become the new file)."""
        path = self._path(value)
        if not path or not os.path.isfile(path):
            self._loaded = None
            if self.grid.rowCount() == 0:
                self._fill([], [])
            self._update_table()
            return
        table = icprofile.read_table(path)
        self._loaded = (table.coords, table.values)
        self._fill(table.coords, table.values)

    def _fill(self, coords, values):
        self._loading = True
        self.grid.setRowCount(max(len(coords), 2))
        for r in range(self.grid.rowCount()):
            for c, source in enumerate((coords, values)):
                text = repr(source[r]) if r < len(source) else ""
                self.grid.setItem(r, c, QTableWidgetItem(text))
        self._loading = False
        self._update_table()

    def _rows(self):
        """``(coords, values, bad)`` of the grid: rows left empty are not rows."""
        coords, values, bad = [], [], []
        for r in range(self.grid.rowCount()):
            texts = [(self.grid.item(r, c).text().strip() if self.grid.item(r, c) else "")
                     for c in (0, 1)]
            if not any(texts):
                continue
            numbers = [icmodel.to_float(t) for t in texts]
            if any(n is None for n in numbers):
                bad.append(r + 1)
                continue
            coords.append(numbers[0])
            values.append(numbers[1])
        return coords, values, bad

    def _add_row(self):
        self.grid.insertRow(self.grid.rowCount())

    def _remove_row(self):
        row = self.grid.currentRow()
        if row >= 0:
            self.grid.removeRow(row)
            self._update_table()

    def _sort_rows(self):
        coords, values, _bad = self._rows()
        pairs = sorted(zip(coords, values))
        self._fill([c for c, _v in pairs], [v for _c, v in pairs])

    def _table(self):
        coords, values, bad = self._rows()
        text = "\n".join(f"{c!r} {v!r}" for c, v in zip(coords, values))
        table = icprofile.parse_table(text)
        if bad:
            table.problems.insert(0, ("error", f"row(s) {', '.join(map(str, bad))} "
                                               "are not two numbers"))
        return table

    def _update_table(self):
        if self._loading or not hasattr(self, "buttons"):
            return          # still being built: _set_mode updates it last
        letter = self.letter.currentData()
        unit = LETTER_UNITS.get(letter, "")
        self.grid.setHorizontalHeaderLabels([
            f"{letter}{f' [{unit}]' if unit else ''}",
            f"{self.label}{f' [{self.unit}]' if self.unit else ''}"])
        table = self._table()
        span = self._span_of(letter)
        self.plot.set_data(table.coords, table.values, span)
        lines, ok = [], table.ok and len(table.coords) >= 2
        for level, text in table.problems:
            lines.append(("✗  " if level == "error" else "!  ") + text)
        if ok and span is not None:
            missed = self._coverage(letter, table)
            low, high = span
            if missed and missed[0]:
                count, first = missed
                lines.append(f"✗  {count:,} cell(s) of the zone lie outside the table "
                             f"(the zone's centres run from {low:.6g} to {high:.6g} along "
                             f"{letter}; the first is cell {first}): ICB stops on them.")
                ok = False
            else:
                lines.append(f"✓  The table holds every cell centre of the zone "
                             f"({letter} from {low:.6g} to {high:.6g}).")
        elif ok:
            lines.append("Load the mesh to check that the table holds every cell of the zone.")
        if not self.table_file.text().strip():
            lines.append("✗  Give the table a file name: it is written next to the case.")
            ok = False
        self.table_status.setText("\n".join(lines))
        self.table_status.setProperty("check", "pass" if ok else "fail")
        self.table_status.style().unpolish(self.table_status)
        self.table_status.style().polish(self.table_status)
        if self.mode == "table":
            self.buttons.button(QDialogButtonBox.StandardButton.Ok).setEnabled(
                table.ok and len(table.coords) >= 2 and bool(self.table_file.text().strip()))

    def _update_field(self):
        if not hasattr(self, "buttons"):
            return
        value = self.field_file.text().strip()
        path = self._path(value)
        ok = False
        if not value:
            text = "Choose the Tecplot file."
        elif not os.path.isfile(path):
            text = f"✗  {value} is not in the case directory."
        else:
            field = icprofile.read_field(path)
            if field.binary:
                text, ok = "A binary Tecplot file: ICB reads it when built with TecIO.", True
            else:
                zones = ", ".join(" × ".join(str(n) for n in z) for z in field.zones[:4])
                text = (f"{len(field.zones)} block(s) ({zones} nodes); variables "
                        f"{', '.join(field.variables)}.")
                if field.value:
                    text += f"\nICB takes {field.value}"
                    text += " (cell-centred)." if field.cell_centred else "."
                problems = [t for level, t in field.problems if level == "error"]
                text += "".join(f"\n✗  {t}" for t in problems)
                ok = field.ok
        self.field_info.setText(text)
        self.field_info.setProperty("check", "pass" if ok else "fail")
        self.field_info.style().unpolish(self.field_info)
        self.field_info.style().polish(self.field_info)
        if self.mode == "field":
            self.buttons.button(QDialogButtonBox.StandardButton.Ok).setEnabled(bool(value))

    def _use_constant(self):
        icmodel.clear_profile(self.state, self.key)
        self.outcome = "constant"
        self.accept()

    def _accept(self):
        if self.mode == "field":
            icmodel.set_profile(self.state, self.key, self.field_file.text().strip(), "")
            self.outcome = "profile"
            self.accept()
            return
        value = self.table_file.text().strip()
        path = self._path(value)
        coords, values, _bad = self._rows()
        pairs = (coords, values)
        if self._loaded is None or (list(self._loaded[0]), list(self._loaded[1])) != pairs:
            if os.path.isfile(path):
                reply = QMessageBox.question(
                    self, "Write the table",
                    f"{value} exists: write the rows of this table over it?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
                if reply != QMessageBox.StandardButton.Yes:
                    return
            try:
                os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
                icprofile.write_table(path, coords, values,
                                      f"{self.letter.currentData()} {self.label}"
                                      " (coordinate, value): read by ICB")
            except OSError as exc:
                QMessageBox.warning(self, "Write the table", f"{value}: {exc.strerror}")
                return
        icmodel.set_profile(self.state, self.key, value, self.letter.currentData())
        self.outcome = "profile"
        self.accept()
