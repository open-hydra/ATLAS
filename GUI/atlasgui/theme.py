"""Colour themes and the Qt stylesheet for the BCB GUI.

A theme is declared as a short *seed* palette -- background, surface, text, an
accent and the semantic colours -- and :func:`get_theme` derives the ~40 tokens
the interface actually uses (borders, hover fills, muted text, soft accent
washes, scrollbars, ...) by mixing those seeds.  Themes therefore stay small to
write and automatically consistent with each other.

The same token dict drives the Qt stylesheet (:func:`build_stylesheet`) and the
3-D viewport (:meth:`bcbgui.viewport.MeshViewport.apply_theme`), so switching a
theme restyles the whole application at once.

The built-in themes (:data:`THEMES`) are fixed.  A user's theme is a *spec*
(:func:`theme_spec`): the seeds, plus *overrides* -- derived tokens the theme
sets itself instead of letting them follow the seeds.  The specs are stored by
:mod:`atlasgui.preferences` and registered here (:func:`set_custom_themes`);
:data:`SEED_GROUPS` and :data:`TOKEN_GROUPS` say what the theme editor offers.

Checkbox indicators, combo arrows and tree branch markers are painted at runtime
into a temporary directory (:func:`_assets`) and referenced from the stylesheet,
which keeps those controls on-theme instead of falling back to the platform's
default widgets.  If anything there fails, the stylesheet is still emitted and
Qt simply draws its native indicators.
"""

from __future__ import annotations

import hashlib
import os
import re
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


_INK = "#0c1116"         # the "black" of text on a light fill


def _on(*fills):
    """Black or white, whichever reads better on every colour of *fills*
    (WCAG contrast: a mid-tone accent can want black where its luminance
    alone would suggest white)."""
    return max((_INK, "#ffffff"),
               key=lambda ink: min(contrast(ink, fill) for fill in fills))


def _legible(colour, toward, against, ratio=4.5):
    """*colour*, moved toward *toward* in steps of 2 % just far enough to
    read at *ratio* (WCAG) against every colour of *against*.

    A derived shade keeps its intended look wherever it already reads and is
    lifted only where a palette would make it too faint: 4.5 : 1 is AA for
    text, 3 : 1 for the edges of shapes.
    """
    for step in range(51):
        candidate = _mix(toward, colour, step / 50.0)
        if all(contrast(candidate, a) >= ratio for a in against):
            return candidate
    return toward


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
        "accent": "#2c77c4",
        "danger": "#cf4436", "success": "#2e9e6b", "warning": "#c07c17",
        "viewport_bg": "#e9edf3", "viewport_bg2": "#fbfcfe",
        "unassigned": "#9fb0c0", "context": "#8a97a5", "highlight_edge": "#e08a00",
    },
}

# What the theme editor shows: the seeds first (every other colour follows
# them), then the derived tokens a theme may set itself, by group.
SEED_GROUPS = [
    ("Interface", [
        ("bg", "Window background"), ("surface", "Panels and cards"),
        ("text", "Text"), ("accent", "Accent")]),
    ("Status", [
        ("danger", "Errors and deletion"), ("warning", "Warnings"),
        ("success", "Success")]),
    ("3-D view", [
        ("viewport_bg", "Background, bottom"), ("viewport_bg2", "Background, top"),
        ("unassigned", "Unassigned faces"), ("context", "Context planes"),
        ("highlight_edge", "Selected face outline")]),
]
TOKEN_GROUPS = [
    ("Surfaces", [
        ("bg_alt", "Header, rail and status bar"),
        ("surface_alt", "Inputs, lists and tables"), ("surface_hi", "Hover"),
        ("header_bg", "Table headers"), ("tooltip_bg", "Tooltips")]),
    ("Lines", [
        ("border", "Borders"), ("border_strong", "Strong borders"),
        ("scroll", "Scroll bars")]),
    ("Text", [
        ("text_dim", "Button text"), ("muted", "Labels and hints"),
        ("faint", "Disabled text"), ("on_accent", "Text on the accent")]),
    ("Accent", [
        ("accent_text", "Accent as text"), ("accent_hi", "Accent, hovered"),
        ("accent_soft", "Selection"), ("accent_line", "Selection outline")]),
    ("Status text", [
        ("danger_text", "Errors, delete buttons"), ("warning_text", "Warnings"),
        ("success_text", "Success"), ("on_danger", "Text on the error colour")]),
    ("3-D view", [
        ("edge", "Mesh edges"), ("label_text", "Label text"),
        ("label_shape", "Label background")]),
    ("INI preview", [
        ("preview_bg", "Background"), ("syn_section", "Sections"),
        ("syn_key", "Keys"), ("syn_value", "Values"),
        ("syn_comment", "Comments")]),
]
SEED_KEYS = [key for _group, rows in SEED_GROUPS for key, _label in rows]
TOKEN_KEYS = [key for _group, rows in TOKEN_GROUPS for key, _label in rows]
MODES = ("dark", "light")

_derived_cache = {}
_custom = {}             # name -> spec of the user's themes


def _derive(name, s):
    dark = s.get("mode", "dark") == "dark"
    bg, surf, text, accent = s["bg"], s["surface"], s["text"], s["accent"]
    danger, success, warning = s["danger"], s["success"], s["warning"]
    # "up" is the direction that reads as raised/hovered: toward the text
    # colour, so borders and hovers keep the palette's hue in both modes.
    up = text

    t = dict(s)
    t["_name"] = name
    # Surfaces and fills first: the text colours are checked against them.
    t.update({
        "bg_alt":        _mix(surf, bg, 0.45),
        "surface":       surf,
        "surface_alt":   _mix(bg, surf, 0.55) if dark else _mix(bg, surf, 0.35),
        "surface_hi":    _mix(up, surf, 0.07),
        "border":        _mix(up, surf, 0.13 if dark else 0.10),
        "border_strong": _mix(up, surf, 0.26 if dark else 0.20),
        "text":          text,
        "accent":        accent,
        # Hovered: lighter on a dark theme, darker on a light one, so the
        # text on the accent keeps its contrast either way.
        "accent_hi":     _mix("#ffffff", accent, 0.16) if dark else _mix("#000000", accent, 0.10),
        "accent_press":  _mix("#000000", accent, 0.14),
        "accent_soft":   _mix(accent, surf, 0.22),
        "accent_wash":   _mix(accent, surf, 0.12),
        "accent_line":   _mix(accent, surf, 0.55),
        "danger":        danger,
        "danger_soft":   _mix(danger, surf, 0.18),
        "danger_line":   _mix(danger, surf, 0.50),
        "success":       success,
        "warning":       warning,
        "header_bg":     _mix(surf, bg, 0.55),
        "preview_bg":    _mix(bg, surf, 0.75) if dark else "#fbfcfe",
        "tooltip_bg":    _mix(surf, up, 0.92),
        "scroll":        _mix(up, surf, 0.20),
        "scroll_hi":     _mix(up, surf, 0.34),
        "shadow":        _mix("#000000", bg, 0.55),
    })
    # Text, on every surface it is drawn on (the badge and a hovered row are
    # the lightest in a dark theme).  Disabled text is exempt, as in WCAG.
    panels = [surf, bg, t["bg_alt"], t["surface_alt"], t["header_bg"],
              t["surface_hi"]]
    statuses = [surf, t["surface_alt"]]
    t.update({
        "text_dim":      _legible(_mix(text, bg, 0.72), text,
                                  [surf, t["surface_hi"], t["bg_alt"]]),
        "muted":         _legible(_mix(text, bg, 0.50), text, panels),
        "faint":         _mix(text, bg, 0.34),
        "on_accent":     _on(accent, t["accent_hi"]),
        "accent_text":   _legible(accent, text,
                                  [t["bg_alt"], surf, t["preview_bg"]]),
        "danger_text":   _legible(_mix(danger, text, 0.65) if dark else danger,
                                  text, [t["danger_soft"]] + statuses),
        "on_danger":     _on(danger),
        "success_text":  _legible(success, text, statuses),
        "warning_text":  _legible(warning, text, statuses),
        "preview_text":  _legible(_mix(text, bg, 0.88), text, [t["preview_bg"]]),
    })
    # Viewport tokens.
    vbg = s["viewport_bg"]
    t.setdefault("viewport_bg2", _mix(up, vbg, 0.08))
    # Mesh edges: lift them off a dark viewport, darken them on a light one,
    # and keep them at 3 : 1 against both ends of the background.
    edge = _mix(t["unassigned"], vbg, 0.55) if dark \
        else _mix(t["unassigned"], text, 0.55)
    t["edge"] = _legible(edge, text, [vbg, t["viewport_bg2"]], 3.0)
    t["label_shape"] = _mix(surf, bg, 0.35)
    t["label_text"] = _on(t["label_shape"])
    # INI preview syntax colours.
    preview = [t["preview_bg"]]
    t["syn_section"] = t["accent_text"]
    t["syn_key"] = _legible(_mix(success, text, 0.78) if dark
                            else _mix(success, text, 0.85), text, preview)
    t["syn_value"] = _legible(_mix(text, bg, 0.85), text, preview)
    t["syn_comment"] = _legible(_mix(text, bg, 0.42), text, preview)
    return t


def derive(spec):
    """The tokens of a theme *spec*: derived from its seeds, then its overrides."""
    tokens = _derive(spec["name"], spec["seeds"])
    tokens.update(spec.get("overrides", {}))
    return tokens


def get_theme(name):
    if name not in theme_names():
        name = DEFAULT_THEME
    if name not in _derived_cache:
        _derived_cache[name] = derive(theme_spec(name))
    return _derived_cache[name]


# --------------------------------------------------------------- the registry
def theme_names():
    """The built-in themes, then the user's."""
    return list(THEMES) + [n for n in _custom if n not in THEMES]


def is_builtin(name):
    return name in THEMES


def theme_spec(name):
    """A copy of theme *name* as a spec: ``{name, base, seeds, overrides}``,
    *base* being the built-in theme it started from."""
    if name in THEMES:
        return {"name": name, "base": name, "seeds": dict(THEMES[name]),
                "overrides": {}}
    spec = _custom[name]
    return {"name": name, "base": spec.get("base", DEFAULT_THEME),
            "seeds": dict(spec["seeds"]),
            "overrides": dict(spec.get("overrides", {}))}


def custom_themes():
    """Copies of the user's theme specs, by name."""
    return {name: theme_spec(name) for name in _custom}


def set_custom_themes(specs):
    """Register the user's themes (replacing the previous set)."""
    _custom.clear()
    for name, spec in specs.items():
        if name not in THEMES:
            _custom[name] = spec
    _derived_cache.clear()


def spec_from_data(data):
    """A theme spec from what a theme file holds, checked and completed.

    A seed the data lacks is taken from its base theme, a colour that does
    not parse is an error, and an override of a token the editor does not
    know is dropped.  Raises ValueError with what is wrong.
    """
    if not isinstance(data, dict):
        raise ValueError("not a theme: the file holds no table of colours")
    name = str(data.get("name", "")).strip()
    if not name:
        raise ValueError("the theme has no name")
    base = data.get("base") if data.get("base") in THEMES else DEFAULT_THEME
    seeds = dict(THEMES[base])
    for key, value in dict(data.get("seeds") or {}).items():
        if key == "mode":
            if value not in MODES:
                raise ValueError(f"mode = {value!r} is not dark or light")
            seeds["mode"] = value
        elif key in SEED_KEYS:
            colour = normalize_color(value)
            if colour is None:
                raise ValueError(f"{key} = {value!r} is not a colour")
            seeds[key] = colour
    overrides = {}
    for key, value in dict(data.get("overrides") or {}).items():
        if key in TOKEN_KEYS:
            colour = normalize_color(value)
            if colour is None:
                raise ValueError(f"{key} = {value!r} is not a colour")
            overrides[key] = colour
    return {"name": name, "base": base, "seeds": seeds, "overrides": overrides}


# ------------------------------------------------------------ colour helpers
_HEX = re.compile(r"#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})")


def normalize_color(value):
    """``"#rrggbb"`` for ``"#abc"``, ``"AABBCC"``, ``"#aabbcc"``; None when
    *value* is not a hex colour."""
    match = _HEX.fullmatch(str(value or "").strip())
    if not match:
        return None
    digits = match.group(1).lower()
    if len(digits) == 3:
        digits = "".join(c * 2 for c in digits)
    return "#" + digits


def contrast(a, b):
    """WCAG contrast ratio of two colours, 1 (none) to 21 (black on white).
    Body text wants 4.5 (AA) or 7 (AAA), large text and controls 3."""
    def luminance(colour):
        r, g, b = (v / 255.0 for v in _rgb(colour))
        r, g, b = (v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
                   for v in (r, g, b))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


# ------------------------------------------------------- generated indicators
_asset_root = None       # kept alive for the process lifetime
_asset_cache = {}


# The tokens the artwork is painted in.  It is cached, and named on disk, by
# these colours rather than by theme name: an edited theme keeps its name, and
# Qt caches an image by its path.
_ASSET_TOKENS = ("surface_alt", "border_strong", "surface_hi", "accent_line",
                 "accent", "on_accent", "bg_alt", "border", "muted", "faint")


def _asset_path(colours):
    global _asset_root
    if _asset_root is None:
        _asset_root = tempfile.TemporaryDirectory(prefix="bcbgui-theme-")
    digest = hashlib.sha1(repr(colours).encode()).hexdigest()[:12]
    d = os.path.join(_asset_root.name, digest)
    os.makedirs(d, exist_ok=True)
    return d


def _assets(t):
    """Paint the checkbox / arrow / branch artwork for theme *t*.

    Returns a dict of stylesheet-ready ``url(...)`` paths, or empty strings if
    no QGuiApplication is available (the stylesheet then keeps Qt's own).
    """
    colours = tuple(t[k] for k in _ASSET_TOKENS)
    if colours in _asset_cache:
        return _asset_cache[colours]
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
        d = _asset_path(colours)
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
    _asset_cache[colours] = out
    return out


# ---------------------------------------------------------------------- sizes
# The stylesheet is written in px for a 100 % interface: Qt's px are device-
# independent, while a pt is drawn 25 % smaller on macOS (72 logical dpi) than
# elsewhere (96).  The whole sheet is then scaled by the screen and the text
# size the user picks.
TEXT_SIZES = (0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6)


def screen_scale(screen):
    """Size factor suited to *screen*: 1 up to a laptop's ~1000 px of usable
    height, growing to 1.3 on a 4K-class one (device-independent pixels)."""
    if screen is None:
        return 1.0
    height = screen.availableGeometry().height()
    return min(1.3, max(1.0, 1.0 + (height - 1000) / 3500.0))


# Lengths of 1-2 px are hairlines (borders, the tab underline) and letter
# spacing, and stay as they are at any size.
_LENGTH = re.compile(r"(?<![\w.])(-?\d+(?:\.\d+)?)px")


def _scale_lengths(sheet, scale):
    def scaled(match):
        value = float(match.group(1))
        if abs(value) < 3 or scale == 1.0:
            return match.group(0)
        sign = -1 if value < 0 else 1
        return "%dpx" % (sign * max(1, round(abs(value) * scale)))
    return _LENGTH.sub(scaled, sheet)


# ---------------------------------------------------------------------- fonts
_SANS = ("Inter", "SF Pro Text", "Segoe UI", "Ubuntu", "Cantarell",
         "Noto Sans", "DejaVu Sans")
_MONO = ("JetBrains Mono", "Fira Code", "SF Mono", "Menlo", "Consolas",
         "DejaVu Sans Mono")
_families_found = None


def _families():
    """``(sans, mono)``: the first installed family of each list.

    Only installed fonts are named, so Qt never searches aliases for a
    missing one (slow, and logged).  Without any of the sans list -- macOS
    ships none -- the stylesheet names no family and the system font, the
    one native applications use, applies.
    """
    global _families_found
    if _families_found is None:
        sans, mono = None, "monospace"
        try:
            from PyQt6.QtGui import QFontDatabase, QGuiApplication
            if QGuiApplication.instance() is not None:
                installed = set(QFontDatabase.families())
                sans = next((f for f in _SANS if f in installed), None)
                mono = next((f for f in _MONO if f in installed), None) or \
                    QFontDatabase.systemFont(
                        QFontDatabase.SystemFont.FixedFont).family()
                sans = f'"{sans}"' if sans else None
                mono = f'"{mono}"'
        except Exception:                               # pragma: no cover
            pass
        _families_found = (sans, mono)
    return _families_found


# ------------------------------------------------------------------ stylesheet
_TEMPLATE = """
* { outline: 0; }
QWidget { color: %(text)s; %(font_decl)s font-size: 14px; }
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
#Brand { color: %(text)s; font-size: 17px; font-weight: 800; letter-spacing: 0.5px; }
#BrandSub { color: %(accent_text)s; font-size: 11px; font-weight: 800; letter-spacing: 2.4px; }
#VDivider { background-color: %(border)s; min-width: 1px; max-width: 1px; border: none; }
#HDivider { background-color: %(border)s; min-height: 1px; max-height: 1px; border: none; }

/* ---------------------------------------------------------------- buttons */
QPushButton {
    background-color: %(surface)s; border: 1px solid %(border)s; border-radius: 9px;
    padding: 6px 12px; min-height: 24px; font-weight: 600; color: %(text_dim)s;
    icon-size: 16px; }
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
QPushButton[seg]:checked { background-color: %(accent_soft)s;
    border-color: %(accent_line)s; color: %(text)s; }

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
#TileValue { font-size: 32px; font-weight: 800; color: %(text)s; }
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
    padding: 0 5px; color: %(muted)s; font-size: 11px; font-weight: 800;
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
/* A row widget is placed inside the item padding, so a list of them has none:
   the row would be clipped by it (the widget brings its own margins). */
QListView#PhaseList::item { padding: 0px; }
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
    border-right: 1px solid %(border)s; font-size: 11px; font-weight: 800;
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
    font-weight: 700; font-size: 13px; }
QTabBar::tab:hover { color: %(text)s; }
QTabBar::tab:selected { color: %(text)s; border-bottom: 2px solid %(accent)s; }

/* ---------------------------------------------------------------- preview */
QPlainTextEdit {
    background-color: %(preview_bg)s; border: 1px solid %(border)s;
    border-radius: 10px; padding: 8px; font-family: %(mono)s; font-size: 13px;
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

/* --------------------------------------------------------------- settings */
QListWidget#SettingsNav { background-color: %(bg_alt)s; border: 1px solid %(border)s;
    border-radius: 12px; padding: 6px; }
QListWidget#SettingsNav::item { padding: 8px 10px; border-radius: 9px;
    color: %(text_dim)s; font-weight: 700; }
QListWidget#SettingsNav::item:hover { background-color: %(surface_hi)s; color: %(text)s; }
QListWidget#SettingsNav::item:selected { background-color: %(accent_soft)s;
    color: %(text)s; }
QPushButton[role="swatch"] { padding: 3px; min-height: 0px; border-radius: 7px; }
QSlider::groove:horizontal { height: 4px; background: %(border_strong)s;
    border-radius: 2px; }
QSlider::sub-page:horizontal { background: %(accent)s; border-radius: 2px; }
QSlider::handle:horizontal { background: %(accent)s; border: 2px solid %(surface)s;
    width: 14px; height: 14px; margin: -7px 0px; border-radius: 9px; }
QLabel[check="pass"] { color: %(success_text)s; font-weight: 700; }
QLabel[check="fail"] { color: %(warning_text)s; font-weight: 700; }

/* ------------------------------------------------------------------- misc */
QProgressBar { background-color: %(surface_alt)s; border: 1px solid %(border)s;
    border-radius: 6px; max-height: 8px; min-height: 8px; text-align: center; }
QProgressBar::chunk { background-color: %(accent)s; border-radius: 5px; }
QProgressBar[state="done"]::chunk { background-color: %(success)s; }
QToolTip { background-color: %(tooltip_bg)s; color: %(text)s;
    border: 1px solid %(border_strong)s; border-radius: 7px; padding: 5px 8px; }
QLabel[role="muted"] { color: %(muted)s; }
QLabel[role="hint"] { color: %(muted)s; font-size: 13px; }
QLabel[role="title"] { color: %(text)s; font-size: 15px; font-weight: 700; }
QLabel[role="section"] { color: %(muted)s; font-size: 11px; font-weight: 800;
    letter-spacing: 1.6px; }
QLabel[role="value"] { color: %(text)s; font-weight: 700; }
QLabel#Badge { background-color: %(surface_hi)s; color: %(muted)s;
    border: 1px solid %(border)s; border-radius: 9px; padding: 1px 8px;
    font-size: 11px; font-weight: 700; }
"""


def build_stylesheet(tokens, scale=1.0):
    """Qt stylesheet for a derived token dict (see :func:`get_theme`), with
    every length scaled by *scale* (:func:`screen_scale` times the text size)."""
    data = dict(tokens)
    data.setdefault("_name", DEFAULT_THEME)
    sans, data["mono"] = _families()
    data["font_decl"] = f"font-family: {sans};" if sans else ""
    data.update(_assets(data))
    # Lengths first: the asset paths substituted afterwards are not touched.
    return _scale_lengths(_TEMPLATE, scale) % data


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
