"""Theme-aware widget factory shared by the shell and the stage panels.

Every panel builds its chrome through one :class:`UIKit`, so a theme change is
a single call (:meth:`UIKit.retint`) that re-tints every icon the application
has handed out, wherever it lives.
"""

from __future__ import annotations

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QFrame, QHBoxLayout, QLabel, QPushButton, QScrollArea, QVBoxLayout, QWidget,
)

from . import icons


class Card(QFrame):
    """A panel surface: rounded, bordered, one shade above the background."""

    def __init__(self, parent=None, margins=(12, 10, 12, 12), spacing=9):
        super().__init__(parent)
        self.setObjectName("Card")
        self.body = QVBoxLayout(self)
        self.body.setContentsMargins(*margins)
        self.body.setSpacing(spacing)


class UIKit:
    """Builds themed widgets and keeps their icons in sync with the theme."""

    def __init__(self, theme_provider):
        self._provider = theme_provider      # anything with a .theme dict
        self._slots = []                     # (setter, icon-name, token, size)
        self._compactable = []               # (button, full text)
        self._compact_labels = []

    @property
    def theme(self):
        return self._provider.theme

    def color(self, token):
        return self.theme.get(token, self.theme["text"])

    # -- icons -----------------------------------------------------------
    def icon(self, name, token="text_dim", size=18):
        return icons.icon(name, self.color(token), size)

    def pixmap(self, name, token="muted", size=16):
        return icons.pixmap(name, self.color(token), size)

    def register_icon(self, setter, name, token="text_dim", size=18):
        """Keep *setter* in sync with the theme; it is called with a QIcon."""
        self._slots.append((setter, name, token, size))
        setter(self.icon(name, token, size))

    def bind_icon(self, widget, name, token="text_dim", size=18):
        widget.setIcon(self.icon(name, token, size))
        self._slots.append((widget.setIcon, name, token, size))
        return widget

    def icon_label(self, name, token="muted", size=16):
        label = QLabel()
        label.setPixmap(self.pixmap(name, token, size))
        self._slots.append((
            lambda ic, w=label, s=size: w.setPixmap(ic.pixmap(s, s)),
            name, token, size))
        return label

    def retint(self):
        for setter, name, token, size in self._slots:
            setter(self.icon(name, token, size))

    # -- buttons ---------------------------------------------------------
    def button(self, text, slot=None, icon=None, role=None, seg=None, tip=None,
               compactable=False):
        button = QPushButton("  " + text if (icon and text) else text)
        if role:
            button.setProperty("role", role)
        if seg:
            button.setProperty("seg", seg)
        if tip:
            button.setToolTip(tip)
        if icon:
            token = {"primary": "on_accent", "danger": "danger_text"}.get(
                role, "text_dim")
            self.bind_icon(button, icon, token)
        if slot is not None:
            button.clicked.connect(slot)
        if compactable:
            if not button.toolTip():
                button.setToolTip(button.text().strip())
            self._compactable.append((button, button.text()))
        return button

    def toggle(self, text, slot=None, icon=None, checked=True, tip=None,
               compactable=True, icon_off="circle"):
        """A pill that reads as on or off: a tick when checked, a ring when not.

        *icon* is the checked icon (default "check"); *icon_off* the unchecked
        one.  Both follow the theme like any other bound icon.
        """
        icon_on = icon or "check"
        button = self.button(text, None, None, "toggle", tip=tip)
        button.setCheckable(True)
        button.setChecked(checked)

        def paint(_ignored=None, b=button):
            name = icon_on if b.isChecked() else icon_off
            token = "accent" if b.isChecked() else "muted"
            b.setIcon(self.icon(name, token, 18))

        paint()
        button.toggled.connect(lambda _on: paint())
        self._slots.append((paint, icon_on, "accent", 18))
        if slot is not None:
            button.toggled.connect(slot)
        if compactable:
            self._compactable.append((button, button.text()))
        return button

    # -- labels ----------------------------------------------------------
    def section_label(self, text, compactable=False):
        label = QLabel(text)
        label.setProperty("role", "section")
        if compactable:
            self._compact_labels.append(label)
        return label

    def hint(self, text, wrap=True):
        label = QLabel(text)
        label.setProperty("role", "hint")
        label.setWordWrap(wrap)
        return label

    def title(self, text):
        label = QLabel(text)
        label.setProperty("role", "title")
        return label

    def badge(self, text=""):
        label = QLabel(text)
        label.setObjectName("Badge")
        return label

    # -- containers ------------------------------------------------------
    def panel_header(self, icon_name, text, badge=None, trailing=None):
        row = QHBoxLayout()
        row.setSpacing(7)
        row.addWidget(self.icon_label(icon_name, "muted", 15))
        row.addWidget(self.section_label(text))
        if badge is not None:
            row.addWidget(badge)
        row.addStretch(1)
        for widget in (trailing or []):
            row.addWidget(widget)
        return row

    def vdivider(self, height=26):
        line = QFrame()
        line.setObjectName("VDivider")
        line.setFixedWidth(1)
        line.setFixedHeight(height)
        return line

    def hdivider(self):
        line = QFrame()
        line.setObjectName("HDivider")
        line.setFixedHeight(1)
        return line

    def scrollable(self, widget):
        """Wrap *widget* so a short window scrolls it instead of clipping."""
        area = QScrollArea()
        area.setWidget(widget)
        area.setWidgetResizable(True)
        area.setFrameShape(QFrame.Shape.NoFrame)
        area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        area.viewport().setAutoFillBackground(False)
        widget.setAutoFillBackground(False)
        return area

    # -- responsive chrome ----------------------------------------------
    def set_compact(self, on):
        """Drop button labels (keeping icon + tooltip) when space runs short."""
        for button, text in self._compactable:
            button.setText("" if on else text)
        for label in self._compact_labels:
            label.setVisible(not on)


def clear_layout(layout):
    """Delete every widget and nested layout of *layout*."""
    while layout.count():
        item = layout.takeAt(0)
        widget = item.widget()
        if widget is not None:
            widget.setParent(None)
            widget.deleteLater()
            continue
        child = item.layout()
        if child is not None:
            clear_layout(child)
            child.setParent(None)


def spacer(height=6):
    widget = QWidget()
    widget.setFixedHeight(height)
    return widget
