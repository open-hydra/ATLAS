"""The Phases stage's view of the tables GPB wrote (:mod:`atlasgui.tables`).

One phase at a time -- the one selected in the deck when GPB wrote it, or any
other phase the case holds -- and one of its sheets: the thermodynamics and
the transport of a gas, its binary diffusion, its rate constants, the
properties of a condensed or solid phase as curves against the temperature,
up to eight species, materials, pairs or reactions at once; the property
grid of a real fluid as a map over pressure and enthalpy, its iso-lines at
the values the colour bar marks.  Under the plot: when GPB wrote the tables,
and whether the case has changed since.
"""

from __future__ import annotations

import datetime
import os

import numpy as np
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QBrush, QColor
from PyQt6.QtWidgets import (QAbstractItemView, QComboBox, QHBoxLayout, QLabel, QLineEdit,
                             QListWidget, QListWidgetItem, QStackedWidget, QVBoxLayout,
                             QWidget)

from . import fieldcolors, icons, tables
from .fieldview import ColourBar, format_value
from .plotview import MAX_SERIES, SERIES, MapPlot, XYPlot, nice_ticks

DEFAULT_SERIES = 4              # curves shown at first
FILTER_FROM = 12                # a list this long gets a filter box


class TablesView(QWidget):
    """The tables of one phase, drawn.  ``run_requested`` asks for the Run
    stage."""

    run_requested = pyqtSignal()

    def __init__(self, kit, parent=None):
        super().__init__(parent)
        self.kit = kit
        self.case_dir = None
        self.phases = []                 # [tables.PhaseOutput]
        self.sheet = None
        self.error = None
        self._chosen = {}                # (phase, sheet) -> {zone: slot} of the curves shown
        self._quantity = {}              # (phase, sheet) -> quantity shown
        self._log = {}                   # (phase, sheet) -> log scale
        self._context = (None, False)    # (ini path, unsaved changes)
        self._missing = None             # a deck phase GPB has not written
        self._loading = False

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(8)
        row = QHBoxLayout()
        row.setSpacing(6)
        self.phase = QComboBox()
        self.phase.setToolTip("The phase whose tables are drawn: the one selected in the deck, "
                              "or any other GPB wrote")
        self.phase.currentIndexChanged.connect(self._phase_changed)
        row.addWidget(self.phase, 1)
        self.sheet_combo = QComboBox()
        self.sheet_combo.setToolTip("Which of its tables")
        self.sheet_combo.currentIndexChanged.connect(self._sheet_changed)
        row.addWidget(self.sheet_combo, 1)
        lay.addLayout(row)
        row = QHBoxLayout()
        row.setSpacing(6)
        self.quantity = QComboBox()
        self.quantity.setToolTip("The quantity drawn")
        self.quantity.currentIndexChanged.connect(self._quantity_changed)
        kit.sized(self.quantity.setMinimumWidth, 200)
        row.addWidget(self.quantity, 1)
        self.log_toggle = kit.toggle("Log scale", self._log_changed, "profile", False,
                                     tip="The values on a logarithmic scale: rates and "
                                         "diffusion coefficients span decades")
        row.addWidget(self.log_toggle)
        self.zoom_reset = kit.button("All T", self._reset_zoom, "fit", "ghost",
                                     tip="Back to the whole range (or double-click the plot)")
        row.addWidget(self.zoom_reset)
        lay.addLayout(row)

        self.plots = QStackedWidget()
        self.xy = XYPlot(kit)
        self.xy.zoomed.connect(self._zoomed)
        self.xy.setToolTip("Hover for the values at a temperature; drag across to zoom in, "
                           "double-click to see all of it")
        self.map = MapPlot(kit)
        self.map.zoomed.connect(self._zoomed)
        self.map.setToolTip("Hover for every property at a (p, h); drag across to zoom in on "
                            "a range of pressure, double-click to see all of it")
        self.plots.addWidget(self.xy)
        self.plots.addWidget(self.map)
        lay.addWidget(self.plots, 1)
        self.bar = ColourBar(kit)
        lay.addWidget(self.bar)

        self.series_head = QHBoxLayout()
        self.series_head.setSpacing(6)
        self.series_label = kit.section_label("CURVES")
        self.series_head.addWidget(self.series_label)
        self.series_head.addStretch(1)
        self.filter = QLineEdit()
        self.filter.setPlaceholderText("Filter…")
        self.filter.setClearButtonEnabled(True)
        self.filter.textChanged.connect(self._filter_series)
        kit.sized(self.filter.setMaximumWidth, 180)
        self.series_head.addWidget(self.filter)
        lay.addLayout(self.series_head)
        self.series = QListWidget()
        self.series.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.series.setTextElideMode(Qt.TextElideMode.ElideRight)
        self.series.setSelectionMode(QAbstractItemView.SelectionMode.NoSelection)
        self.series.setToolTip(f"Tick the curves to draw, up to {MAX_SERIES}: each keeps its "
                               "colour while it is drawn")
        self.series.itemChanged.connect(self._series_ticked)
        lay.addWidget(self.series)

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
        self.run_button = kit.button("Run GPB…", self.run_requested.emit, "play", "ghost",
                                     tip="The Run stage: run GPB to write the tables")
        empty.addWidget(self.run_button)
        lay.addWidget(self.empty)
        kit.register_repaint(self.redraw)

    # ------------------------------------------------------------ the case
    def show_case(self, case_dir, prefer=None, ini_path=None, dirty=False):
        """The tables of *case_dir*; *prefer*, the name of the phase selected
        in the deck, shown when GPB has written it (else said to be
        missing).  *ini_path*, *dirty*: the case as saved, to tell whether
        the tables are older than it."""
        self.case_dir = case_dir
        self._context = (ini_path, dirty)
        self.phases = tables.phase_outputs(case_dir) if case_dir else []
        names = [p.name for p in self.phases]
        current = self.phase.currentData()
        if prefer is not None:
            current = prefer
        self._missing = current if current is not None and current not in names and \
            prefer is not None else None
        self._loading = True
        self.phase.clear()
        if self._missing is not None:
            self.phase.addItem(f"{self._missing or '(unnamed)'} · not written yet", self._missing)
        for phase in self.phases:
            self.phase.addItem(icons.dot(_family_colour(phase.family), 11), phase.label,
                               phase.name)
        index = self.phase.findData(current) if current is not None else -1
        self.phase.setCurrentIndex(max(index, 0))
        self._loading = False
        self._phase_changed()

    def current_phase(self):
        name = self.phase.currentData()
        for phase in self.phases:
            if phase.name == name:
                return phase
        return None

    def select(self, phase_name, sheet_key=None):
        """Show *phase_name* (and its sheet *sheet_key*), when written."""
        index = self.phase.findData(phase_name)
        if index >= 0:
            self.phase.setCurrentIndex(index)
        if sheet_key is not None:
            index = self.sheet_combo.findData(sheet_key)
            if index >= 0:
                self.sheet_combo.setCurrentIndex(index)

    def _phase_changed(self, _index=None):
        if self._loading:
            return
        phase = self.current_phase()
        current = self.sheet_combo.currentData()
        self._loading = True
        self.sheet_combo.clear()
        if phase is not None:
            for key, label in tables.sheets(phase):
                self.sheet_combo.addItem(label, key)
        index = self.sheet_combo.findData(current)
        self.sheet_combo.setCurrentIndex(max(index, 0))
        self.sheet_combo.setVisible(self.sheet_combo.count() > 1)
        self._loading = False
        self._sheet_changed()

    def _key(self):
        phase = self.current_phase()
        return (phase.name if phase else None, self.sheet_combo.currentData())

    def _sheet_changed(self, _index=None):
        if self._loading:
            return
        phase = self.current_phase()
        key = self.sheet_combo.currentData()
        self.sheet, self.error = None, None
        if phase is not None and key is not None:
            try:
                self.sheet = tables.load_sheet(phase, key)
            except (tables.TableError, OSError) as exc:
                self.error = f"{os.path.basename(phase.files.get(key, '') or '') or key}: {exc}"
        sheet = self.sheet
        self._loading = True
        self.quantity.clear()
        if sheet is not None:
            for name in sheet.quantities:
                label, unit = tables.describe(name)
                self.quantity.addItem(f"{label} [{unit}]" if unit else label, name)
            wanted = self._quantity.get(self._key())
            index = self.quantity.findData(wanted) if wanted else 0
            self.quantity.setCurrentIndex(max(index, 0))
        self.log_toggle.setChecked(self._log.get(self._key(), bool(sheet and sheet.log)))
        self._fill_series()
        self._loading = False
        self.redraw()

    def _quantity_changed(self, _index=None):
        if self._loading:
            return
        self._quantity[self._key()] = self.quantity.currentData()
        self.redraw()

    def _log_changed(self, on):
        if self._loading:
            return
        self._log[self._key()] = bool(on)
        self.redraw()

    def _reset_zoom(self):
        self.xy.reset_zoom()
        self.map.reset_zoom()

    def _zoomed(self):
        self.zoom_reset.setVisible(self.xy.span is not None or self.map.span is not None)

    # --------------------------------------------------------- the curves
    def _chosen_now(self):
        """``{zone: colour slot}`` of the curves drawn on this sheet."""
        sheet = self.sheet
        key = self._key()
        if key not in self._chosen and sheet is not None:
            zones = [zone for zone, _label in sheet.series][:DEFAULT_SERIES]
            self._chosen[key] = {zone: n for n, zone in enumerate(zones)}
        return self._chosen.get(key, {})

    def _fill_series(self):
        sheet = self.sheet
        self.series.blockSignals(True)
        self.series.clear()
        chosen = self._chosen_now()
        xy = sheet is not None and sheet.form == "xy"
        if xy:
            for zone, label in sheet.series:
                item = QListWidgetItem(label)
                item.setData(Qt.ItemDataRole.UserRole, zone)
                item.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsUserCheckable)
                item.setCheckState(Qt.CheckState.Checked if zone in chosen
                                   else Qt.CheckState.Unchecked)
                item.setToolTip(label)
                self.series.addItem(item)
        self.series.blockSignals(False)
        self._paint_series()
        many = xy and len(sheet.series) > 1
        for widget in (self.series, self.series_label):
            widget.setVisible(many)
        self.filter.setVisible(many and len(sheet.series) >= FILTER_FROM)
        if not self.filter.isVisible():
            self.filter.clear()
        if many:
            rows = min(self.series.count(), 7)
            frame = 2 * self.series.frameWidth() + 4
            self.series.setFixedHeight(rows * max(self.series.sizeHintForRow(0), 1) + frame)
        self._filter_series(self.filter.text())

    def _paint_series(self):
        """The colour of every curve drawn beside its name: the list is the
        legend."""
        chosen = self._chosen_now()
        palette = SERIES[self._mode()]
        self.series.blockSignals(True)
        for n in range(self.series.count()):
            item = self.series.item(n)
            slot = chosen.get(item.data(Qt.ItemDataRole.UserRole))
            if slot is None:
                item.setIcon(icons.dot("#00000000", 11, ring=self.kit.color("border_strong")))
                item.setForeground(QBrush(QColor(self.kit.color("muted"))))
            else:
                item.setIcon(icons.dot(palette[slot], 11))
                item.setForeground(QBrush(QColor(self.kit.color("text"))))
        self.series.blockSignals(False)
        self.series_label.setText(f"CURVES · {len(chosen)} OF {self.series.count()}"
                                  if self.series.count() else "CURVES")

    def _series_ticked(self, item):
        chosen = self._chosen_now()
        zone = item.data(Qt.ItemDataRole.UserRole)
        if item.checkState() == Qt.CheckState.Checked:
            if zone not in chosen:
                free = [s for s in range(MAX_SERIES) if s not in chosen.values()]
                if not free:
                    self.series.blockSignals(True)
                    item.setCheckState(Qt.CheckState.Unchecked)
                    self.series.blockSignals(False)
                    self.note.setText(f"{MAX_SERIES} curves at most: untick one to draw "
                                      "another.")
                    self.note.setVisible(True)
                    return
                chosen[zone] = free[0]
        else:
            chosen.pop(zone, None)
        self._paint_series()
        self.redraw()

    def _filter_series(self, text):
        text = text.strip().lower()
        for n in range(self.series.count()):
            item = self.series.item(n)
            item.setHidden(bool(text) and text not in item.text().lower())

    # ------------------------------------------------------------ drawing
    def _mode(self):
        return "dark" if self.kit.theme.get("mode") == "dark" else "light"

    def redraw(self):
        sheet = self.sheet
        phase = self.current_phase()
        if phase is None or sheet is None:
            self._show_empty(phase)
            return
        self.empty.setVisible(False)
        self.phase.setVisible(True)
        self.quantity.setVisible(True)
        warnings, notes = self._notes(phase, sheet)
        name = self.quantity.currentData()
        if sheet.form == "map":
            self.plots.setCurrentWidget(self.map)
            self.log_toggle.setVisible(False)
            self._draw_map(sheet, name, notes)
        else:
            self.plots.setCurrentWidget(self.xy)
            self.log_toggle.setVisible(True)
            self.bar.setVisible(False)
            self._paint_series()             # the theme may have changed the colours
            self._draw_curves(sheet, name)
        self.plots.setVisible(True)
        self.zoom_reset.setText("All p" if sheet.form == "map" else "All T")
        self._zoomed()
        self.warning.setText("\n".join(warnings))
        self.warning.setVisible(bool(warnings))
        self.note.setText("\n".join(notes))
        self.note.setVisible(bool(notes))

    def _draw_curves(self, sheet, name):
        chosen = self._chosen_now()
        palette = SERIES[self._mode()]
        labels = dict(sheet.series)
        curves = []
        for zone, slot in sorted(chosen.items(), key=lambda item: item[1]):
            y = sheet.values(zone, name)
            if y is None:
                continue
            curves.append((labels.get(zone, zone), palette[slot],
                           sheet.values(zone, sheet.x), y))
        self.xy.empty_text = ("Tick a curve below to draw it" if sheet.series
                              else "The table has no zone")
        self.xy.set_data(tables.describe(sheet.x), tables.describe(name), curves,
                         log=self.log_toggle.isChecked())

    def _draw_map(self, sheet, name, notes):
        values = sheet.values("grid", name)
        if values is None:
            self.map.clear()
            self.bar.setVisible(False)
            return
        finite = values[np.isfinite(values)]
        low, high = (float(finite.min()), float(finite.max())) if finite.size else (0.0, 1.0)
        signed = fieldcolors.is_signed(low, high)
        dark = self._mode() == "dark"
        table = fieldcolors.diverging(dark) if signed else fieldcolors.sequential(dark)
        colours = fieldcolors.colours(values.ravel(order="F"), low, high, table, signed,
                                      missing=(128, 128, 128))
        colours = colours.reshape(values.shape + (3,), order="F")
        if signed:
            reach = max(abs(low), abs(high))
            levels = nice_ticks(-reach, reach, 8)[0]
        else:
            levels = nice_ticks(low, high, 8)[0] if high > low else []
        levels = [v for v in levels if low < v < high]
        xs, ys = tables.axis(sheet, sheet.x), tables.axis(sheet, sheet.y)
        label, unit = tables.describe(name)
        self.map.set_data(xs, ys, values, colours, levels, tables.describe(sheet.x),
                          tables.describe(sheet.y), self._readout(sheet, name))
        self.bar.setVisible(True)
        self.bar.show_scale(table, low, high, signed, f"{label} [{unit}]" if unit else label,
                            (low, high), marks=levels)
        if levels:
            notes.insert(0, "Lines: the values the colour bar marks.")

    def _readout(self, sheet, shown):
        """The values of every quantity of the grid at (p, h), bilinear."""
        xs, ys = tables.axis(sheet, sheet.x), tables.axis(sheet, sheet.y)
        grid = sheet.zones["grid"]

        def readout(x, y):
            fi = float(np.interp(x, xs, np.arange(len(xs))))
            fj = float(np.interp(y, ys, np.arange(len(ys))))
            i0, j0 = min(int(fi), len(xs) - 2), min(int(fj), len(ys) - 2)
            ti, tj = fi - i0, fj - j0
            rows = []
            for name in [shown] + [q for q in sheet.quantities if q != shown]:
                v = grid.data[name]
                value = ((1 - ti) * (1 - tj) * v[i0, j0] + ti * (1 - tj) * v[i0 + 1, j0]
                         + ti * tj * v[i0 + 1, j0 + 1] + (1 - ti) * tj * v[i0, j0 + 1])
                label, unit = tables.describe(name)
                rows.append(f"{label.split(' · ')[0]} = {format_value(float(value))} {unit}"
                            .rstrip())
            title = (f"p = {format_value(x)} Pa · h = {format_value(y)} J/kg")
            return title, rows

        return readout

    def _notes(self, phase, sheet):
        warnings, notes = [], []
        written = phase.mtime()
        ini, dirty = self._context
        try:
            newer = bool(ini) and os.path.getmtime(ini) > written + 1
        except OSError:
            newer = False
        if newer:
            warnings.append("The INI was saved after GPB wrote these tables: run GPB again "
                            "to see the phases as they are now.")
        elif dirty:
            warnings.append("The case has changes GPB has not run on: the tables are the "
                            "ones of the INI as last saved and run.")
        files = ", ".join(os.path.basename(p) for p in sheet.paths)
        where = os.path.basename(phase.directory.rstrip(os.sep))
        when = datetime.datetime.fromtimestamp(written)
        notes.append(f"{files} in {where}/, written {when:%d %b %H:%M}")
        notes += sheet.notes
        return warnings, notes

    def _show_empty(self, phase):
        for widget in (self.plots, self.bar, self.series, self.series_label, self.filter,
                       self.quantity, self.log_toggle, self.zoom_reset):
            widget.setVisible(False)
        self.empty.setVisible(True)
        self.warning.setVisible(False)
        if self.error:
            self.empty_text.setText(self.error)
            self.run_button.setVisible(True)
        elif self._missing is not None and phase is None:
            name = self._missing or "the unnamed phase"
            self.empty_text.setText(f"GPB has not written the tables of {name} yet: run it to "
                                    "see its properties.")
            self.run_button.setVisible(True)
        elif not self.phases:
            self.empty_text.setText(f"GPB has written no table in {tables.OUTPUT_DIR}/ yet: run "
                                    "it to see the properties of the phases.")
            self.run_button.setVisible(True)
        else:
            self.empty_text.setText("GPB wrote no table of this phase that can be drawn.")
            self.run_button.setVisible(False)
        self.note.setVisible(False)
        self.phase.setVisible(bool(self.phases) or self._missing is not None)
        self.sheet_combo.setVisible(False)


def _family_colour(family):
    from .gpbpanel import FAMILY_COLORS
    return FAMILY_COLORS.get(family, "#888888")

