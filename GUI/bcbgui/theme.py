"""Colour themes for the BCB GUI.

Each theme is a flat dict of colour tokens.  The same tokens drive both the Qt
stylesheet (:func:`build_stylesheet`) and the 3-D viewport
(:meth:`bcbgui.viewport.MeshViewport.apply_theme`), so switching a theme
restyles the whole application consistently.
"""

from __future__ import annotations

# Keys consumed by the viewport (everything else styles the Qt widgets).
VIEWPORT_KEYS = (
    "viewport_bg", "edge", "unassigned", "context", "highlight_edge",
    "label_text", "label_shape",
)

THEMES = {
    "Dark Blue": {
        "bg": "#11161c", "text": "#e6edf3",
        "gb_border": "#2a3a4d", "gb_title": "#a8c0d9",
        "btn_bg": "#1f3a54", "btn_border": "#305879", "btn_hover": "#2b4f73",
        "btn_text": "#e7f3ff",
        "primary_bg": "#28628f", "primary_border": "#3f84ba", "primary_text": "#f3fbff",
        "danger_bg": "#6b2f35", "danger_border": "#a34a54", "danger_text": "#ffecee",
        "input_bg": "#16202a", "input_border": "#35516a",
        "panel_bg": "#16202a", "panel_border": "#304255",
        "header_bg": "#203243", "header_text": "#dcecff", "header_border": "#2d4258",
        "preview_bg": "#101820", "preview_text": "#d5e9ff",
        "tab_bg": "#172331", "tab_text": "#b8d0e7",
        "tab_sel_bg": "#20384f", "tab_sel_text": "#f1f6fb",
        "toolbar_bg": "#141c24", "muted": "#8ba0b5",
        "viewport_bg": "#0e141b", "edge": "#4b5a68", "unassigned": "#8a97a5",
        "context": "#c9d3dd", "highlight_edge": "#ffd23f",
        "label_text": "white", "label_shape": "#1f3550",
    },
    "Graphite": {
        "bg": "#1a1a1d", "text": "#e8e8ea",
        "gb_border": "#3a3a40", "gb_title": "#b8b8c0",
        "btn_bg": "#33333a", "btn_border": "#4a4a52", "btn_hover": "#42424b",
        "btn_text": "#eaeaee",
        "primary_bg": "#2f6f6a", "primary_border": "#3f918a", "primary_text": "#eafffb",
        "danger_bg": "#6b2f35", "danger_border": "#a34a54", "danger_text": "#ffecee",
        "input_bg": "#232327", "input_border": "#45454e",
        "panel_bg": "#232327", "panel_border": "#3a3a40",
        "header_bg": "#2c2c32", "header_text": "#e0e0e6", "header_border": "#3a3a40",
        "preview_bg": "#141416", "preview_text": "#d8d8de",
        "tab_bg": "#26262b", "tab_text": "#c0c0c8",
        "tab_sel_bg": "#35353c", "tab_sel_text": "#f2f2f5",
        "toolbar_bg": "#1e1e21", "muted": "#9a9aa4",
        "viewport_bg": "#141416", "edge": "#55555e", "unassigned": "#8f8f98",
        "context": "#cfcfd6", "highlight_edge": "#ffcf40",
        "label_text": "white", "label_shape": "#33333a",
    },
    "Nord": {
        "bg": "#2e3440", "text": "#eceff4",
        "gb_border": "#434c5e", "gb_title": "#a3b8d0",
        "btn_bg": "#3b4252", "btn_border": "#4c566a", "btn_hover": "#434c5e",
        "btn_text": "#eceff4",
        "primary_bg": "#5e81ac", "primary_border": "#81a1c1", "primary_text": "#eceff4",
        "danger_bg": "#bf616a", "danger_border": "#cf7079", "danger_text": "#2e3440",
        "input_bg": "#3b4252", "input_border": "#4c566a",
        "panel_bg": "#3b4252", "panel_border": "#434c5e",
        "header_bg": "#434c5e", "header_text": "#e5e9f0", "header_border": "#4c566a",
        "preview_bg": "#272c36", "preview_text": "#d8dee9",
        "tab_bg": "#3b4252", "tab_text": "#c0ccdc",
        "tab_sel_bg": "#4c566a", "tab_sel_text": "#eceff4",
        "toolbar_bg": "#323847", "muted": "#8896ab",
        "viewport_bg": "#272c36", "edge": "#4c566a", "unassigned": "#7b88a1",
        "context": "#d8dee9", "highlight_edge": "#ebcb8b",
        "label_text": "#eceff4", "label_shape": "#4c566a",
    },
    "Light": {
        "bg": "#f2f4f7", "text": "#1c2530",
        "gb_border": "#c9d3dd", "gb_title": "#4a6580",
        "btn_bg": "#e6ebf1", "btn_border": "#b7c4d2", "btn_hover": "#d6dee7",
        "btn_text": "#1c2530",
        "primary_bg": "#2f7fc0", "primary_border": "#2668a0", "primary_text": "#ffffff",
        "danger_bg": "#c0492f", "danger_border": "#9a3a24", "danger_text": "#ffffff",
        "input_bg": "#ffffff", "input_border": "#b7c4d2",
        "panel_bg": "#ffffff", "panel_border": "#cfd8e2",
        "header_bg": "#dde5ee", "header_text": "#24405c", "header_border": "#c2cedb",
        "preview_bg": "#f7f9fb", "preview_text": "#24333f",
        "tab_bg": "#e2e8ef", "tab_text": "#4a6580",
        "tab_sel_bg": "#ffffff", "tab_sel_text": "#1c2530",
        "toolbar_bg": "#e9eef3", "muted": "#5c6f80",
        "viewport_bg": "#eef1f5", "edge": "#9aa7b5", "unassigned": "#9fb0c0",
        "context": "#8a97a5", "highlight_edge": "#e08a00",
        "label_text": "#1c2530", "label_shape": "#dbe4ee",
    },
}

DEFAULT_THEME = "Dark Blue"


def get_theme(name):
    return THEMES.get(name, THEMES[DEFAULT_THEME])


_TEMPLATE = """
QWidget { background-color: %(bg)s; color: %(text)s;
    font-family: "Segoe UI", "Helvetica Neue", sans-serif; font-size: 10.5pt; }
QGroupBox { border: 1px solid %(gb_border)s; border-radius: 8px; margin-top: 10px;
    font-weight: bold; padding: 8px; }
QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 6px; color: %(gb_title)s; }
QPushButton { background-color: %(btn_bg)s; border: 1px solid %(btn_border)s;
    border-radius: 7px; padding: 6px 9px; font-weight: 600; min-height: 26px;
    color: %(btn_text)s; }
QPushButton:hover { background-color: %(btn_hover)s; }
QPushButton[role="primary"] { background-color: %(primary_bg)s;
    border-color: %(primary_border)s; color: %(primary_text)s; }
QPushButton[role="danger"] { background-color: %(danger_bg)s;
    border-color: %(danger_border)s; color: %(danger_text)s; }
QLineEdit, QComboBox { background-color: %(input_bg)s; border: 1px solid %(input_border)s;
    border-radius: 7px; padding: 5px; min-height: 26px; color: %(text)s; }
QComboBox QAbstractItemView { background-color: %(panel_bg)s; color: %(text)s;
    border: 1px solid %(input_border)s; }
QTreeWidget, QListWidget, QTableWidget { background-color: %(panel_bg)s;
    border: 1px solid %(panel_border)s; border-radius: 8px; color: %(text)s; }
QHeaderView::section { background-color: %(header_bg)s; color: %(header_text)s;
    padding: 5px; border: 0; border-right: 1px solid %(header_border)s; }
QPlainTextEdit { background-color: %(preview_bg)s; border: 1px solid %(panel_border)s;
    border-radius: 8px; font-family: "Menlo", "Consolas", monospace; font-size: 9.5pt;
    color: %(preview_text)s; }
QTabWidget::pane { border: 1px solid %(gb_border)s; border-radius: 8px; }
QTabBar::tab { background: %(tab_bg)s; color: %(tab_text)s; border: 1px solid %(gb_border)s;
    border-bottom: none; border-top-left-radius: 7px; border-top-right-radius: 7px;
    padding: 6px 12px; margin-right: 3px; }
QTabBar::tab:selected { background: %(tab_sel_bg)s; color: %(tab_sel_text)s; }
QToolBar { background: %(toolbar_bg)s; border: none; spacing: 4px; }
QCheckBox { color: %(text)s; }
QLabel[role="muted"] { color: %(muted)s; }
"""


def build_stylesheet(tokens):
    return _TEMPLATE % tokens
