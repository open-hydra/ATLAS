"""Theme-aware widget factory shared by the shell and the stage panels.

Every panel builds its chrome through one :class:`UIKit`, so a theme change is
a single call (:meth:`UIKit.retint`) that re-tints every icon the application
has handed out, wherever it lives.  The same call follows the text size: sizes
set in code (icons, table rows, fixed widths) are given at 100 % and go
through :meth:`UIKit.px`, the way the stylesheet's lengths are scaled.
"""

from __future__ import annotations

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QBrush, QColor
from PyQt6.QtWidgets import (
    QDialog, QDialogButtonBox, QFrame, QHBoxLayout, QLabel, QPushButton,
    QScrollArea, QVBoxLayout, QWidget,
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


class Dialog(QDialog):
    """Shared chrome for every dialog of the GUI: title, explanation, buttons.

    The dense parts of a setup are edited in their own window rather than in
    the stage panel, so this chrome is used from several modules.
    """

    def __init__(self, parent, kit, title, explanation="", icon="sliders"):
        super().__init__(parent)
        self.kit = kit
        self.setWindowTitle(title)
        self.setObjectName("Root")
        self.setModal(True)
        self.layout_ = QVBoxLayout(self)
        self.layout_.setContentsMargins(16, 14, 16, 14)
        self.layout_.setSpacing(10)
        header = QHBoxLayout()
        header.setSpacing(8)
        header.addWidget(kit.icon_label(icon, "accent", 18))
        header.addWidget(kit.title(title))
        header.addStretch(1)
        self.layout_.addLayout(header)
        if explanation:
            self.layout_.addWidget(kit.hint(explanation))

    def add_buttons(self, close_only=False):
        """OK / Cancel, or a single Close for a dialog that commits live."""
        standard = (QDialogButtonBox.StandardButton.Close if close_only else
                    QDialogButtonBox.StandardButton.Ok
                    | QDialogButtonBox.StandardButton.Cancel)
        buttons = QDialogButtonBox(standard)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        primary = buttons.button(
            QDialogButtonBox.StandardButton.Close if close_only
            else QDialogButtonBox.StandardButton.Ok)
        primary.setProperty("role", "primary")
        if close_only:
            primary.clicked.connect(self.accept)
        self.layout_.addWidget(buttons)
        return buttons


class UIKit:
    """Builds themed widgets and keeps their icons in sync with the theme."""

    def __init__(self, theme_provider):
        self._provider = theme_provider      # anything with a .theme dict
        self._slots = []                     # (setter, icon-name, token, size)
        self._compactable = []               # (button, full text)
        self._repaints = []                  # state-dependent artwork
        self._compact_labels = []

    @property
    def theme(self):
        return self._provider.theme

    @property
    def scale(self):
        """Size factor of the interface: the screen's, times the text size."""
        return getattr(self._provider, "ui_scale", 1.0)

    def px(self, value):
        """*value* pixels of the 100 % design, at the current size."""
        return int(round(value * self.scale))

    def color(self, token):
        return self.theme.get(token, self.theme["text"])

    def color_brush(self, token):
        return QBrush(QColor(self.color(token)))

    # -- icons -----------------------------------------------------------
    def icon(self, name, token="text_dim", size=18):
        return icons.icon(name, self.color(token), self.px(size))

    def pixmap(self, name, token="muted", size=16):
        return icons.pixmap(name, self.color(token), self.px(size))

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
            lambda ic, w=label, s=size: w.setPixmap(
                ic.pixmap(self.px(s), self.px(s))),
            name, token, size))
        return label

    def register_repaint(self, repaint):
        """Call *repaint* on every theme or text-size change.

        For artwork whose colour depends on state rather than on one token --
        a toggle that ticks when checked, a path that marks a missing file --
        and for the sizes set in code.
        """
        self._repaints.append(repaint)

    def sized(self, setter, value):
        """Call *setter* with :meth:`px` of *value*, now and whenever the
        text size changes (a fixed width, a minimum height)."""
        self.register_repaint(lambda: setter(self.px(value)))
        setter(self.px(value))

    def table_rows(self, table, height=28):
        """Rows of *height* px (at 100 %) for *table*, following the text size."""
        self.sized(table.verticalHeader().setDefaultSectionSize, height)

    def retint(self):
        """Re-tint every icon handed out, and forget the ones whose widget died.

        The stage editors are rebuilt as the selection changes, so a slot
        registered for a widget that no longer exists is normal: Qt raises
        RuntimeError on it, and that is how a dead slot is dropped.
        """
        live = []
        for slot in self._slots:
            setter, name, token, size = slot
            try:
                setter(self.icon(name, token, size))
            except RuntimeError:
                continue
            live.append(slot)
        self._slots = live
        alive = []
        for repaint in self._repaints:
            try:
                repaint()
            except RuntimeError:
                continue
            alive.append(repaint)
        self._repaints = alive

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
        self.sized(line.setFixedHeight, height)
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
