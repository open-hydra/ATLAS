"""The Settings window: one page per subject, picked from a sidebar.

It follows the settings dialogs of the large engineering suites: a sidebar of
pages, OK / Cancel / Apply, and Restore Defaults for the page shown.  Every
change is previewed on the whole application as it is made; Cancel puts back
what was last applied, Apply and OK store it (:mod:`atlasgui.preferences`).

* **Appearance** -- the theme, picked from a gallery of miniatures, and the
  text size;
* **Colours** -- the theme editor: the seed colours the others follow, the
  derived colours a theme may set itself, a live preview with the WCAG
  contrast of the pairs that carry text, and the user's themes (duplicate,
  rename, delete, import, export).  A built-in theme is never changed: the
  first edit makes a copy of it.

A page is a widget with ``refresh()`` -- show the dialog's state -- and
``restore_defaults()``; a new page is one more line of
:attr:`SettingsDialog.PAGES`.
"""

from __future__ import annotations

import os

from PyQt6.QtCore import QPointF, QRectF, QSize, Qt, QTimer
from PyQt6.QtGui import (QColor, QFont, QFontMetrics, QIcon, QKeySequence,
                         QLinearGradient, QPainter, QPainterPath, QPen,
                         QPolygonF)
from PyQt6.QtWidgets import (
    QAbstractButton, QButtonGroup, QColorDialog, QComboBox, QDialog,
    QDialogButtonBox, QFileDialog, QGridLayout, QHBoxLayout, QInputDialog,
    QLabel, QLineEdit, QListWidget, QListWidgetItem, QMenu, QMessageBox,
    QPushButton, QSlider, QStackedWidget, QVBoxLayout, QWidget,
)

from . import icons, preferences
from . import theme as thememod
from .widgets import Card


def _copy_spec(spec):
    return {"name": spec["name"], "base": spec.get("base", thememod.DEFAULT_THEME),
            "seeds": dict(spec["seeds"]),
            "overrides": dict(spec.get("overrides", {}))}


def _copy_specs(specs):
    return {name: _copy_spec(spec) for name, spec in specs.items()}


# ------------------------------------------------------------------ widgets
class ThemeCard(QAbstractButton):
    """A theme of the gallery: a miniature of the window in its colours."""

    def __init__(self, kit, spec, parent=None):
        super().__init__(parent)
        self.kit = kit
        self.setCheckable(True)
        self.setAttribute(Qt.WidgetAttribute.WA_Hover, True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.set_spec(spec)

    def set_spec(self, spec):
        self.spec = spec
        self.tokens = thememod.derive(spec)
        custom = not thememod.is_builtin(spec["name"])
        self.setToolTip(f"{spec['name']} — "
                        + (f"your theme, based on {spec['base']}" if custom
                           else "built-in theme"))
        self.update()

    def sizeHint(self):
        return QSize(self.kit.px(178), self.kit.px(140))

    def enterEvent(self, event):
        super().enterEvent(event)
        self.update()

    def leaveEvent(self, event):
        super().leaveEvent(event)
        self.update()

    def paintEvent(self, _event):
        t, chrome, s = self.tokens, self.kit.theme, self.kit.scale
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        w, h = self.width(), self.height()

        # The card, in the colours of the dialog.
        if self.isChecked():
            border, width = chrome["accent"], 2.0
        elif self.underMouse():
            border, width = chrome["border_strong"], 1.0
        else:
            border, width = chrome["border"], 1.0
        p.setPen(QPen(QColor(border), width))
        p.setBrush(QColor(chrome["surface"]))
        p.drawRoundedRect(QRectF(1, 1, w - 2, h - 2), 10 * s, 10 * s)

        # The miniature, in the colours of the theme.
        pad, label_h = 7 * s, 26 * s
        mini = QRectF(pad, pad, w - 2 * pad, h - 2 * pad - label_h)
        clip = QPainterPath()
        clip.addRoundedRect(mini, 6 * s, 6 * s)
        p.setClipPath(clip)
        p.setPen(Qt.PenStyle.NoPen)
        p.fillRect(mini, QColor(t["bg"]))
        bar = QRectF(mini.x(), mini.y(), mini.width(), mini.height() * 0.17)
        p.fillRect(bar, QColor(t["bg_alt"]))
        p.setBrush(QColor(t["accent"]))
        p.drawRoundedRect(QRectF(bar.right() - 30 * s, bar.y() + 3 * s,
                                 24 * s, bar.height() - 6 * s), 3 * s, 3 * s)
        body_y = bar.bottom() + 3 * s
        body_h = mini.bottom() - body_y - 3 * s
        rail = QRectF(mini.x() + 3 * s, body_y, mini.width() * 0.16, body_h)
        p.setBrush(QColor(t["bg_alt"]))
        p.drawRoundedRect(rail, 3 * s, 3 * s)
        p.setBrush(QColor(t["accent_soft"]))
        p.drawRoundedRect(QRectF(rail.x() + 2 * s, rail.y() + 4 * s,
                                 rail.width() - 4 * s, 7 * s), 2 * s, 2 * s)
        panel = QRectF(rail.right() + 3 * s, body_y, mini.width() * 0.4, body_h)
        p.setPen(QPen(QColor(t["border"]), 1.0))
        p.setBrush(QColor(t["surface"]))
        p.drawRoundedRect(panel, 4 * s, 4 * s)
        p.setPen(Qt.PenStyle.NoPen)
        for i, (token, frac) in enumerate((("text", 0.55), ("muted", 0.8),
                                           ("muted", 0.65))):
            p.setBrush(QColor(t[token]))
            p.drawRoundedRect(QRectF(panel.x() + 5 * s,
                                     panel.y() + (6 + 9 * i) * s,
                                     (panel.width() - 10 * s) * frac, 4 * s),
                              2 * s, 2 * s)
        p.setBrush(QColor(t["surface_alt"]))
        p.drawRoundedRect(QRectF(panel.x() + 5 * s, panel.bottom() - 15 * s,
                                 panel.width() - 10 * s, 10 * s), 3 * s, 3 * s)
        view = QRectF(panel.right() + 3 * s, body_y,
                      mini.right() - panel.right() - 6 * s, body_h)
        gradient = QLinearGradient(view.topLeft(), view.bottomLeft())
        gradient.setColorAt(0, QColor(t["viewport_bg2"]))
        gradient.setColorAt(1, QColor(t["viewport_bg"]))
        p.setBrush(gradient)
        p.drawRoundedRect(view, 4 * s, 4 * s)
        cx, cy, r = view.center().x(), view.center().y(), min(view.width(), view.height()) * 0.28
        face = QPolygonF([QPointF(cx - r, cy - r * 0.4), QPointF(cx, cy - r),
                          QPointF(cx + r, cy - r * 0.4), QPointF(cx, cy + r * 0.2)])
        p.setPen(QPen(QColor(t["edge"]), 1.0))
        p.setBrush(QColor(t["unassigned"]))
        p.drawPolygon(face)
        p.setPen(QPen(QColor(t["highlight_edge"]), 1.6))
        p.setBrush(QColor(t["accent"]))
        p.drawPolygon(QPolygonF([QPointF(cx - r, cy - r * 0.4),
                                 QPointF(cx, cy + r * 0.2),
                                 QPointF(cx, cy + r), QPointF(cx - r, cy + r * 0.4)]))
        p.setClipping(False)

        # The name, and whether it is one of the user's.
        label = QRectF(pad + 2 * s, h - label_h - pad / 2, w - 2 * pad - 4 * s, label_h)
        font = QFont(self.font())
        room = label.width()
        if not thememod.is_builtin(self.spec["name"]):
            p.setFont(font)
            p.setPen(QColor(chrome["muted"]))
            p.drawText(label, Qt.AlignmentFlag.AlignRight
                       | Qt.AlignmentFlag.AlignVCenter, "custom")
            room -= QFontMetrics(font).horizontalAdvance("custom") + 8 * s
        font.setBold(True)
        p.setFont(font)
        p.setPen(QColor(chrome["text"]))
        name = QFontMetrics(font).elidedText(
            self.spec["name"], Qt.TextElideMode.ElideRight, int(room))
        p.drawText(label, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                   name)
        p.end()


class ViewportSample(QWidget):
    """The 3-D view's colours on a small painted mesh."""

    def __init__(self, dialog):
        super().__init__()
        self.dialog = dialog
        self.setMinimumHeight(dialog.kit.px(120))

    def paintEvent(self, _event):
        t, s = self.dialog.tokens(), self.dialog.kit.scale
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        rect = QRectF(0.5, 0.5, self.width() - 1, self.height() - 1)
        gradient = QLinearGradient(rect.topLeft(), rect.bottomLeft())
        gradient.setColorAt(0, QColor(t["viewport_bg2"]))
        gradient.setColorAt(1, QColor(t["viewport_bg"]))
        p.setPen(QPen(QColor(t["border"]), 1.0))
        p.setBrush(gradient)
        p.drawRoundedRect(rect, 10 * s, 10 * s)
        # A block of 3 x 2 faces seen in perspective; one assigned, one picked.
        cx, cy = rect.center().x(), rect.center().y() + 6 * s
        dx, dy = min(rect.width() / 9, 42 * s), 16 * s
        fills = {(0, 0): t["accent"], (2, 1): t["success"]}
        for i in range(3):
            for j in range(2):
                x0 = cx + (i - 1.5) * dx + j * dx * 0.35
                y0 = cy + (j - 1) * dy
                quad = QPolygonF([QPointF(x0, y0), QPointF(x0 + dx, y0),
                                  QPointF(x0 + dx * 1.35, y0 + dy),
                                  QPointF(x0 + dx * 0.35, y0 + dy)])
                p.setPen(QPen(QColor(t["edge"]), 1.0))
                p.setBrush(QColor(fills.get((i, j), t["unassigned"])))
                p.drawPolygon(quad)
                if (i, j) == (1, 0):
                    p.setPen(QPen(QColor(t["highlight_edge"]), 2.4 * s))
                    p.setBrush(Qt.BrushStyle.NoBrush)
                    p.drawPolygon(quad)
        context = QColor(t["context"])
        context.setAlphaF(0.25)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(context)
        p.drawRect(QRectF(cx - 1.6 * dx, cy + dy + 6 * s, 3.6 * dx, 6 * s))
        # A face label, as the view draws them.
        font = QFont(self.font())
        font.setPixelSize(max(9, round(11 * s)))
        p.setFont(font)
        tag = QRectF(rect.x() + 10 * s, rect.y() + 10 * s, 74 * s, 20 * s)
        p.setBrush(QColor(t["label_shape"]))
        p.drawRoundedRect(tag, 5 * s, 5 * s)
        p.setPen(QColor(t["label_text"]))
        p.drawText(tag, Qt.AlignmentFlag.AlignCenter, "B1 · face 3")
        p.end()


class ColorRow:
    """One colour of the editor: its name, a swatch that opens a picker, the
    hex value, and a reset."""

    def __init__(self, dialog, grid, row, key, label):
        self.dialog, self.key = dialog, key
        kit = dialog.kit
        self.label = QLabel(label)
        self.label.setToolTip(f"Token {key}")
        self.swatch = QPushButton()
        self.swatch.setProperty("role", "swatch")
        self.swatch.setToolTip("Choose the colour")
        self.swatch.clicked.connect(lambda: dialog.pick_colour(key))
        self.hex = QLineEdit()
        self.hex.setMaxLength(7)
        kit.sized(self.hex.setFixedWidth, 92)
        self.hex.setToolTip("Hex colour, #rrggbb")
        self.hex.textEdited.connect(self._typed)
        self.hex.editingFinished.connect(self._finished)
        self.reset = kit.button("", lambda: dialog.reset_colour(key), "reset",
                                "ghost")
        # Shown on a changed colour only, its column kept when it is not.
        policy = self.reset.sizePolicy()
        policy.setRetainSizeWhenHidden(True)
        self.reset.setSizePolicy(policy)
        grid.addWidget(self.label, row, 0)
        grid.addWidget(self.swatch, row, 1)
        grid.addWidget(self.hex, row, 2)
        grid.addWidget(self.reset, row, 3)
        self.value = ""

    def _typed(self, text):
        colour = thememod.normalize_color(text)
        if colour is not None and len(text.strip().lstrip("#")) == 6:
            self.dialog.set_colour(self.key, colour)

    def _finished(self):
        if thememod.normalize_color(self.hex.text()) is None:
            self.hex.setText(self.value)     # not a colour: back to the one in use

    def show(self, colour, changed, reset_tip):
        kit = self.dialog.kit
        self.value = colour
        self.swatch.setIcon(QIcon(icons.swatch_pixmap(
            colour, kit.px(34), kit.px(18), kit.theme["border_strong"])))
        self.swatch.setIconSize(QSize(kit.px(34), kit.px(18)))
        if not self.hex.hasFocus():
            self.hex.setText(colour)
        self.reset.setVisible(changed)
        self.reset.setToolTip(reset_tip)
        font = self.label.font()
        font.setBold(changed)
        self.label.setFont(font)


# -------------------------------------------------------------------- pages
class AppearancePage(QWidget):
    """The theme, from a gallery of miniatures, and the text size."""

    title = "Appearance"
    scrolls = True          # the gallery grows with the user's themes
    blurb = ("How the application looks. Changes show at once; Apply or OK "
             "keeps them, Cancel puts back what was there.")

    def __init__(self, dialog):
        super().__init__()
        self.dialog = dialog
        kit = dialog.kit
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        themes = Card()
        themes.body.addLayout(kit.panel_header("contrast", "THEME"))
        self.gallery = QGridLayout()
        self.gallery.setHorizontalSpacing(kit.px(10))
        self.gallery.setVerticalSpacing(kit.px(10))
        themes.body.addLayout(self.gallery)
        self.cards = {}
        self.card_group = QButtonGroup(self)
        self.card_group.setExclusive(True)
        row = QHBoxLayout()
        row.addWidget(kit.hint("Built-in themes are fixed; your own are saved "
                               "as files you can share."), 1)
        row.addWidget(kit.button("Customise colours…",
                                 lambda: dialog.show_page("colours"), "palette"))
        themes.body.addLayout(row)
        layout.addWidget(themes)

        text = Card()
        text.body.addLayout(kit.panel_header("type", "TEXT SIZE"))
        line = QHBoxLayout()
        line.setSpacing(12)
        small = QLabel("A")
        kit.sized(lambda v, w=small: w.setStyleSheet(f"font-size: {v}px;"), 12)
        line.addWidget(small)
        self.slider = QSlider(Qt.Orientation.Horizontal)
        self.slider.setRange(0, len(thememod.TEXT_SIZES) - 1)
        self.slider.setPageStep(1)
        self.slider.setTickPosition(QSlider.TickPosition.NoTicks)
        self.slider.valueChanged.connect(
            lambda i: dialog.set_text_size(thememod.TEXT_SIZES[i]))
        line.addWidget(self.slider, 1)
        big = QLabel("A")
        kit.sized(lambda v, w=big: w.setStyleSheet(f"font-size: {v}px;"), 22)
        line.addWidget(big)
        self.size_label = QLabel()
        self.size_label.setProperty("role", "value")
        kit.sized(self.size_label.setMinimumWidth, 56)
        line.addWidget(self.size_label)
        text.body.addLayout(line)
        native = QKeySequence.SequenceFormat.NativeText
        keys = ", ".join(QKeySequence(k).toString(native) for k in (
            QKeySequence.StandardKey.ZoomIn, QKeySequence.StandardKey.ZoomOut,
            "Ctrl+0"))
        self.size_hint = kit.hint("")
        text.body.addWidget(self.size_hint)
        text.body.addWidget(kit.hint(
            f"Text and controls grow together. {keys} change the size from "
            f"anywhere in the window."))
        layout.addWidget(text)
        layout.addStretch(1)

    def refresh(self):
        dialog = self.dialog
        names = dialog.theme_names()
        if list(self.cards) != names:
            for card in self.cards.values():
                self.card_group.removeButton(card)
                card.setParent(None)
                card.deleteLater()
            self.cards = {}
            for index, name in enumerate(names):
                card = ThemeCard(dialog.kit, dialog.spec_of(name))
                card.clicked.connect(lambda _c=False, n=name: dialog.select_theme(n))
                self.card_group.addButton(card)
                self.gallery.addWidget(card, index // 3, index % 3,
                                       Qt.AlignmentFlag.AlignLeft)
                self.cards[name] = card
        for name, card in self.cards.items():
            card.set_spec(dialog.spec_of(name))
            card.setChecked(name == dialog.theme_name)
            card.updateGeometry()
        index = thememod.TEXT_SIZES.index(dialog.text_size)
        if self.slider.value() != index:
            self.slider.blockSignals(True)
            self.slider.setValue(index)
            self.slider.blockSignals(False)
        self.size_label.setText(f"{round(dialog.text_size * 100)} %")
        screen = dialog.shell.screen_scale
        self.size_hint.setText(
            f"100 % is sized for this screen (×{screen:.2f}); the interface is "
            f"drawn at ×{dialog.text_size * screen:.2f}.")

    def restore_defaults(self):
        self.dialog.select_theme(thememod.DEFAULT_THEME)
        self.dialog.set_text_size(1.0)


class ColoursPage(QWidget):
    """The theme editor."""

    title = "Colours"
    scrolls = False         # its colour list and preview scroll on their own
    blurb = ("The colours of a theme. The base colours set the look; the "
             "others follow them unless you set them here.")

    def __init__(self, dialog):
        super().__init__()
        self.dialog = dialog
        kit = dialog.kit
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)

        # Which theme, its mode, and what can be done with it.
        head = QHBoxLayout()
        head.setSpacing(8)
        head.addWidget(kit.section_label("THEME"))
        self.theme_combo = QComboBox()
        kit.sized(self.theme_combo.setMinimumWidth, 200)
        self.theme_combo.currentIndexChanged.connect(self._combo_changed)
        head.addWidget(self.theme_combo)
        head.addSpacing(kit.px(6))
        self.mode_buttons = {}
        self.mode_group = QButtonGroup(self)
        for i, mode in enumerate(thememod.MODES):
            button = kit.button(mode.capitalize(), None, None,
                                seg="left" if i == 0 else "right",
                                tip=f"Derive the other colours for a {mode} theme")
            button.setCheckable(True)
            button.clicked.connect(lambda _c=False, m=mode: dialog.set_mode(m))
            self.mode_group.addButton(button)
            self.mode_buttons[mode] = button
            head.addWidget(button)
        head.addStretch(1)
        head.addWidget(kit.button("Duplicate", dialog.duplicate_theme, "copy",
                                  tip="Make an editable copy of this theme"))
        manage = kit.button("Manage", None, "sliders")
        menu = QMenu(manage)
        self.rename_action = menu.addAction("Rename…", dialog.rename_theme)
        self.delete_action = menu.addAction("Delete", dialog.delete_theme)
        menu.addSeparator()
        menu.addAction("Import…", dialog.import_theme)
        menu.addAction("Export…", dialog.export_theme)
        manage.setMenu(menu)
        head.addWidget(manage)
        layout.addLayout(head)

        self.banner = kit.hint("")
        layout.addWidget(self.banner)

        body = QHBoxLayout()
        body.setSpacing(12)
        # The colours, in a scrolling column.
        colours = QWidget()
        column = QVBoxLayout(colours)
        column.setContentsMargins(0, 0, kit.px(8), 0)
        column.setSpacing(6)
        self.rows = {}
        for title, groups, note in (
                ("BASE COLOURS", thememod.SEED_GROUPS, None),
                ("DERIVED COLOURS", thememod.TOKEN_GROUPS,
                 "These follow the base colours. Set one to fix it; ↺ lets it "
                 "follow again.")):
            column.addWidget(kit.title(title.capitalize()))
            if note:
                column.addWidget(kit.hint(note))
            for group, keys in groups:
                column.addSpacing(kit.px(4))
                column.addWidget(kit.section_label(group.upper()))
                grid = QGridLayout()
                grid.setHorizontalSpacing(8)
                grid.setVerticalSpacing(4)
                grid.setColumnStretch(0, 1)
                for row, (key, label) in enumerate(keys):
                    self.rows[key] = ColorRow(dialog, grid, row, key, label)
                column.addLayout(grid)
            column.addSpacing(kit.px(10))
        column.addStretch(1)
        self.colours_body = colours
        self.colours_area = kit.scrollable(colours)
        body.addWidget(self.colours_area, 1)

        # The preview: real widgets, so they show the theme as it applies.
        preview = QVBoxLayout()
        preview.setSpacing(10)
        sample = Card()
        sample.body.addLayout(kit.panel_header("eye", "PREVIEW"))
        sample.body.addWidget(kit.title("Phase 1 · gas"))
        sample.body.addWidget(kit.hint("Labels and hints read like this."))
        fields = QHBoxLayout()
        fields.addWidget(QLineEdit("H2 O2 N2"), 1)
        combo = QComboBox()
        combo.addItems(["NASA9", "Burcat"])
        fields.addWidget(combo)
        sample.body.addLayout(fields)
        buttons = QHBoxLayout()
        buttons.addWidget(kit.button("Save", None, "save", "primary"))
        buttons.addWidget(kit.button("Remove", None, "trash", "danger"))
        buttons.addStretch(1)
        sample.body.addLayout(buttons)
        toggles = QHBoxLayout()
        toggles.addWidget(kit.toggle("Explicit species", None, "check", True,
                                     compactable=False))
        toggles.addWidget(kit.toggle("Mechanism", None, "check", False,
                                     compactable=False))
        toggles.addStretch(1)
        sample.body.addLayout(toggles)
        sample_list = QListWidget()
        for text in ("gas", "particles", "wall"):
            sample_list.addItem(QListWidgetItem(text))
        sample_list.setCurrentRow(1)
        kit.sized(sample_list.setFixedHeight, 96)
        sample.body.addWidget(sample_list)
        self.viewport = ViewportSample(dialog)
        sample.body.addWidget(self.viewport)
        preview.addWidget(sample)

        checks = Card()
        checks.body.addLayout(kit.panel_header("check", "CONTRAST (WCAG)"))
        self.check_grid = QGridLayout()
        self.check_grid.setHorizontalSpacing(10)
        self.check_grid.setVerticalSpacing(4)
        self.check_grid.setColumnStretch(0, 1)
        self.checks = []
        for row, (fg, bg, label, need) in enumerate(CONTRAST_PAIRS):
            name = QLabel(label)
            ratio = QLabel()
            grade = QLabel()
            self.check_grid.addWidget(name, row, 0)
            self.check_grid.addWidget(ratio, row, 1, Qt.AlignmentFlag.AlignRight)
            self.check_grid.addWidget(grade, row, 2)
            self.checks.append((fg, bg, need, ratio, grade))
        checks.body.addLayout(self.check_grid)
        checks.body.addWidget(kit.hint(
            "Text wants 4.5 : 1 (AA) or 7 : 1 (AAA); edges and controls 3 : 1."))
        preview.addWidget(checks)
        preview.addStretch(1)
        holder = QWidget()
        holder.setLayout(preview)
        preview_area = kit.scrollable(holder)
        kit.sized(preview_area.setMinimumWidth, 330)
        kit.sized(preview_area.setMaximumWidth, 400)
        body.addWidget(preview_area, 1)
        layout.addLayout(body, 1)

        self.where = kit.hint("")
        self.where.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(self.where)

    def _combo_changed(self, _index):
        name = self.theme_combo.currentData()
        if name and name != self.dialog.theme_name:
            self.dialog.select_theme(name)

    def refresh(self):
        dialog = self.dialog
        names = dialog.theme_names()
        listed = [self.theme_combo.itemData(i)
                  for i in range(self.theme_combo.count())]
        if [n for n in listed if n is not None] != names:      # not separators
            self.theme_combo.blockSignals(True)
            self.theme_combo.clear()
            for index, name in enumerate(names):
                if index == len(thememod.THEMES):
                    self.theme_combo.insertSeparator(index)
                self.theme_combo.addItem(name, name)
            self.theme_combo.blockSignals(False)
        self.theme_combo.blockSignals(True)
        self.theme_combo.setCurrentIndex(self.theme_combo.findData(dialog.theme_name))
        self.theme_combo.blockSignals(False)

        spec = dialog.current_spec()
        builtin = thememod.is_builtin(spec["name"])
        mode = spec["seeds"].get("mode", "dark")
        for name, button in self.mode_buttons.items():
            button.setChecked(name == mode)
        self.rename_action.setEnabled(not builtin)
        self.delete_action.setEnabled(not builtin)
        if builtin:
            self.banner.setText(
                f"{spec['name']} is a built-in theme: your first change makes a "
                f"copy of it to edit, and {spec['name']} stays as it is.")
        else:
            base_seeds = thememod.THEMES[spec["base"]]
            changed = len(spec["overrides"]) + sum(
                1 for k in thememod.SEED_KEYS + ["mode"]
                if spec["seeds"].get(k) != base_seeds.get(k))
            self.banner.setText(
                f"Your theme, based on {spec['base']}: {changed} colour(s) "
                f"differ from it.")

        tokens = dialog.tokens()
        base = thememod.THEMES[spec["base"]]
        for key, row in self.rows.items():
            if key in thememod.SEED_KEYS:
                changed = not builtin and spec["seeds"].get(key) != base.get(key)
                row.show(tokens[key], changed,
                         f"Back to {spec['base']}'s {base.get(key)}")
            else:
                row.show(tokens[key], key in spec["overrides"],
                         "Follow the base colours again")
        for fg, bg, need, ratio_label, grade_label in self.checks:
            ratio = min(thememod.contrast(tokens[fg], tokens[b]) for b in bg)
            ok = ratio >= need
            if need < 4.5:          # an edge, not text: no AA/AAA grades
                grade = "ok"
            else:
                grade = ("AAA" if ratio >= 7 else "AA" if ratio >= 4.5 else
                         "AA large")
            ratio_label.setText(f"{ratio:.1f} : 1")
            grade_label.setText(grade if ok else "low")
            grade_label.setToolTip(f"{ratio:.2f} : 1, this pair wants {need:g} : 1")
            if grade_label.property("check") != ("pass" if ok else "fail"):
                grade_label.setProperty("check", "pass" if ok else "fail")
                grade_label.style().unpolish(grade_label)
                grade_label.style().polish(grade_label)
        self.viewport.update()
        # The colours keep their natural width (label, swatch, hex, reset):
        # the preview column is the one that gives way.
        bar = self.colours_area.verticalScrollBar().sizeHint().width()
        self.colours_area.setMinimumWidth(
            self.colours_body.sizeHint().width() + bar + 4)
        where = preferences.themes_dir().replace(os.path.expanduser("~"), "~", 1)
        self.where.setText(f"Your themes are saved in {where} when you apply.")

    def restore_defaults(self):
        self.dialog.reset_theme()


# (foreground token, the backgrounds it is drawn on, what it is, the ratio it
# needs); a check shows the worst of its backgrounds.
CONTRAST_PAIRS = [
    ("text", ("surface", "surface_alt", "bg_alt", "surface_hi"), "Text", 4.5),
    ("muted", ("surface", "bg", "bg_alt", "surface_alt", "header_bg",
               "surface_hi"), "Labels and hints", 4.5),
    ("text_dim", ("surface", "surface_hi", "bg_alt"), "Button text", 4.5),
    ("text", ("accent_soft",), "Selected text", 4.5),
    ("on_accent", ("accent", "accent_hi"), "Text on the accent", 4.5),
    ("accent_text", ("bg_alt", "surface", "preview_bg"), "Accent as text", 4.5),
    ("danger_text", ("danger_soft", "surface"), "Delete buttons, errors", 4.5),
    ("syn_comment", ("preview_bg",), "INI comments", 4.5),
    ("edge", ("viewport_bg", "viewport_bg2"), "Mesh edges on the 3-D view", 3.0),
]


# ------------------------------------------------------------------- dialog
class SettingsDialog(QDialog):
    """Settings of the GUI.  Works on a copy of the user's choices, previews
    them on the application as they change, and stores them on Apply/OK."""

    PAGES = [("appearance", AppearancePage, "contrast"),
             ("colours", ColoursPage, "palette")]

    def __init__(self, shell, page="appearance"):
        super().__init__(shell)
        self.shell = shell
        self.kit = shell.kit
        self.setWindowTitle("Settings")
        self.setObjectName("Root")
        self.setModal(True)

        self.themes = _copy_specs(thememod.custom_themes())
        self.theme_name = shell._theme_name
        self.text_size = shell._text_size
        self._applied = (_copy_specs(self.themes), self.theme_name, self.text_size)
        self._preview_timer = QTimer(self)
        self._preview_timer.setSingleShot(True)
        self._preview_timer.setInterval(120)
        self._preview_timer.timeout.connect(self._preview)

        kit = self.kit
        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 12)
        root.setSpacing(12)
        main = QHBoxLayout()
        main.setSpacing(14)
        self.nav = QListWidget()
        self.nav.setObjectName("SettingsNav")
        kit.sized(self.nav.setFixedWidth, 190)
        self.stack = QStackedWidget()
        self.pages = {}
        for key, page_class, icon in self.PAGES:
            page_widget = page_class(self)
            holder = QWidget()
            column = QVBoxLayout(holder)
            column.setContentsMargins(0, 0, 0, 0)
            column.setSpacing(8)
            heading = QLabel(page_class.title)
            heading.setProperty("role", "title")
            column.addWidget(heading)
            column.addWidget(kit.hint(page_class.blurb))
            column.addWidget(kit.scrollable(page_widget) if page_class.scrolls
                             else page_widget, 1)
            self.stack.addWidget(holder)
            item = QListWidgetItem(page_class.title)
            kit.register_icon(item.setIcon, icon, "text_dim", 18)
            self.nav.addItem(item)
            self.pages[key] = page_widget
        self.nav.currentRowChanged.connect(self._on_page)
        main.addWidget(self.nav)
        main.addWidget(self.stack, 1)
        root.addLayout(main, 1)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.RestoreDefaults
            | QDialogButtonBox.StandardButton.Cancel
            | QDialogButtonBox.StandardButton.Apply
            | QDialogButtonBox.StandardButton.Ok)
        self.restore_button = buttons.button(
            QDialogButtonBox.StandardButton.RestoreDefaults)
        self.restore_button.clicked.connect(self._restore_defaults)
        buttons.button(QDialogButtonBox.StandardButton.Apply).clicked.connect(
            self.apply)
        ok = buttons.button(QDialogButtonBox.StandardButton.Ok)
        ok.setProperty("role", "primary")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

        screen = shell.screen().availableGeometry()
        self.resize(min(kit.px(1080), screen.width() - 60),
                    min(kit.px(760), screen.height() - 60))
        self.show_page(page)
        self.refresh()

    # -- state ---------------------------------------------------------
    def theme_names(self):
        return list(thememod.THEMES) + [n for n in self.themes
                                        if n not in thememod.THEMES]

    def spec_of(self, name):
        if name in self.themes:
            return self.themes[name]
        return thememod.theme_spec(name)

    def current_spec(self):
        return self.spec_of(self.theme_name)

    def tokens(self):
        return thememod.derive(self.current_spec())

    def _unique_name(self, base):
        taken = set(thememod.THEMES) | set(self.themes)
        name, suffix = base, 2
        while name in taken:
            name = f"{base} {suffix}"
            suffix += 1
        return name

    def _editable_spec(self):
        """The spec an edit goes into: the current theme, or -- for a
        built-in one -- a copy of it made now and selected."""
        if thememod.is_builtin(self.theme_name):
            spec = thememod.theme_spec(self.theme_name)
            spec["name"] = self._unique_name(f"{self.theme_name} custom")
            self.themes[spec["name"]] = spec
            self.theme_name = spec["name"]
        return self.themes[self.theme_name]

    # -- pages ---------------------------------------------------------
    def show_page(self, key):
        index = [k for k, _c, _i in self.PAGES].index(key)
        self.nav.setCurrentRow(index)

    def _on_page(self, index):
        self.stack.setCurrentIndex(index)
        key = self.PAGES[index][0]
        self.restore_button.setToolTip(
            "Back to the Dark Blue theme at 100 % text size" if key == "appearance"
            else "Undo every change of this theme, back to its base theme")

    def refresh(self):
        for page in self.pages.values():
            page.refresh()

    def _changed(self):
        """Show the new state here, and on the application shortly."""
        self.refresh()
        self._preview_timer.start()

    def _preview(self):
        self.shell.preview_appearance(self.tokens(), self.text_size)
        self.refresh()

    def _restore_defaults(self):
        key = self.PAGES[self.stack.currentIndex()][0]
        self.pages[key].restore_defaults()

    # -- edits ---------------------------------------------------------
    def select_theme(self, name):
        self.theme_name = name
        self._changed()

    def set_text_size(self, size):
        self.text_size = size
        self._changed()

    def set_colour(self, key, colour):
        spec = self._editable_spec()
        if key in thememod.SEED_KEYS:
            spec["seeds"][key] = colour
        else:
            spec["overrides"][key] = colour
        self._changed()

    def reset_colour(self, key):
        if thememod.is_builtin(self.theme_name):
            return
        spec = self.themes[self.theme_name]
        if key in thememod.SEED_KEYS:
            spec["seeds"][key] = thememod.THEMES[spec["base"]][key]
        else:
            spec["overrides"].pop(key, None)
        self._changed()

    def set_mode(self, mode):
        if self.current_spec()["seeds"].get("mode") != mode:
            self._editable_spec()["seeds"]["mode"] = mode
        self._changed()

    def reset_theme(self):
        """Every colour of the current theme back to its base theme's."""
        if thememod.is_builtin(self.theme_name):
            return
        spec = self.themes[self.theme_name]
        spec["seeds"] = dict(thememod.THEMES[spec["base"]])
        spec["overrides"] = {}
        self._changed()

    def pick_colour(self, key):
        """A colour picker that previews as it moves; Cancel undoes all of
        it, the copy of a built-in theme its first move made included."""
        before = (_copy_specs(self.themes), self.theme_name)
        picker = QColorDialog(QColor(self.tokens()[key]), self)
        picker.setWindowTitle(
            f"Colour — {self.pages['colours'].rows[key].label.text()}")
        picker.setOption(QColorDialog.ColorDialogOption.DontUseNativeDialog, True)
        picker.currentColorChanged.connect(
            lambda colour: self.set_colour(key, colour.name()))
        if picker.exec() == QDialog.DialogCode.Accepted:
            self.set_colour(key, picker.selectedColor().name())
        else:
            self.themes, self.theme_name = before
            self._changed()
        picker.deleteLater()

    # -- the user's themes ---------------------------------------------
    def duplicate_theme(self):
        spec = _copy_spec(self.current_spec())
        spec["name"] = self._unique_name(f"{self.theme_name} copy")
        self.themes[spec["name"]] = spec
        self.select_theme(spec["name"])

    def rename_theme(self):
        if thememod.is_builtin(self.theme_name):
            return
        name, ok = QInputDialog.getText(self, "Rename theme", "Name:",
                                        text=self.theme_name)
        name = name.strip()
        if not ok or not name or name == self.theme_name:
            return
        if name in thememod.THEMES or name in self.themes:
            QMessageBox.warning(self, "Rename theme",
                                f"There is already a theme called {name}.")
            return
        spec = self.themes.pop(self.theme_name)
        spec["name"] = name
        self.themes[name] = spec
        self.select_theme(name)

    def delete_theme(self):
        if thememod.is_builtin(self.theme_name):
            return
        reply = QMessageBox.question(
            self, "Delete theme",
            f"Delete the theme {self.theme_name}? Its file is removed when you "
            f"apply.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel)
        if reply != QMessageBox.StandardButton.Yes:
            return
        base = self.themes.pop(self.theme_name)["base"]
        self.select_theme(base if base in thememod.THEMES
                          else thememod.DEFAULT_THEME)

    def import_theme(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Import theme", os.path.expanduser("~"),
            "ATLAS themes (*.json);;All files (*)")
        if not path:
            return
        try:
            spec = preferences.read_theme_file(path)
        except ValueError as exc:
            QMessageBox.warning(self, "Import theme",
                                f"{os.path.basename(path)}: {exc}.")
            return
        spec["name"] = self._unique_name(spec["name"])
        self.themes[spec["name"]] = spec
        self.select_theme(spec["name"])

    def export_theme(self):
        spec = self.current_spec()
        start = os.path.join(os.path.expanduser("~"),
                             spec["name"].replace(" ", "-") + ".json")
        path, _ = QFileDialog.getSaveFileName(
            self, "Export theme", start, "ATLAS themes (*.json)")
        if not path:
            return
        try:
            preferences.write_theme_file(spec, path)
        except OSError as exc:
            QMessageBox.critical(self, "Export theme", str(exc))

    # -- outcome -------------------------------------------------------
    def apply(self):
        """Store the dialog's state and make it the application's."""
        try:
            preferences.save_themes(self.themes)
        except OSError as exc:
            QMessageBox.critical(self, "Settings",
                                 f"The themes could not be saved: {exc}")
            return False
        thememod.set_custom_themes(_copy_specs(self.themes))
        self._preview_timer.stop()
        self.shell.set_appearance(self.theme_name, self.text_size)
        self._applied = (_copy_specs(self.themes), self.theme_name, self.text_size)
        self.refresh()
        return True

    def accept(self):
        if self.apply():
            super().accept()

    def reject(self):
        """Put back what was last applied."""
        self._preview_timer.stop()
        themes, name, size = self._applied
        self.themes = _copy_specs(themes)
        self.theme_name, self.text_size = name, size
        self.shell.set_appearance(name, size)
        super().reject()
