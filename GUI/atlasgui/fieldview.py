"""What the Initial stage shows under its 3-D view when it shows the field ICB
wrote: which field and which quantity, the colour bar, and what to know about
the file (when it was written, whether the case has changed since, whether it
fits the mesh on the screen).

:class:`ColourBar` draws a scale of :mod:`atlasgui.fieldcolors` with its
values; :class:`FieldControls` gathers the controls, and tells the Initial
stage when the field or the quantity changes.  The colours of the cells are
the stage's to set (:mod:`atlasgui.icbpanel`).
"""

from __future__ import annotations

import numpy as np
from PyQt6.QtCore import QPointF, QRectF, Qt, pyqtSignal
from PyQt6.QtGui import QColor, QFont, QFontMetrics, QImage, QPainter, QPainterPath, QPen
from PyQt6.QtWidgets import QComboBox, QHBoxLayout, QLabel, QVBoxLayout, QWidget


def format_value(value):
    """Four significant digits, as a cell's value is read."""
    if value == 0 or not np.isfinite(value):
        return "0" if value == 0 else "—"
    text = f"{value:.4g}"
    if "e" in text:
        mantissa, exponent = text.split("e")
        text = f"{mantissa}e{int(exponent)}"
    return text.replace("-", "−")


class ColourBar(QWidget):
    """A colour scale: its quantity and unit, the gradient, the values at its
    ends (and zero, for a diverging scale), and the range of the values."""

    def __init__(self, kit, parent=None):
        super().__init__(parent)
        self.kit = kit
        self.table = None
        self.low = self.high = 0.0
        self.data = None                  # (min, max) of the values
        self.signed = False
        self.title = ""
        self.marks = []                   # values marked across the bar (iso-lines)
        kit.register_repaint(self._resize)
        self._resize()

    def _resize(self):
        metrics = QFontMetrics(self.font())
        self.setFixedHeight(2 * metrics.height() + self.kit.px(14) + 10)
        self.update()

    def show_scale(self, table, low, high, signed, title, data=None, marks=()):
        """*marks*: values drawn as ticks across the bar (the iso-lines of a
        map)."""
        self.table = np.ascontiguousarray(table, dtype=np.uint8)
        self.marks = list(marks)
        if signed:
            reach = max(abs(low), abs(high))
            low, high = -reach, reach
        self.low, self.high, self.signed = low, high, signed
        self.title, self.data = title, data
        self.update()

    def clear(self):
        self.table = None
        self.update()

    def paintEvent(self, _event):
        if self.table is None:
            return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        kit = self.kit
        metrics = QFontMetrics(self.font())
        line = metrics.height()
        width = self.width()
        bold = QFont(self.font())
        bold.setWeight(QFont.Weight.DemiBold)
        painter.setFont(bold)
        painter.setPen(QColor(kit.color("text")))
        painter.drawText(QRectF(0, 0, width, line), Qt.AlignmentFlag.AlignLeft
                         | Qt.AlignmentFlag.AlignVCenter, self.title)
        painter.setFont(self.font())
        if self.data is not None:
            painter.setPen(QColor(kit.color("muted")))
            text = f"values {format_value(self.data[0])} … {format_value(self.data[1])}"
            painter.drawText(QRectF(0, 0, width, line), Qt.AlignmentFlag.AlignRight
                             | Qt.AlignmentFlag.AlignVCenter, text)
        bar = QRectF(0.5, line + 4.5, width - 1.0, kit.px(14))
        image = QImage(self.table.tobytes(), len(self.table), 1, 3 * len(self.table),
                       QImage.Format.Format_RGB888)
        path = QPainterPath()
        path.addRoundedRect(bar, 3, 3)
        painter.save()
        painter.setClipPath(path)
        painter.drawImage(bar, image)
        painter.restore()
        if self.marks and self.high > self.low:
            ink = QColor(kit.color("text"))
            ink.setAlpha(150)
            painter.setPen(QPen(ink, 1))
            for value in self.marks:
                x = bar.left() + (value - self.low) / (self.high - self.low) * bar.width()
                if bar.left() < x < bar.right():
                    painter.drawLine(QPointF(x, bar.top() + 2), QPointF(x, bar.bottom() - 2))
        painter.setPen(QPen(QColor(kit.color("border_strong")), 1))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawPath(path)
        painter.setPen(QColor(kit.color("text_dim")))
        y = bar.bottom() + 3
        labels = [(self.low, Qt.AlignmentFlag.AlignLeft), (self.high, Qt.AlignmentFlag.AlignRight)]
        if self.signed:
            labels.append((0.0, Qt.AlignmentFlag.AlignHCenter))
        elif self.high > self.low:
            labels.append((0.5 * (self.low + self.high), Qt.AlignmentFlag.AlignHCenter))
        for value, align in labels:
            painter.drawText(QRectF(0, y, width, line), align | Qt.AlignmentFlag.AlignTop,
                             format_value(value))
        painter.end()


class FieldControls(QWidget):
    """Which field (one per phase ICB wrote) and which quantity, the colour
    bar, and the notes on the field.  ``changed`` asks the stage to repaint."""

    changed = pyqtSignal()

    def __init__(self, kit, parent=None):
        super().__init__(parent)
        self.kit = kit
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        row = QHBoxLayout()
        row.setSpacing(6)
        row.addWidget(kit.section_label("INITIAL FIELD"))
        row.addStretch(1)
        self.phase = QComboBox()
        self.phase.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
        self.phase.setMinimumContentsLength(8)
        self.phase.setToolTip("The phase whose field is shown: ICB writes one file per phase")
        self.phase.currentIndexChanged.connect(lambda _i: self.changed.emit())
        row.addWidget(self.phase)
        self.quantity = QComboBox()
        self.quantity.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
        self.quantity.setMinimumContentsLength(12)
        self.quantity.setToolTip("The quantity the cells are coloured by")
        self.quantity.currentIndexChanged.connect(lambda _i: self.changed.emit())
        row.addWidget(self.quantity)
        lay.addLayout(row)
        self.bar = ColourBar(kit)
        lay.addWidget(self.bar)
        self.warning = QLabel("")
        self.warning.setWordWrap(True)
        self.warning.setProperty("check", "fail")
        lay.addWidget(self.warning)
        self.note = kit.hint("")
        lay.addWidget(self.note)
        self.empty = QWidget()
        empty = QHBoxLayout(self.empty)
        empty.setContentsMargins(0, 0, 0, 0)
        empty.setSpacing(8)
        self.empty_text = kit.hint("")
        empty.addWidget(self.empty_text, 1)
        self.run_button = kit.button("Run ICB…", None, "play", "ghost",
                                     tip="The Run stage: run ICB to write the field")
        empty.addWidget(self.run_button)
        lay.addWidget(self.empty)

    # -- the choices -----------------------------------------------------
    def set_files(self, files, current):
        """Offer the field files *files* (``icfield.FieldFile``), *current*
        (a path) selected; the choice shows only when there are several."""
        paths = [f.path for f in files]
        if [self.phase.itemData(i) for i in range(self.phase.count())] != paths:
            self.phase.blockSignals(True)
            self.phase.clear()
            for f in files:
                self.phase.addItem(f.phase or "(unnamed phase)", f.path)
            self.phase.blockSignals(False)
        if current in paths and self.phase.currentIndex() != paths.index(current):
            self.phase.blockSignals(True)
            self.phase.setCurrentIndex(paths.index(current))
            self.phase.blockSignals(False)
        self.phase.setVisible(len(files) > 1)

    def file(self):
        return self.phase.currentData()

    def set_quantities(self, items, current):
        """Offer ``[(name, label, unit)]``, *current* selected when there."""
        names = [name for name, _l, _u in items]
        self.quantity.blockSignals(True)
        if [self.quantity.itemData(i) for i in range(self.quantity.count())] != names:
            self.quantity.clear()
            for name, label, unit in items:
                self.quantity.addItem(f"{label} [{unit}]" if unit else label, name)
        index = names.index(current) if current in names else 0
        if names:
            self.quantity.setCurrentIndex(index)
        self.quantity.blockSignals(False)
        self.quantity.setVisible(bool(names))

    def name(self):
        return self.quantity.currentData()

    # -- what is shown ---------------------------------------------------
    def show_field(self, table, low, high, signed, title, data, warnings, notes):
        self.empty.setVisible(False)
        self.bar.setVisible(True)
        self.bar.show_scale(table, low, high, signed, title, data)
        self._notes(warnings, notes)

    def show_empty(self, text, warnings=(), run=True):
        """No field to colour by: say why (and offer the Run stage)."""
        self.bar.clear()
        self.bar.setVisible(False)
        self.quantity.setVisible(False)
        self.empty.setVisible(True)
        self.empty_text.setText(text)
        self.run_button.setVisible(run)
        self._notes(warnings, ())

    def _notes(self, warnings, notes):
        self.warning.setText("\n".join(warnings))
        self.warning.setVisible(bool(warnings))
        self.note.setText("\n".join(notes))
        self.note.setVisible(bool(notes))
