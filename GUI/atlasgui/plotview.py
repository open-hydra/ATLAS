"""Plots of the tables GPB writes: curves against the temperature
(:class:`XYPlot`) and a quantity over the (p, h) grid of a real fluid
(:class:`MapPlot`), drawn with QPainter in the colours of the theme.

They follow the GUI's data-viz rules: one y axis; thin 2 px lines in the
categorical colours, which the caller gives each curve and keeps while it is
shown; a legend (the caller's list) and, up to four curves, the names at the
ends of the lines; hairline grid and axes in the muted ink, the text never
in a series colour.  Hovering shows the values under the cursor (a crosshair
and a panel); dragging across a plot zooms into the span, a double click goes
back to all of it.  A map is coloured with the scales of
:mod:`atlasgui.fieldcolors`, its iso-lines at the values the colour bar
marks.
"""

from __future__ import annotations

import math

import numpy as np
from PyQt6.QtCore import QLineF, QPointF, QRectF, Qt, pyqtSignal
from PyQt6.QtGui import QColor, QFontMetricsF, QImage, QPainter, QPainterPath, QPen
from PyQt6.QtWidgets import QWidget

from .fieldview import format_value

# the categorical palette of the data-viz reference, in its fixed order:
# light steps, dark steps (validated on adjacent pairs in both modes)
SERIES = {
    "light": ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300",
              "#6250d6", "#e34948"],
    "dark": ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300",
             "#9085e9", "#e66767"],
}
MAX_SERIES = len(SERIES["light"])
DIRECT_LABELS = 4                 # up to this many curves, named at their ends
LOG_DECADES = 24                  # a log axis reaches this far below its top

_SUPER = str.maketrans("-0123456789", "⁻⁰¹²³⁴⁵⁶⁷⁸⁹")


def superscript(n):
    return str(n).translate(_SUPER)


# ------------------------------------------------------------------- scales
class Scale:
    """A linear or logarithmic map of values onto pixels, its ticks and
    their labels (the power of ten common to them goes into the title)."""

    def __init__(self, low, high, log=False):
        self.log = log
        if log:
            low, high = math.log10(low), math.log10(high)
        if not high > low:
            pad = abs(low) * 0.05 or 1.0
            low, high = low - pad, high + pad
        self.low, self.high = low, high
        self.p0 = self.p1 = 0.0

    def place(self, p0, p1):
        self.p0, self.p1 = p0, p1
        return self

    def map(self, values):
        values = np.asarray(values, dtype=float)
        if self.log:
            with np.errstate(divide="ignore", invalid="ignore"):
                values = np.where(values > 0, np.log10(np.where(values > 0, values, 1.0)),
                                  np.nan)
        return self.p0 + (values - self.low) / (self.high - self.low) * (self.p1 - self.p0)

    def value(self, pixel):
        t = self.low + (pixel - self.p0) / (self.p1 - self.p0) * (self.high - self.low)
        return 10 ** t if self.log else t

    def ticks(self, count=6):
        """``(values, labels, power)``: the tick values, their labels and the
        power of ten the labels leave out (0: none)."""
        if self.log:
            first, last = math.floor(self.low), math.ceil(self.high)
            every = max(1, math.ceil((last - first) / max(count, 1)))
            values = [10.0 ** e for e in range(first, last + 1, every)
                      if self.low - 1e-9 <= e <= self.high + 1e-9]
            if len(values) < 2:                  # less than a decade: 1, 2, 5 steps
                values = [m * 10.0 ** e for e in range(first - 1, last + 1) for m in (1, 2, 5)
                          if self.low - 1e-9 <= math.log10(m * 10.0 ** e) <= self.high + 1e-9]
            labels = [_log_label(v) for v in values]
            return values, labels, 0
        values, step = nice_ticks(self.low, self.high, count)
        reach = max(abs(self.low), abs(self.high))
        power = 0
        if reach >= 1e4 or 0 < reach < 1e-2:
            power = 3 * math.floor(math.log10(reach) / 3)
        scaled = step / 10.0 ** power
        decimals = max(0, -math.floor(math.log10(scaled) + 1e-9))
        if abs(round(scaled * 10 ** decimals) - scaled * 10 ** decimals) > 1e-6:
            decimals += 1                         # a step of 2.5
        labels = [f"{v / 10.0 ** power:.{decimals}f}".replace("-", "−") for v in values]
        labels = ["0" if float(t.replace("−", "-")) == 0 else t for t in labels]
        return values, labels, power


def nice_ticks(low, high, count=6):
    """``(values, step)``: round values from *low* to *high*, about *count*."""
    span = high - low
    raw = span / max(count, 1)
    magnitude = 10.0 ** math.floor(math.log10(raw))
    for factor in (1, 2, 2.5, 5, 10):
        if raw <= factor * magnitude * 1.0001:
            step = factor * magnitude
            break
    first = math.ceil(low / step - 1e-9) * step
    values = [first + n * step for n in range(int((high - first) / step + 1e-9) + 1)]
    return [0.0 if abs(v) < step * 1e-9 else v for v in values], step


def _log_label(value):
    exponent = round(math.log10(value))
    if abs(value - 10.0 ** exponent) < 1e-9 * value:
        return {0: "1", 1: "10"}.get(exponent, f"10{superscript(exponent)}")
    return format_value(value)


def axis_title(label, unit, power):
    """``μ · viscosity [10⁻⁶ Pa·s]``: the label, the power of ten the tick
    labels leave out, the unit."""
    scale = f"10{superscript(power)}" if power else ""
    inside = " ".join(part for part in (scale, unit if unit != "–" else "") if part)
    return f"{label} [{inside}]" if inside else label


# ------------------------------------------------------------------ helpers
def _hover_panel(painter, kit, anchor, area, title, rows):
    """A panel of *rows* ``(colour or None, text)`` under *title*, beside
    *anchor* and kept inside *area*."""
    metrics = QFontMetricsF(painter.font())
    line = metrics.height()
    pad = kit.px(8)
    swatch = kit.px(9)
    width = max([metrics.horizontalAdvance(title)]
                + [metrics.horizontalAdvance(text) + (swatch + kit.px(6) if colour else 0)
                   for colour, text in rows]) + 2 * pad
    height = line * (1 + len(rows)) + 2 * pad + kit.px(2)
    x = anchor.x() + kit.px(14)
    if x + width > area.right():
        x = anchor.x() - kit.px(14) - width
    x = max(area.left(), x)
    y = min(max(area.top(), anchor.y() - height / 2), area.bottom() - height)
    box = QRectF(x, y, width, height)
    background = QColor(kit.color("surface"))
    background.setAlpha(240)
    painter.setPen(QPen(QColor(kit.color("border_strong")), 1))
    painter.setBrush(background)
    painter.drawRoundedRect(box, 6, 6)
    painter.setPen(QColor(kit.color("text")))
    font = painter.font()
    bold = painter.font()
    bold.setBold(True)
    painter.setFont(bold)
    painter.drawText(QPointF(x + pad, y + pad + metrics.ascent()), title)
    painter.setFont(font)
    for n, (colour, text) in enumerate(rows, start=1):
        base = y + pad + kit.px(2) + n * line
        left = x + pad
        if colour:
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(colour))
            painter.drawEllipse(QRectF(left, base + (line - swatch) / 2, swatch, swatch))
            left += swatch + kit.px(6)
        painter.setPen(QColor(kit.color("text")))
        painter.drawText(QPointF(left, base + metrics.ascent()), text)


def _ink(kit, token, alpha=None):
    colour = QColor(kit.color(token))
    if alpha is not None:
        colour.setAlpha(alpha)
    return colour


class _Plot(QWidget):
    """What both plots share: the frame, the axes and their titles, the
    crosshair, the drag to zoom along x."""

    zoomed = pyqtSignal()

    def __init__(self, kit, parent=None):
        super().__init__(parent)
        self.kit = kit
        self.setMouseTracking(True)
        self.setMinimumHeight(kit.px(220))
        self.empty_text = "Nothing to draw"
        self.hover = None              # QPointF of the cursor over the plot area
        self.drag = None               # x where a drag started
        self.drag_to = None            # x the drag has reached
        self.span = None               # (low, high) of x shown, None: all
        self.box = QRectF()
        kit.register_repaint(self.update)

    # -- zoom along x ----------------------------------------------------
    def reset_zoom(self):
        if self.span is not None:
            self.span = None
            self.zoomed.emit()
            self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self.box.contains(event.position()):
            self.drag = event.position().x()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        position = event.position()
        self.hover = position if self.box.contains(position) else None
        if self.drag is not None:
            self.drag_to = min(max(position.x(), self.box.left()), self.box.right())
        self.update()

    def mouseReleaseEvent(self, event):
        if self.drag is not None and event.button() == Qt.MouseButton.LeftButton:
            x0, x1 = sorted((self.drag, min(max(event.position().x(), self.box.left()),
                                            self.box.right())))
            self.drag = self.drag_to = None
            if x1 - x0 > self.kit.px(8) and self._xscale is not None:
                self.span = (self._xscale.value(x0), self._xscale.value(x1))
                self.zoomed.emit()
            self.update()
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        self.reset_zoom()

    def leaveEvent(self, event):
        self.hover = None
        self.update()
        super().leaveEvent(event)

    _xscale = None

    # -- drawing ---------------------------------------------------------
    def _frame(self, painter, xscale, yscale, xtitle, ytitle, right=0.0):
        """The grid, the axes, their ticks and titles; places the scales in
        the plot area and returns it."""
        kit = self.kit
        metrics = QFontMetricsF(painter.font())
        line = metrics.height()
        xticks, xlabels, xpower = xscale.ticks(7)
        yticks, ylabels, ypower = yscale.ticks(6)
        left = max([metrics.horizontalAdvance(t) for t in ylabels] + [0]) + kit.px(10)
        box = QRectF(self.rect()).adjusted(left + kit.px(4), line + kit.px(10),
                                           -kit.px(12) - right, -(2 * line + kit.px(12)))
        self.box = box
        xscale.place(box.left(), box.right())
        yscale.place(box.bottom(), box.top())
        grid = QPen(_ink(kit, "border"), 1)
        painter.setPen(grid)
        for value in yticks:
            y = float(yscale.map(value))
            painter.drawLine(QPointF(box.left(), y), QPointF(box.right(), y))
        painter.setPen(QPen(_ink(kit, "border_strong"), 1))
        painter.drawLine(box.bottomLeft(), box.bottomRight())
        painter.drawLine(box.bottomLeft(), box.topLeft())
        painter.setPen(_ink(kit, "muted"))
        for value, text in zip(yticks, ylabels):
            y = float(yscale.map(value))
            painter.drawText(QRectF(0, y - line / 2, box.left() - kit.px(6), line),
                             Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, text)
        last = -1e9
        for value, text in zip(xticks, xlabels):
            x = float(xscale.map(value))
            width = metrics.horizontalAdvance(text)
            if x - width / 2 < last + kit.px(6):
                continue                     # no label over another
            painter.drawLine(QPointF(x, box.bottom()), QPointF(x, box.bottom() + kit.px(4)))
            painter.drawText(QRectF(x - width / 2 - 2, box.bottom() + kit.px(4), width + 4, line),
                             Qt.AlignmentFlag.AlignCenter, text)
            last = x + width / 2
        painter.setPen(_ink(kit, "text_dim"))
        painter.drawText(QRectF(box.left(), box.bottom() + line + kit.px(6), box.width(), line),
                         Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop,
                         axis_title(*xtitle, xpower))
        painter.drawText(QRectF(kit.px(2), 0, self.width(), line + kit.px(4)),
                         Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                         axis_title(*ytitle, ypower))
        return box

    def _drag_band(self, painter):
        if self.drag is None or self.drag_to is None:
            return
        x0, x1 = sorted((self.drag, self.drag_to))
        band = _ink(self.kit, "accent", 40)
        painter.fillRect(QRectF(x0, self.box.top(), x1 - x0, self.box.height()), band)

    def _empty(self, painter):
        painter.setPen(_ink(self.kit, "muted"))
        painter.drawText(QRectF(self.rect()), Qt.AlignmentFlag.AlignCenter
                         | Qt.TextFlag.TextWordWrap, self.empty_text)


# ------------------------------------------------------------------- curves
class XYPlot(_Plot):
    """Curves against one x: ``set_data`` takes the axis titles and
    ``[(label, colour, x, y)]``."""

    def __init__(self, kit, parent=None):
        super().__init__(kit, parent)
        self.series = []
        self.xtitle = self.ytitle = ("", "")
        self.log = False
        self.unit = ""

    def set_data(self, xtitle, ytitle, series, log=False):
        """*xtitle*, *ytitle*: ``(label, unit)``; *series*: ``[(label,
        colour, x, y)]``; *log*: the y axis logarithmic."""
        if xtitle != self.xtitle:           # another axis: the zoom does not carry over
            self.span = None
        self.xtitle, self.ytitle, self.series, self.log = xtitle, ytitle, series, log
        self.unit = ytitle[1]
        self.update()

    def _ranges(self):
        xs = [np.asarray(x, dtype=float) for _l, _c, x, _y in self.series]
        x0 = min(float(np.nanmin(x)) for x in xs)
        x1 = max(float(np.nanmax(x)) for x in xs)
        if self.span is not None:
            x0, x1 = max(x0, self.span[0]), min(x1, self.span[1])
        low, high = math.inf, -math.inf
        for _label, _colour, x, y in self.series:
            x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
            seen = y[(x >= x0) & (x <= x1) & np.isfinite(y) & ((y > 0) if self.log else True)]
            if seen.size:
                low, high = min(low, float(seen.min())), max(high, float(seen.max()))
        if not math.isfinite(low):
            return x0, x1, None
        if self.log:
            # a rate at 1 K is 1e-300: what is that far below the top is left off
            low = max(low, high * 10.0 ** -LOG_DECADES)
            return x0, x1, (low / 1.3, high * 1.3) if high > low else (low / 3, high * 3)
        pad = 0.05 * (high - low) or (abs(high) * 0.05 or 1.0)
        return x0, x1, (low - pad, high + pad)

    def paintEvent(self, _event):
        kit = self.kit
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        if not self.series:
            self._empty(painter)
            return
        x0, x1, yrange = self._ranges()
        if yrange is None:
            self.empty_text = ("No positive value to draw on a logarithmic scale"
                               if self.log else "No value to draw")
            self._empty(painter)
            return
        metrics = QFontMetricsF(painter.font())
        direct = len(self.series) <= DIRECT_LABELS
        right = (max(metrics.horizontalAdvance(_tag(s[0])) for s in self.series) + kit.px(8)
                 if direct else 0.0)
        right = min(right, self.width() * 0.3)
        xscale = Scale(x0, x1)
        yscale = Scale(*yrange, log=self.log)
        self._xscale = xscale
        box = self._frame(painter, xscale, yscale, self.xtitle, self.ytitle, right)
        painter.save()
        painter.setClipRect(box.adjusted(-2, -2, 2, 2))
        ends = []
        for label, colour, x, y in self.series:
            x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
            inside = (x >= x0) & (x <= x1)
            # one point beyond each end of the span keeps the line to the edge
            index = np.flatnonzero(inside)
            if index.size == 0:
                continue
            index = np.arange(max(index[0] - 1, 0), min(index[-1] + 2, len(x)))
            px, py = xscale.map(x[index]), yscale.map(y[index])
            path, drawing, last = QPainterPath(), False, None
            for u, v in zip(px, py):
                if not (math.isfinite(u) and math.isfinite(v)):
                    drawing = False
                    continue
                if drawing:
                    path.lineTo(u, v)
                else:
                    path.moveTo(u, v)
                    drawing = True
                last = (u, v)
            pen = QPen(QColor(colour), kit.px(2))
            pen.setCapStyle(Qt.PenCapStyle.RoundCap)
            pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawPath(path)
            if last is not None:
                ends.append([min(last[1], box.bottom()), label, colour])
        painter.restore()
        if direct and ends:
            self._direct_labels(painter, box, ends, metrics)
        self._drag_band(painter)
        if self.hover is not None and self.drag is None:
            self._hover(painter, box, xscale, yscale)

    def _direct_labels(self, painter, box, ends, metrics):
        """The name of each curve beside its end, the names kept apart."""
        line = metrics.height()
        ends.sort(key=lambda e: e[0])
        for n in range(1, len(ends)):
            ends[n][0] = max(ends[n][0], ends[n - 1][0] + line)
        overflow = ends[-1][0] + line / 2 - (box.bottom() + line)
        if overflow > 0:
            for end in ends:
                end[0] -= overflow
        painter.setPen(_ink(self.kit, "text_dim"))
        for y, label, _colour in ends:
            painter.drawText(QRectF(box.right() + self.kit.px(6), y - line / 2,
                                    self.width() - box.right(), line),
                             Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                             _tag(label))

    def _hover(self, painter, box, xscale, yscale):
        kit = self.kit
        xv = xscale.value(self.hover.x())
        x_line = self.hover.x()
        painter.setPen(QPen(_ink(kit, "border_strong"), 1, Qt.PenStyle.DashLine))
        painter.drawLine(QPointF(x_line, box.top()), QPointF(x_line, box.bottom()))
        rows = []
        surface = QColor(kit.color("surface"))
        for label, colour, x, y in self.series:
            x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
            if not x[0] <= xv <= x[-1]:
                continue
            value = float(np.interp(xv, x, y))
            if not math.isfinite(value):
                rows.append((colour, f"{_short(label)}  —"))
                continue
            py = float(yscale.map(value))
            if math.isfinite(py) and box.top() - 1 <= py <= box.bottom() + 1:
                painter.setPen(QPen(surface, 2))
                painter.setBrush(QColor(colour))
                painter.drawEllipse(QPointF(x_line, py), kit.px(4), kit.px(4))
            unit = f" {self.unit}" if self.unit and self.unit != "–" else ""
            rows.append((colour, f"{_short(label)}  {format_value(value)}{unit}"))
        label, unit = self.xtitle
        symbol = label.split(" · ")[0]
        title = f"{symbol} = {format_value(xv)} {unit}".rstrip()
        _hover_panel(painter, kit, self.hover, box, title, rows[:12])


def _short(label, size=34):
    return label if len(label) <= size else label[:size - 1] + "…"


def _tag(label):
    """The name at the end of a line: ``R4`` of ``R4 · 0.5 O2 + H2 → H2O``."""
    return _short(label.split(" · ")[0], 16)


# --------------------------------------------------------------------- maps
class MapPlot(_Plot):
    """A quantity over a rectilinear grid: the colours of the values, the
    iso-lines at *levels*, the values of every quantity under the cursor."""

    def __init__(self, kit, parent=None):
        super().__init__(kit, parent)
        self.image = None
        self.xs = self.ys = None
        self.values = None
        self.levels = []
        self.xtitle = self.ytitle = ("", "")
        self.readout = None            # (x, y) -> (title, [text])

    def set_data(self, xs, ys, values, colours, levels, xtitle, ytitle, readout):
        """*xs*, *ys*: the grid lines (I and J); *values* ``(I, J)``;
        *colours* ``(I, J, 3)`` uint8; *readout*: ``(x, y) -> (title,
        rows)`` for the panel under the cursor."""
        if xtitle != self.xtitle or ytitle != self.ytitle:
            self.span = None
        self.xs, self.ys = np.asarray(xs, float), np.asarray(ys, float)
        self.values = np.asarray(values, float)
        # one pixel per node, j upwards
        rgb = np.ascontiguousarray(np.transpose(colours, (1, 0, 2))[::-1], dtype=np.uint8)
        self._bytes = rgb.tobytes()
        self.image = QImage(self._bytes, rgb.shape[1], rgb.shape[0], 3 * rgb.shape[1],
                            QImage.Format.Format_RGB888)
        self.levels, self.xtitle, self.ytitle, self.readout = levels, xtitle, ytitle, readout
        self._lines = None
        self.update()

    def clear(self):
        self.image = None
        self.update()

    def paintEvent(self, _event):
        kit = self.kit
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.image is None:
            self._empty(painter)
            return
        x0, x1 = float(self.xs[0]), float(self.xs[-1])
        if self.span is not None:
            x0, x1 = max(x0, self.span[0]), min(x1, self.span[1])
        xscale = Scale(x0, x1)
        yscale = Scale(float(self.ys[0]), float(self.ys[-1]))
        self._xscale = xscale
        box = self._frame(painter, xscale, yscale, self.xtitle, self.ytitle)
        painter.save()
        painter.setClipRect(box)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        # the nodes at the pixel centres: the image reaches half a cell past them
        nx, ny = len(self.xs), len(self.ys)
        dx = (self.xs[-1] - self.xs[0]) / max(nx - 1, 1)
        dy = (self.ys[-1] - self.ys[0]) / max(ny - 1, 1)
        left, right = xscale.map([self.xs[0] - dx / 2, self.xs[-1] + dx / 2])
        top, bottom = yscale.map([self.ys[-1] + dy / 2, self.ys[0] - dy / 2])
        painter.drawImage(QRectF(float(left), float(top), float(right - left),
                                 float(bottom - top)), self.image)
        if self._lines is None:
            self._lines = [contour_segments(self.values, level) for level in self.levels]
        pen = QPen(QColor(0, 0, 0, 0), 1)
        ink = QColor(kit.color("text"))
        ink.setAlpha(110)
        pen.setColor(ink)
        painter.setPen(pen)
        for segments in self._lines:
            if not len(segments):
                continue
            fi = np.interp(segments[..., 0], np.arange(nx), self.xs)
            fj = np.interp(segments[..., 1], np.arange(ny), self.ys)
            px, py = xscale.map(fi), yscale.map(fj)
            painter.drawLines([QLineF(a, b, c, d) for a, b, c, d in
                               zip(px[:, 0], py[:, 0], px[:, 1], py[:, 1])])
        painter.restore()
        painter.setPen(QPen(_ink(kit, "border_strong"), 1))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRect(box)
        self._drag_band(painter)
        if self.hover is not None and self.drag is None and self.readout is not None:
            xv, yv = xscale.value(self.hover.x()), yscale.value(self.hover.y())
            painter.setPen(QPen(_ink(kit, "text", 150), 1, Qt.PenStyle.DashLine))
            painter.drawLine(QPointF(self.hover.x(), box.top()),
                             QPointF(self.hover.x(), box.bottom()))
            painter.drawLine(QPointF(box.left(), self.hover.y()),
                             QPointF(box.right(), self.hover.y()))
            title, rows = self.readout(xv, yv)
            _hover_panel(painter, kit, self.hover, box, title, [(None, r) for r in rows])


def contour_segments(values, level):
    """``(n, 2, 2)``: the segments of the iso-line *level* of the grid
    *values* ``(I, J)``, in fractional (i, j) -- marching squares, a saddle
    split by the mean of its corners."""
    z = np.asarray(values, dtype=float)
    if z.ndim != 2 or min(z.shape) < 2:
        return np.zeros((0, 2, 2))
    a, b = z[:-1, :-1], z[1:, :-1]          # (i, j), (i+1, j)
    c, d = z[1:, 1:], z[:-1, 1:]            # (i+1, j+1), (i, j+1)
    ii, jj = np.meshgrid(np.arange(z.shape[0] - 1), np.arange(z.shape[1] - 1), indexing="ij")

    def cross(p, q):
        with np.errstate(divide="ignore", invalid="ignore"):
            t = (level - p) / (q - p)
        hit = ((p > level) != (q > level)) & np.isfinite(p) & np.isfinite(q)
        return np.where(hit, t, np.nan)

    # the four edges: bottom (a-b), right (b-c), top (d-c), left (a-d)
    t = [cross(a, b), cross(b, c), cross(d, c), cross(a, d)]
    points = [np.stack([ii + t[0], jj + 0.0], -1), np.stack([ii + 1.0, jj + t[1]], -1),
              np.stack([ii + t[2], jj + 1.0], -1), np.stack([ii + 0.0, jj + t[3]], -1)]
    hits = np.stack([np.isfinite(x) for x in t], -1)
    count = hits.sum(-1)
    segments = []
    two = count == 2
    if two.any():
        order = np.argsort(~hits[two], axis=-1, kind="stable")[:, :2]
        stacked = np.stack([p[two] for p in points], 1)          # (m, 4, 2)
        rows = np.arange(len(order))
        segments.append(np.stack([stacked[rows, order[:, 0]], stacked[rows, order[:, 1]]], 1))
    four = count == 4
    if four.any():
        # a saddle: the lines cut off the two corners that are not on the
        # side of the centre
        centre = (a + b + c + d)[four] / 4 > level
        with_a = ((a[four] > level) == centre)[:, None]
        p = [x[four] for x in points]
        segments.append(np.stack([p[0], np.where(with_a, p[1], p[3])], 1))
        segments.append(np.stack([p[2], np.where(with_a, p[3], p[1])], 1))
    return np.concatenate(segments) if segments else np.zeros((0, 2, 2))
