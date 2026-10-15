"""Colour themes and the Qt stylesheet for the BCB GUI.

A theme is declared as a short *seed* palette -- background, surface, text, an
accent and the semantic colours -- and :func:`get_theme` derives the ~40 tokens
the interface actually uses (borders, hover fills, muted text, soft accent
washes, scrollbars, ...) by mixing those seeds.  Themes therefore stay small to
write and automatically consistent with each other.

The same token dict drives the Qt stylesheet (:func:`build_stylesheet`) and the
3-D viewport (:meth:`bcbgui.viewport.MeshViewport.apply_theme`), so switching a
theme restyles the whole application at once.

Checkbox indicators, combo arrows and tree branch markers are painted at runtime
into a temporary directory (:func:`_assets`) and referenced from the stylesheet,
which keeps those controls on-theme instead of falling back to the platform's
default widgets.  If anything there fails, the stylesheet is still emitted and
Qt simply draws its native indicators.
"""

from __future__ import annotations

import os
import tempfile

# Keys consumed by the viewport (everything else styles the Qt widgets).
VIEWPORT_KEYS = (
    "viewport_bg", "viewport_bg2", "edge", "unassigned", "context",
    "highlight_edge", "label_text", "label_shape",
)

DEFAULT_THEME = "Dark Blue"


# --------------------------------------------------------------- colour maths
def _rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(c)))) for c in rgb)


def _mix(a, b, t):
    """*t* parts of colour *a* over colour *b* (t in 0..1)."""
    ra, rb = _rgb(a), _rgb(b)
    return _hex([ra[i] * t + rb[i] * (1.0 - t) for i in range(3)])


def _lum(c):
    r, g, b = (v / 255.0 for v in _rgb(c))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _readable(c):
    """Black or white, whichever reads better on *c*."""
    return "#0c1116" if _lum(c) > 0.55 else "#ffffff"


# ------------------------------------------------------------------- palettes
# Seeds only: everything else is derived in _derive().
THEMES = {
    "Dark Blue": {
        "mode": "dark",
        "bg": "#0b1118", "surface": "#141d28", "text": "#e8f0f8",
        "accent": "#3d9ae0",
        "danger": "#e2596a", "success": "#49c08a", "warning": "#e0a54a",
        "viewport_bg": "#080d13", "viewport_bg2": "#16222f",
        "unassigned": "#8295a9", "context": "#c9d5e1", "highlight_edge": "#ffd23f",
    },
    "Midnight": {
        "mode": "dark",
        "bg": "#07080c", "surface": "#11131a", "text": "#e9eaf2",
        "accent": "#7c6cf0",
        "danger": "#ef5f7a", "success": "#3fc99a", "warning": "#e8b14c",
        "viewport_bg": "#05060a", "viewport_bg2": "#141628",
        "unassigned": "#8a8c9e", "context": "#cdcedd", "highlight_edge": "#ffd66b",
    },
    "Graphite": {
        "mode": "dark",
        "bg": "#17181b", "surface": "#212328", "text": "#eceef1",
        "accent": "#38a39a",
        "danger": "#df5f66", "success": "#54bd86", "warning": "#d9a450",
        "viewport_bg": "#121316", "viewport_bg2": "#232529",
        "unassigned": "#8d9299", "context": "#d2d5d9", "highlight_edge": "#ffcf40",
    },
    "Nord": {
        "mode": "dark",
        "bg": "#262c38", "surface": "#333b4a", "text": "#eceff4",
        "accent": "#88c0d0",
        "danger": "#bf616a", "success": "#a3be8c", "warning": "#ebcb8b",
        "viewport_bg": "#232834", "viewport_bg2": "#3b4252",
        "unassigned": "#7b88a1", "context": "#d8dee9", "highlight_edge": "#ebcb8b",
    },
    "Light": {
        "mode": "light",
        "bg": "#eef1f6", "surface": "#ffffff", "text": "#16202b",
        "accent": "#2f7fd0",
        "danger": "#cf4436", "success": "#2e9e6b", "warning": "#c07c17",
        "viewport_bg": "#e9edf3", "viewport_bg2": "#fbfcfe",
        "unassigned": "#9fb0c0", "context": "#8a97a5", "highlight_edge": "#e08a00",
    },
}

_derived_cache = {}


def _derive(name, s):
    dark = s.get("mode", "dark") == "dark"
    bg, surf, text, accent = s["bg"], s["surface"], s["text"], s["accent"]
    danger, success, warning = s["danger"], s["success"], s["warning"]
    # "up" is the direction that reads as raised/hovered: toward the text
    # colour, so borders and hovers keep the palette's hue in both modes.
    up = text

    t = dict(s)
    t["_name"] = name
    t.update({
        "bg_alt":        _mix(surf, bg, 0.45),
        "surface":       surf,
        "surface_alt":   _mix(bg, surf, 0.55) if dark else _mix(bg, surf, 0.35),
        "surface_hi":    _mix(up, surf, 0.07),
        "border":        _mix(up, surf, 0.13 if dark else 0.10),
        "border_strong": _mix(up, surf, 0.26 if dark else 0.20),
        "text":          text,
        "text_dim":      _mix(text, bg, 0.72),
        "muted":         _mix(text, bg, 0.50),
        "faint":         _mix(text, bg, 0.34),
        "accent":        accent,
        "accent_hi":     _mix("#ffffff", accent, 0.16) if dark else _mix("#ffffff", accent, 0.10),
        "accent_press":  _mix("#000000", accent, 0.14),
        "accent_soft":   _mix(accent, surf, 0.22),
        "accent_wash":   _mix(accent, surf, 0.12),
        "accent_line":   _mix(accent, surf, 0.55),
        "on_accent":     _readable(accent),
        "danger":        danger,
        "danger_soft":   _mix(danger, surf, 0.18),
        "danger_line":   _mix(danger, surf, 0.50),
        "danger_text":   _mix(danger, text, 0.65) if dark else danger,
        "on_danger":     _readable(danger),
        "success":       success,
        "warning":       warning,
        "header_bg":     _mix(surf, bg, 0.55),
        "preview_bg":    _mix(bg, surf, 0.75) if dark else "#fbfcfe",
        "preview_text":  _mix(text, bg, 0.88),
        "tooltip_bg":    _mix(surf, up, 0.92),
        "scroll":        _mix(up, surf, 0.20),
        "scroll_hi":     _mix(up, surf, 0.34),
        "shadow":        _mix("#000000", bg, 0.55),
    })
    # Viewport tokens.
    vbg = s["viewport_bg"]
    t.setdefault("viewport_bg2", _mix(up, vbg, 0.08))
    # Mesh edges: lift them off a dark viewport, darken them on a light one.
    t["edge"] = _mix(t["unassigned"], vbg, 0.55) if dark \
        else _mix(t["unassigned"], text, 0.55)
    t["label_text"] = _readable(_mix(surf, bg, 0.5))
    t["label_shape"] = _mix(surf, bg, 0.35)
    # INI preview syntax colours.
    t["syn_section"] = accent
    t["syn_key"] = _mix(success, text, 0.78) if dark else _mix(success, text, 0.85)
    t["syn_value"] = _mix(text, bg, 0.85)
    t["syn_comment"] = _mix(text, bg, 0.42)
    return t


def get_theme(name):
    if name not in THEMES:
        name = DEFAULT_THEME
    if name not in _derived_cache:
        _derived_cache[name] = _derive(name, THEMES[name])
    return _derived_cache[name]


# ------------------------------------------------------- generated indicators
_asset_root = None       # kept alive for the process lifetime
_asset_cache = {}


def _asset_path(theme_name):
    global _asset_root
    if _asset_root is None:
        _asset_root = tempfile.TemporaryDirectory(prefix="bcbgui-theme-")
    d = os.path.join(_asset_root.name, theme_name.replace(" ", "_"))
    os.makedirs(d, exist_ok=True)
    return d


def _assets(t):
    """Paint the checkbox / arrow / branch artwork for theme *t*.

    Returns a dict of stylesheet-ready ``url(...)`` paths, or empty strings if
    no QGuiApplication is available (the stylesheet then keeps Qt's own).
    """
    name = t.get("_name", "theme")
    if name in _asset_cache:
        return _asset_cache[name]
    blank = {k: "" for k in ("box_off", "box_on", "box_hover", "box_off_dis",
                             "arrow_down", "branch_open", "branch_closed")}
    try:
        from PyQt6.QtCore import QRectF, Qt
        from PyQt6.QtGui import QColor, QPainter, QPainterPath, QPen, QPixmap
        from . import icons
    except Exception:                                   # pragma: no cover
        return blank

    def box(path, fill, line, tick=None, lw=1.6):
        px = QPixmap(36, 36)
        px.fill(Qt.GlobalColor.transparent)
        p = QPainter(px)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setPen(QPen(QColor(line), lw * 2))
        p.setBrush(QColor(fill))
        p.drawRoundedRect(QRectF(3, 3, 30, 30), 9, 9)
        if tick:
            pen = QPen(QColor(tick), 4.2)
            pen.setCapStyle(Qt.PenCapStyle.RoundCap)
            pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            p.setPen(pen)
            p.setBrush(Qt.BrushStyle.NoBrush)
            tk = QPainterPath()
            tk.moveTo(10.5, 18.5)
            tk.lineTo(16, 24)
            tk.lineTo(25.5, 12.5)
            p.drawPath(tk)
        p.end()
        px.save(path, "PNG")

    try:
        d = _asset_path(name)
        out = {}
        files = {
            "box_off": (t["surface_alt"], t["border_strong"], None),
            "box_hover": (t["surface_hi"], t["accent_line"], None),
            "box_on": (t["accent"], t["accent"], t["on_accent"]),
            "box_off_dis": (t["bg_alt"], t["border"], None),
        }
        for key, (fill, line, tick) in files.items():
            f = os.path.join(d, key + ".png")
            box(f, fill, line, tick)
            out[key] = f.replace("\\", "/")
        for key, iname, col in (("arrow_down", "chevron-down", t["muted"]),
                                ("branch_open", "chevron-down", t["faint"]),
                                ("branch_closed", "chevron-right", t["faint"])):
            f = os.path.join(d, key + ".png")
            icons.pixmap(iname, col, 16).save(f, "PNG")
            out[key] = f.replace("\\", "/")
    except Exception:                                   # pragma: no cover
        return blank
    _asset_cache[name] = out
    return out


# ------------------------------------------------------------------ stylesheet
_FONT = ('"Inter", "SF Pro Text", "Segoe UI", "Ubuntu", "Cantarell", '
         '"Noto Sans", "DejaVu Sans", sans-serif')
_MONO = ('"JetBrains Mono", "Fira Code", "SF Mono", "Menlo", "Consolas", '
         '"DejaVu Sans Mono", monospace')

_TEMPLATE = """
* { outline: 0; }
QWidget { color: %(text)s; font-family: %(font)s; font-size: 10.5pt; }
#Root { background-color: %(bg)s; }
QDialog, QMessageBox, QInputDialog, QFileDialog { background-color: %(bg_alt)s; }
QMessageBox QLabel, QInputDialog QLabel { color: %(text)s; }
QMessageBox QPushButton, QInputDialog QPushButton { min-width: 76px; }
QMessageBox QPushButton, QDialogButtonBox QPushButton { icon-size: 0px; }
QDialogButtonBox QPushButton { min-width: 88px; }

/* ------------------------------------------------------------- chrome bars */
#HeaderBar, #StatusStrip {
    background-color: %(bg_alt)s; border: 1px solid %(border)s; border-radius: 12px; }
#HeaderBar { padding: 2px; }
#Brand { color: %(text)s; font-size: 12.5pt; font-weight: 800; letter-spacing: 0.5px; }
#BrandSub { color: %(accent)s; font-size: 8pt; font-weight: 800; letter-spacing: 2.4px; }
#VDivider { background-color: %(border)s; min-width: 1px; max-width: 1px; border: none; }
#HDivider { background-color: %(border)s; min-height: 1px; max-height: 1px; border: none; }

/* ---------------------------------------------------------------- buttons */
QPushButton {
    background-color: %(surface)s; border: 1px solid %(border)s; border-radius: 9px;
    padding: 6px 12px; min-height: 24px; font-weight: 600; color: %(text_dim)s; }
QPushButton:hover { background-color: %(surface_hi)s; border-color: %(border_strong)s;
    color: %(text)s; }
QPushButton:pressed { background-color: %(bg_alt)s; }
QPushButton:disabled { color: %(faint)s; background-color: %(bg_alt)s;
    border-color: %(border)s; }
QPushButton[role="primary"] { background-color: %(accent)s; border-color: %(accent)s;
    color: %(on_accent)s; }
QPushButton[role="primary"]:hover { background-color: %(accent_hi)s;
    border-color: %(accent_hi)s; color: %(on_accent)s; }
QPushButton[role="primary"]:pressed { background-color: %(accent_press)s; }
QPushButton[role="danger"] { background-color: %(danger_soft)s;
    border-color: %(danger_line)s; color: %(danger_text)s; }
QPushButton[role="danger"]:hover { background-color: %(danger)s; color: %(on_danger)s;
    border-color: %(danger)s; }
QPushButton[role="ghost"] { background-color: transparent; border-color: transparent;
    color: %(text_dim)s; }
QPushButton[role="ghost"]:hover { background-color: %(surface_hi)s; color: %(text)s; }
QPushButton[role="chip"] { border-radius: 14px; padding: 6px 13px; text-align: left; }
QPushButton[role="chip"]:hover { border-color: %(accent_line)s; }
QPushButton[role="toggle"] { border-radius: 14px; padding: 5px 13px; color: %(muted)s; }
QPushButton[role="toggle"]:checked { background-color: %(accent_soft)s;
    border-color: %(accent_line)s; color: %(text)s; }
QPushButton[role="toggle"]:checked:hover { background-color: %(accent_soft)s;
    border-color: %(accent)s; }
QPushButton[seg="left"] { border-top-right-radius: 0; border-bottom-right-radius: 0;
    border-right-color: transparent; padding: 6px 10px; }
QPushButton[seg="mid"] { border-radius: 0; border-right-color: transparent;
    padding: 6px 10px; }
QPushButton[seg="right"] { border-top-left-radius: 0; border-bottom-left-radius: 0;
    padding: 6px 10px; }

/* ----------------------------------------------------------------- inputs */
QLineEdit, QComboBox, QAbstractSpinBox {
    background-color: %(surface_alt)s; border: 1px solid %(border)s; border-radius: 9px;
    padding: 5px 9px; min-height: 24px; color: %(text)s;
    selection-background-color: %(accent)s; selection-color: %(on_accent)s; }
QLineEdit:hover, QComboBox:hover { border-color: %(border_strong)s; }
QLineEdit:focus, QComboBox:focus, QComboBox:on { border-color: %(accent)s; }
QComboBox::drop-down { border: none; width: 24px; }
QComboBox::down-arrow { image: url(%(arrow_down)s); width: 13px; height: 13px; }
QComboBox QAbstractItemView {
    background-color: %(surface)s; border: 1px solid %(border_strong)s;
    border-radius: 9px; padding: 4px; outline: none;
    selection-background-color: %(accent_soft)s; selection-color: %(text)s; }

/* -------------------------------------------------------------- workflow */
#StageRail { background-color: %(bg_alt)s; border: 1px solid %(border)s;
    border-radius: 12px; }
QPushButton[role="stage"] { background-color: transparent;
    border: 1px solid transparent; border-radius: 9px; text-align: left;
    padding: 8px 10px; color: %(muted)s; font-weight: 700; }
QPushButton[role="stage"]:hover { background-color: %(surface_hi)s;
    color: %(text)s; }
QPushButton[role="stage"]:checked { background-color: %(accent_soft)s;
    border-color: %(accent_line)s; color: %(text)s; }
#Tile { background-color: %(surface_alt)s; border: 1px solid %(border)s;
    border-radius: 10px; min-width: 150px; }
#TileValue { font-size: 24pt; font-weight: 800; color: %(text)s; }
#PhaseRow { background-color: transparent; }

/* ------------------------------------------------------------------ menus */
QMenu { background-color: %(surface)s; border: 1px solid %(border_strong)s;
    border-radius: 10px; padding: 6px; }
QMenu::item { padding: 7px 16px; border-radius: 7px; color: %(text_dim)s; }
QMenu::item:selected { background-color: %(accent_soft)s; color: %(text)s; }
QMenu::separator { height: 1px; background: %(border)s; margin: 5px 8px; }
QPushButton::menu-indicator { subcontrol-origin: padding;
    subcontrol-position: center right; right: 8px; width: 12px; }

/* ------------------------------------------------------------ cards/groups */
QGroupBox {
    background-color: %(surface)s; border: 1px solid %(border)s; border-radius: 12px;
    margin-top: 15px; padding: 14px 10px 10px 10px; font-weight: 700; }
QGroupBox::title {
    subcontrol-origin: margin; subcontrol-position: top left; left: 13px;
    padding: 0 5px; color: %(muted)s; font-size: 8pt; font-weight: 800;
    letter-spacing: 1.6px; }
#Card { background-color: %(surface)s; border: 1px solid %(border)s;
    border-radius: 12px; }
#SelCard { background-color: %(accent_wash)s; border: 1px solid %(accent_line)s;
    border-radius: 12px; }
#ViewportFrame { background-color: %(viewport_bg)s; border: 1px solid %(border)s;
    border-radius: 12px; }

/* ------------------------------------------------------- item views/tables */
QTreeWidget, QTreeView, QListWidget, QListView, QTableWidget, QTableView {
    background-color: %(surface_alt)s; border: 1px solid %(border)s;
    border-radius: 10px; outline: none; color: %(text)s;
    alternate-background-color: %(surface_alt)s;
    selection-background-color: %(accent_soft)s; selection-color: %(text)s; }
QTreeView::item, QListView::item { padding: 5px 3px; border: none; }
QTableView::item { padding: 3px 5px; }
QTreeView::item:hover, QListView::item:hover, QTableView::item:hover {
    background-color: %(surface_hi)s; }
QTreeView::item:selected, QListView::item:selected, QTableView::item:selected {
    background-color: %(accent_soft)s; color: %(text)s; }
QTreeView::branch:has-children:!has-siblings:closed,
QTreeView::branch:closed:has-children:has-siblings { image: url(%(branch_closed)s); }
QTreeView::branch:open:has-children:!has-siblings,
QTreeView::branch:open:has-children:has-siblings { image: url(%(branch_open)s); }
QHeaderView { background-color: transparent; }
QHeaderView::section {
    background-color: %(header_bg)s; color: %(muted)s; padding: 7px 8px;
    border: none; border-bottom: 1px solid %(border)s;
    border-right: 1px solid %(border)s; font-size: 8pt; font-weight: 800;
    letter-spacing: 1.2px; }
QHeaderView::section:last { border-right: none; }
QTableView { gridline-color: %(border)s; }
QTableCornerButton::section { background-color: %(header_bg)s; border: none; }

/* ------------------------------------------------------------- indicators */
QCheckBox { spacing: 8px; color: %(text_dim)s; }
QCheckBox::indicator, QTreeView::indicator, QGroupBox::indicator,
QListView::indicator { width: 17px; height: 17px; }
QCheckBox::indicator:unchecked, QTreeView::indicator:unchecked,
QListView::indicator:unchecked { image: url(%(box_off)s); }
QCheckBox::indicator:unchecked:hover, QTreeView::indicator:unchecked:hover,
QListView::indicator:unchecked:hover { image: url(%(box_hover)s); }
QCheckBox::indicator:checked, QTreeView::indicator:checked,
QListView::indicator:checked { image: url(%(box_on)s); }
QCheckBox::indicator:disabled, QTreeView::indicator:disabled {
    image: url(%(box_off_dis)s); }

/* ------------------------------------------------------------------- tabs */
QTabWidget::pane { border: none; border-top: 1px solid %(border)s; top: -1px; }
QTabBar { qproperty-drawBase: 0; background: transparent; }
QTabBar::tab {
    background: transparent; color: %(muted)s; border: none;
    border-bottom: 2px solid transparent; padding: 9px 13px; margin-right: 3px;
    font-weight: 700; font-size: 10pt; }
QTabBar::tab:hover { color: %(text)s; }
QTabBar::tab:selected { color: %(text)s; border-bottom: 2px solid %(accent)s; }

/* ---------------------------------------------------------------- preview */
QPlainTextEdit {
    background-color: %(preview_bg)s; border: 1px solid %(border)s;
    border-radius: 10px; padding: 8px; font-family: %(mono)s; font-size: 9.5pt;
    color: %(preview_text)s; selection-background-color: %(accent)s;
    selection-color: %(on_accent)s; }

/* ------------------------------------------------------------- scrollbars */
QScrollBar:vertical { background: transparent; width: 12px; margin: 3px; }
QScrollBar:horizontal { background: transparent; height: 12px; margin: 3px; }
QScrollBar::handle:vertical { background: %(scroll)s; border-radius: 4px;
    min-height: 30px; }
QScrollBar::handle:horizontal { background: %(scroll)s; border-radius: 4px;
    min-width: 30px; }
QScrollBar::handle:hover { background: %(scroll_hi)s; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; border: none; }
QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }

/* -------------------------------------------------------------- splitters */
QScrollArea { background: transparent; border: none; }
QSplitter::handle { background-color: transparent; }
QSplitter::handle:horizontal { width: 9px; }
QSplitter::handle:vertical { height: 9px; }
QSplitter::handle:hover { background-color: %(accent_line)s; }

/* ------------------------------------------------------------------- misc */
QProgressBar { background-color: %(surface_alt)s; border: 1px solid %(border)s;
    border-radius: 6px; max-height: 8px; min-height: 8px; text-align: center; }
QProgressBar::chunk { background-color: %(accent)s; border-radius: 5px; }
QProgressBar[state="done"]::chunk { background-color: %(success)s; }
QToolTip { background-color: %(tooltip_bg)s; color: %(text)s;
    border: 1px solid %(border_strong)s; border-radius: 7px; padding: 5px 8px; }
QLabel[role="muted"] { color: %(muted)s; }
QLabel[role="hint"] { color: %(muted)s; font-size: 9.5pt; }
QLabel[role="title"] { color: %(text)s; font-size: 11.5pt; font-weight: 700; }
QLabel[role="section"] { color: %(muted)s; font-size: 8pt; font-weight: 800;
    letter-spacing: 1.6px; }
QLabel[role="value"] { color: %(text)s; font-weight: 700; }
QLabel#Badge { background-color: %(surface_hi)s; color: %(muted)s;
    border: 1px solid %(border)s; border-radius: 9px; padding: 1px 8px;
    font-size: 8.5pt; font-weight: 700; }
"""


def build_stylesheet(tokens):
    """Qt stylesheet for a derived token dict (see :func:`get_theme`)."""
    data = dict(tokens)
    data.setdefault("_name", DEFAULT_THEME)
    data["font"] = _FONT
    data["mono"] = _MONO
    data.update(_assets(data))
    return _TEMPLATE % data


def build_palette(tokens):
    """QPalette matching *tokens*, so dialogs and native-drawn bits agree
    with the stylesheet."""
    from PyQt6.QtGui import QColor, QPalette

    c = QColor
    g = QPalette.ColorGroup
    r = QPalette.ColorRole
    p = QPalette()
    p.setColor(r.Window, c(tokens["bg"]))
    p.setColor(r.WindowText, c(tokens["text"]))
    p.setColor(r.Base, c(tokens["surface_alt"]))
    p.setColor(r.AlternateBase, c(tokens["surface"]))
    p.setColor(r.Text, c(tokens["text"]))
    p.setColor(r.PlaceholderText, c(tokens["muted"]))
    p.setColor(r.Button, c(tokens["surface"]))
    p.setColor(r.ButtonText, c(tokens["text"]))
    p.setColor(r.BrightText, c(tokens["danger"]))
    p.setColor(r.Highlight, c(tokens["accent"]))
    p.setColor(r.HighlightedText, c(tokens["on_accent"]))
    p.setColor(r.ToolTipBase, c(tokens["tooltip_bg"]))
    p.setColor(r.ToolTipText, c(tokens["text"]))
    p.setColor(r.Link, c(tokens["accent"]))
    p.setColor(r.Mid, c(tokens["border"]))
    p.setColor(r.Dark, c(tokens["bg_alt"]))
    for role in (r.WindowText, r.Text, r.ButtonText):
        p.setColor(g.Disabled, role, c(tokens["faint"]))
    return p
