"""Vector icons for the BCB GUI, drawn at runtime with QPainter.

Every interface icon is a short stroked path drawn on a transparent pixmap in
a 24x24 design grid and tinted with a colour token, so the whole icon set
re-colours when the theme changes.  The one image file is the application
icon, ``assets/atlas-icon.png`` (rendered from ``atlas-icon.svg``), which is
a placeholder until ATLAS has its logo: replace both files to change it.

Public helpers
--------------
``icon(name, color, size)``   -> :class:`QIcon` for buttons / tabs / tree items
``pixmap(name, color, size)`` -> the same artwork as a :class:`QPixmap`
``dot(color, size)``          -> filled colour swatch used for BC colours
``app_icon(accent, bg)``      -> window / Dock icon (the asset, else drawn)
"""

from __future__ import annotations

import math
import os

from PyQt6.QtCore import QPointF, QRectF, Qt
from PyQt6.QtGui import QColor, QIcon, QPainter, QPainterPath, QPen, QPixmap

GRID = 24.0          # design grid every path is drawn in
_SCALE = 2           # supersampling factor for crisp icons on any DPI
APP_ICON_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "assets", "atlas-icon.png")


# --------------------------------------------------------------- primitives
def _stroke(p, color, width=1.9):
    pen = QPen(QColor(color), width)
    pen.setCapStyle(Qt.PenCapStyle.RoundCap)
    pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
    p.setPen(pen)
    p.setBrush(Qt.BrushStyle.NoBrush)


def _fill(p, color):
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(QColor(color))


def _poly(p, pts, close=False):
    path = QPainterPath(QPointF(*pts[0]))
    for xy in pts[1:]:
        path.lineTo(QPointF(*xy))
    if close:
        path.closeSubpath()
    p.drawPath(path)


# -------------------------------------------------------------------- icons
def _mesh(p, c):
    _stroke(p, c)
    _poly(p, [(12, 3), (21, 7.5), (21, 16.5), (12, 21), (3, 16.5), (3, 7.5)], True)
    _poly(p, [(3, 7.5), (12, 12), (21, 7.5)])
    _poly(p, [(12, 12), (12, 21)])


def _cube(p, c):
    _stroke(p, c, 1.7)
    _poly(p, [(4, 8), (12, 4), (20, 8), (20, 16), (12, 20), (4, 16)], True)
    _poly(p, [(4, 8), (12, 12), (20, 8)])
    _poly(p, [(12, 12), (12, 20)])


def _open(p, c):
    _stroke(p, c)
    _poly(p, [(3, 19), (3, 6), (9.5, 6), (11.5, 8.5), (19, 8.5), (19, 11)])
    _poly(p, [(2.5, 19), (5.5, 11.5), (22, 11.5), (19, 19)], True)


def _save(p, c):
    _stroke(p, c)
    _poly(p, [(4, 15), (4, 19.5), (20, 19.5), (20, 15)])
    _poly(p, [(12, 3.5), (12, 14.5)])
    _poly(p, [(7.5, 10), (12, 14.8), (16.5, 10)])


def _save_as(p, c):
    _stroke(p, c)
    _poly(p, [(4, 15), (4, 19.5), (13, 19.5)])
    _poly(p, [(10, 3.5), (10, 14.5)])
    _poly(p, [(5.5, 10), (10, 14.8), (14.5, 10)])
    _poly(p, [(16, 19.5), (16, 16.3), (20.6, 11.7), (22, 13.1), (17.4, 17.7), (16, 19.5)])


def _fit(p, c):
    _stroke(p, c)
    _poly(p, [(4, 9), (4, 4), (9, 4)])
    _poly(p, [(15, 4), (20, 4), (20, 9)])
    _poly(p, [(20, 15), (20, 20), (15, 20)])
    _poly(p, [(9, 20), (4, 20), (4, 15)])


def _tag(p, c):
    _stroke(p, c)
    _poly(p, [(3.5, 11), (11, 3.5), (20.5, 3.5), (20.5, 13), (13, 20.5), (3.5, 11)], True)
    _fill(p, c)
    p.drawEllipse(QRectF(15.1, 6.1, 3.0, 3.0))


def _eye(p, c):
    _stroke(p, c)
    path = QPainterPath(QPointF(2.5, 12))
    path.cubicTo(QPointF(6.5, 5.5), QPointF(17.5, 5.5), QPointF(21.5, 12))
    path.cubicTo(QPointF(17.5, 18.5), QPointF(6.5, 18.5), QPointF(2.5, 12))
    p.drawPath(path)
    p.drawEllipse(QRectF(9.4, 9.4, 5.2, 5.2))


def _palette(p, c):
    _stroke(p, c)
    path = QPainterPath(QPointF(12, 21))
    path.cubicTo(QPointF(5, 21), QPointF(2.5, 17), QPointF(2.5, 12))
    path.cubicTo(QPointF(2.5, 6.5), QPointF(7, 3), QPointF(12.5, 3))
    path.cubicTo(QPointF(18, 3), QPointF(21.5, 6.2), QPointF(21.5, 10.5))
    path.cubicTo(QPointF(21.5, 13.4), QPointF(19.2, 14.6), QPointF(16.6, 14.6))
    path.cubicTo(QPointF(14.2, 14.6), QPointF(13.2, 16), QPointF(14, 17.6))
    path.cubicTo(QPointF(14.7, 19.2), QPointF(13.8, 21), QPointF(12, 21))
    p.drawPath(path)
    _fill(p, c)
    for cx, cy in ((7.3, 9.6), (11.2, 7.0), (15.8, 8.4)):
        p.drawEllipse(QRectF(cx - 1.35, cy - 1.35, 2.7, 2.7))


def _contrast(p, c):
    _stroke(p, c)
    p.drawEllipse(QRectF(3.2, 3.2, 17.6, 17.6))
    path = QPainterPath(QPointF(12, 3.2))
    path.arcTo(QRectF(3.2, 3.2, 17.6, 17.6), 90, -180)
    path.closeSubpath()
    _fill(p, c)
    p.drawPath(path)


def _plus(p, c):
    _stroke(p, c, 2.1)
    _poly(p, [(12, 5), (12, 19)])
    _poly(p, [(5, 12), (19, 12)])


def _copy(p, c):
    _stroke(p, c)
    p.drawRoundedRect(QRectF(8.5, 3.5, 12, 12), 2.4, 2.4)
    _poly(p, [(15.5, 20.5), (3.5, 20.5), (3.5, 8.5)])


def _pencil(p, c):
    _stroke(p, c)
    _poly(p, [(3.5, 20.5), (4.4, 16.2), (16.3, 4.3), (19.7, 7.7), (7.8, 19.6), (3.5, 20.5)], True)
    _poly(p, [(14.2, 6.4), (17.6, 9.8)])


def _trash(p, c):
    _stroke(p, c)
    _poly(p, [(3.8, 6.3), (20.2, 6.3)])
    _poly(p, [(9.3, 6.3), (9.3, 3.8), (14.7, 3.8), (14.7, 6.3)])
    _poly(p, [(5.8, 6.3), (6.9, 20.2), (17.1, 20.2), (18.2, 6.3)])
    _poly(p, [(10.3, 10), (10.3, 16.6)])
    _poly(p, [(13.7, 10), (13.7, 16.6)])


def _check(p, c):
    _stroke(p, c, 2.2)
    _poly(p, [(4.5, 12.6), (9.8, 18), (19.5, 6.4)])


def _target(p, c):
    _stroke(p, c)
    p.drawEllipse(QRectF(5.2, 5.2, 13.6, 13.6))
    _fill(p, c)
    p.drawEllipse(QRectF(9.8, 9.8, 4.4, 4.4))
    _stroke(p, c)
    _poly(p, [(12, 1.8), (12, 4.6)])
    _poly(p, [(12, 19.4), (12, 22.2)])
    _poly(p, [(1.8, 12), (4.6, 12)])
    _poly(p, [(19.4, 12), (22.2, 12)])


def _layers(p, c):
    _stroke(p, c)
    _poly(p, [(12, 3), (21.5, 8), (12, 13), (2.5, 8)], True)
    _poly(p, [(4.6, 12), (12, 15.9), (19.4, 12)])
    _poly(p, [(4.6, 16), (12, 19.9), (19.4, 16)])


def _sliders(p, c):
    _stroke(p, c)
    for y in (7, 12, 17):
        _poly(p, [(3.5, y), (20.5, y)])
    _fill(p, c)
    for x, y in ((9, 7), (15.5, 12), (7, 17)):
        p.drawEllipse(QRectF(x - 2.3, y - 2.3, 4.6, 4.6))


def _code(p, c):
    _stroke(p, c)
    _poly(p, [(8.6, 7.2), (3.5, 12), (8.6, 16.8)])
    _poly(p, [(15.4, 7.2), (20.5, 12), (15.4, 16.8)])
    _poly(p, [(13.4, 4.4), (10.6, 19.6)])


def _chevron_down(p, c):
    _stroke(p, c, 2.1)
    _poly(p, [(6, 9.5), (12, 15.5), (18, 9.5)])


def _chevron_up(p, c):
    _stroke(p, c, 2.1)
    _poly(p, [(6, 14.5), (12, 8.5), (18, 14.5)])


def _split(p, c):
    """A block cut in two: the zones of a block."""
    _stroke(p, c, 1.7)
    _poly(p, [(3.5, 5), (10, 5), (10, 19), (3.5, 19)], True)
    _poly(p, [(14, 5), (20.5, 5), (20.5, 19), (14, 19)], True)
    _stroke(p, c, 1.3)
    for y in (3, 8, 13, 18):
        _poly(p, [(12, y), (12, y + 2.5)])


def _profile(p, c):
    """Axes and a curve: a value given cell by cell from a file."""
    _stroke(p, c, 1.6)
    _poly(p, [(4, 3.5), (4, 20), (20.5, 20)])
    _stroke(p, c, 2.0)
    _poly(p, [(6.5, 16.5), (9.5, 13), (12.5, 14.5), (15.5, 8.5), (19, 6)])


def _nozzle(p, c):
    """A de Laval nozzle in section, the flow through it: the special
    initialisations."""
    _stroke(p, c, 1.7)
    for side in (1, -1):
        path = QPainterPath(QPointF(2.5, 12 - side * 7))
        path.cubicTo(QPointF(7.5, 12 - side * 7), QPointF(8.5, 12 - side * 3.6),
                     QPointF(11.5, 12 - side * 3.6))
        path.cubicTo(QPointF(15, 12 - side * 3.6), QPointF(17.5, 12 - side * 8.5),
                     QPointF(21.5, 12 - side * 9.5))
        p.drawPath(path)
    _stroke(p, c, 1.5)
    _poly(p, [(6.5, 12), (17, 12)])
    _poly(p, [(14.5, 10), (17, 12), (14.5, 14)])


def _chevron_right(p, c):
    _stroke(p, c, 2.1)
    _poly(p, [(9.5, 6), (15.5, 12), (9.5, 18)])


def _circle(p, c):
    _stroke(p, c, 1.9)
    p.drawEllipse(QRectF(4.6, 4.6, 14.8, 14.8))


def _info(p, c):
    _stroke(p, c)
    p.drawEllipse(QRectF(3.4, 3.4, 17.2, 17.2))
    _poly(p, [(12, 11), (12, 17)])
    _fill(p, c)
    p.drawEllipse(QRectF(10.85, 6.6, 2.3, 2.3))


def _file(p, c):
    _stroke(p, c)
    _poly(p, [(14, 3), (6, 3), (6, 21), (18, 21), (18, 7)], True)
    _poly(p, [(14, 3), (14, 7), (18, 7)])


def _alert(p, c):
    _stroke(p, c)
    _poly(p, [(12, 4), (21, 19.5), (3, 19.5)], True)
    _poly(p, [(12, 9.5), (12, 14)])
    _fill(p, c)
    p.drawEllipse(QRectF(10.85, 15.6, 2.3, 2.3))


def _gear(p, c):
    _stroke(p, c, 1.8)
    p.drawEllipse(QRectF(9.2, 9.2, 5.6, 5.6))
    p.drawEllipse(QRectF(5.6, 5.6, 12.8, 12.8))
    _stroke(p, c, 2.6)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        _poly(p, [(12 + 6.6 * math.cos(a), 12 + 6.6 * math.sin(a)),
                  (12 + 9.4 * math.cos(a), 12 + 9.4 * math.sin(a))])


def _reset(p, c):
    _stroke(p, c)
    path = QPainterPath()
    path.arcMoveTo(QRectF(4.5, 4.5, 15, 15), 135)
    path.arcTo(QRectF(4.5, 4.5, 15, 15), 135, -290)
    p.drawPath(path)
    _poly(p, [(4.4, 4.6), (6.7, 6.7), (9.6, 5.8)])


def _type(p, c):
    _stroke(p, c)
    _poly(p, [(9.5, 19), (14.5, 5), (19.5, 19)])
    _poly(p, [(11.4, 14), (17.6, 14)])
    _poly(p, [(3, 19), (6, 11), (9, 19)])


def _thermo(p, c):
    """A thermometer: the initial state of the flow."""
    _stroke(p, c)
    stem = QPainterPath()
    stem.addRoundedRect(QRectF(9.6, 2.8, 4.8, 13.6), 2.4, 2.4)
    bulb = QPainterPath()
    bulb.addEllipse(QRectF(7.4, 13.2, 9.2, 9.2))
    p.drawPath(stem.united(bulb))
    _fill(p, c)
    p.drawEllipse(QRectF(9.7, 15.5, 4.6, 4.6))
    _stroke(p, c, 2.2)
    _poly(p, [(12, 9), (12, 16)])
    _stroke(p, c, 1.6)
    for y in (6, 9, 12):
        _poly(p, [(16.8, y), (19.2, y)])


DRAW = {
    "mesh": _mesh, "cube": _cube, "open": _open, "save": _save,
    "save-as": _save_as, "fit": _fit, "tag": _tag, "eye": _eye,
    "palette": _palette, "contrast": _contrast, "plus": _plus, "copy": _copy,
    "pencil": _pencil, "trash": _trash, "check": _check, "target": _target,
    "layers": _layers, "sliders": _sliders, "code": _code, "info": _info,
    "chevron-down": _chevron_down, "chevron-right": _chevron_right,
    "chevron-up": _chevron_up, "split": _split, "profile": _profile,
    "nozzle": _nozzle,
    "circle": _circle, "file": _file, "alert": _alert, "gear": _gear,
    "reset": _reset, "type": _type, "thermo": _thermo,
}


# ------------------------------------------------------------------ factory
def pixmap(name, color, size=18):
    """Artwork *name* tinted *color*, as a ``size`` x ``size`` pixmap."""
    px = QPixmap(int(size * _SCALE), int(size * _SCALE))
    px.setDevicePixelRatio(float(_SCALE))
    px.fill(Qt.GlobalColor.transparent)
    draw = DRAW.get(name)
    if draw is None:
        return px
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.scale(size / GRID, size / GRID)
    draw(p, color)
    p.end()
    return px


# QIcon is implicitly shared, so the same instance can be handed to any number
# of widgets.  Caching matters on large meshes, where the tree asks for one
# swatch per face.
_icon_cache = {}


def icon(name, color, size=18):
    key = ("i", name, color, size)
    if key not in _icon_cache:
        _icon_cache[key] = QIcon(pixmap(name, color, size))
    return _icon_cache[key]


def dot_pixmap(color, size=12, ring=None):
    """A filled colour swatch (optionally with a contrasting ring)."""
    px = QPixmap(int(size * _SCALE), int(size * _SCALE))
    px.setDevicePixelRatio(float(_SCALE))
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.scale(size / GRID, size / GRID)
    if ring:
        pen = QPen(QColor(ring), 2.0)
        p.setPen(pen)
    else:
        p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(QColor(color))
    p.drawEllipse(QRectF(4.5, 4.5, 15, 15))
    p.end()
    return px


def swatch_pixmap(color, width, height, border="#808080"):
    """A rounded colour sample of *width* x *height*, outlined so a colour
    close to its background still shows its edge."""
    px = QPixmap(int(width * _SCALE), int(height * _SCALE))
    px.setDevicePixelRatio(float(_SCALE))
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setPen(QPen(QColor(border), 1.0))
    p.setBrush(QColor(color))
    radius = min(width, height) * 0.22
    p.drawRoundedRect(QRectF(0.5, 0.5, width - 1, height - 1), radius, radius)
    p.end()
    return px


def dot(color, size=12, ring=None):
    key = ("d", color, size, ring)
    if key not in _icon_cache:
        _icon_cache[key] = QIcon(dot_pixmap(color, size, ring))
    return _icon_cache[key]


def app_icon(accent, bg="#0b1017", size=64):
    """The application icon: :data:`APP_ICON_FILE`, or -- when the file is
    missing -- the mesh glyph in *accent* on a rounded *bg* tile."""
    if os.path.isfile(APP_ICON_FILE):
        icon = QIcon(APP_ICON_FILE)
        if not icon.isNull():
            return icon
    px = QPixmap(size * _SCALE, size * _SCALE)
    px.setDevicePixelRatio(float(_SCALE))
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.scale(size / GRID, size / GRID)
    _fill(p, bg)
    p.drawRoundedRect(QRectF(0.5, 0.5, 23, 23), 5.5, 5.5)
    _mesh(p, accent)
    p.end()
    return QIcon(px)
