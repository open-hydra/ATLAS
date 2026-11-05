"""What the Boundaries stage shows under its 3-D view when it shows what BCB
wrote: the boundary file (one per phase and multigrid level), the BCs in it
and how many cells each takes, what to know about the file, and the record
of the cell last clicked.

:class:`WrittenView` reads the file (:mod:`atlasgui.bcfile`) and gives the
colour of every cell of every face drawn; the stage hands them to the view.
The colours follow the data-viz rules: a BC in a categorical colour, in the
fixed order of the palette by id; the faces between blocks (connections,
chimera, periodic) and the null BC in a neutral grey, so the boundaries
stand out.
"""

from __future__ import annotations

import datetime
import os

import numpy as np
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import (QAbstractItemView, QComboBox, QHBoxLayout, QLabel, QListWidget,
                             QListWidgetItem, QVBoxLayout, QWidget)

from . import bcfile, icons
from . import faces as facemod
from .plotview import SERIES

NEUTRAL = "#898781"           # interfaces and the null BC: not a boundary
OTHER = "#5f5e5a"             # a ninth BC and beyond
FACE_NAMES = facemod.FACE_LABELS


def _rgb(colour):
    colour = colour.lstrip("#")
    return np.array([int(colour[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.uint8)


class WrittenView(QWidget):
    """The boundary file shown, its BCs, its notes.  ``changed``: another
    file was chosen."""

    changed = pyqtSignal()
    run_requested = pyqtSignal()

    def __init__(self, kit, parent=None):
        super().__init__(parent)
        self.kit = kit
        self.result = None             # the BCFile shown
        self.error = None
        self.mapping = {}              # block of the file -> mesh block (from 1)
        self.colours = {}              # id -> hex
        self._key = None
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        row = QHBoxLayout()
        row.setSpacing(6)
        row.addWidget(kit.section_label("WHAT BCB WROTE"))
        row.addStretch(1)
        self.file = QComboBox()
        self.file.setToolTip("The boundary file shown: one per phase, and one per multigrid "
                             "level (bc2.txt, …)")
        self.file.currentIndexChanged.connect(lambda _i: self.changed.emit())
        row.addWidget(self.file)
        lay.addLayout(row)
        self.legend = QListWidget()
        self.legend.setSelectionMode(QAbstractItemView.SelectionMode.NoSelection)
        self.legend.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.legend.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.legend.setTextElideMode(Qt.TextElideMode.ElideRight)
        self.legend.setToolTip("The BCs of the file, by id, and the boundary cells each takes")
        lay.addWidget(self.legend)
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
        self.run_button = kit.button("Run BCB…", self.run_requested.emit, "play", "ghost",
                                     tip="The Run stage: run BCB to write the boundary files")
        empty.addWidget(self.run_button)
        lay.addWidget(self.empty)

    # ------------------------------------------------------------ the file
    def _choose(self, case_dir):
        files = bcfile.bc_files(case_dir) if case_dir else []
        paths = [f.path for f in files]
        current = self.file.currentData()
        if [self.file.itemData(i) for i in range(self.file.count())] != paths:
            self.file.blockSignals(True)
            self.file.clear()
            for f in files:
                name = f.phase or "(unnamed phase)"
                self.file.addItem(name if f.level == 1 else f"{name} · level {f.level}", f.path)
            self.file.blockSignals(False)
        index = paths.index(current) if current in paths else 0
        if paths:
            self.file.blockSignals(True)
            self.file.setCurrentIndex(index)
            self.file.blockSignals(False)
        self.file.setVisible(len(files) > 1)
        return files[index] if files else None

    def update(self, case_dir, blocks, bcb, ini_path=None, dirty=False, dark=False):
        """Read the file chosen and fill the legend; ``{(b, f): (M, N, 3)}``
        the colours of the faces to draw (b from 0), or None when there is
        nothing to draw."""
        if not blocks:
            self._show_empty("Load the mesh to see the boundary cells BCB wrote.", run=False)
            return None
        info = self._choose(case_dir)
        if info is None:
            self._show_empty(f"BCB has written no boundary file in {bcfile.OUTPUT_DIR}/ yet: "
                             "run it to see the BC of every boundary cell.")
            return None
        try:
            result = bcfile.cached_bc(info.path)
        except (bcfile.BCFileError, OSError) as exc:
            self.result = None
            self._show_empty(f"{os.path.basename(info.path)}: {exc}")
            return None
        self.result = result
        dims = [(b.ni - 1, b.nj - 1, max(b.nk - 1, 0)) for b in blocks]
        mapping, how, issues = bcfile.block_map(result, dims, self._phase_blocks(
            bcb, result.phase, len(blocks)))
        self.mapping = mapping
        factor = 2 ** (result.level - 1)
        drawn, counts, hidden = {}, {}, 0
        for local, mesh_b in mapping.items():
            part = result.blocks[local]
            block = blocks[mesh_b - 1]
            for f, cells in part.faces.items():
                if f not in facemod.assignable_faces(block):
                    hidden += int((cells.ids >= 0).sum())
                    continue
                xf, _y, _z = facemod.extract_face(block, f)
                shape = (max(xf.shape[0] - 1, 1), max(xf.shape[1] - 1, 1))
                ids, _ = bcfile.fine_ids(cells, shape, factor) if factor > 1 else (cells.ids, None)
                if ids.shape != shape:
                    issues.append(f"block {local}, face {f}: {ids.shape[0]}×{ids.shape[1]} "
                                  f"cells in the file, {shape[0]}×{shape[1]} on the mesh")
                    continue
                drawn[(mesh_b - 1, f)] = ids
                values, number = np.unique(ids[ids >= 0], return_counts=True)
                for bc_id, n in zip(values.tolist(), number.tolist()):
                    counts[bc_id] = counts.get(bc_id, 0) + n
        self.colours = self._palette(counts, dark)
        table = {bc_id: _rgb(c) for bc_id, c in self.colours.items()}
        void = _rgb(NEUTRAL) // 2
        faces = {}
        for key, ids in drawn.items():
            rgb = np.empty(ids.shape + (3,), dtype=np.uint8)
            rgb[...] = void
            for bc_id, colour in table.items():
                rgb[ids == bc_id] = colour
            faces[key] = rgb
        self._fill_legend(counts, result.family)
        warnings, notes = self._notes(result, info, ini_path, dirty)
        if issues:
            warnings.insert(0, "The file does not fit the mesh on the screen: "
                            + "; ".join(issues[:3]) + ("; …" if len(issues) > 3 else ""))
        others = [b + 1 for b in range(len(blocks)) if b + 1 not in mapping.values()]
        if others:
            notes.append(f"Block {', '.join(map(str, others[:8]))}{', …' if len(others) > 8 else ''}"
                         f": not in this file (faint)")
        if how != "block for block" and any(k != v for k, v in mapping.items()):
            notes.append(f"Blocks placed {how}.")
        if hidden:
            notes.append("Faces 5 and 6 of a planar block: set by BCB itself, not drawn.")
        if factor > 1:
            notes.append(f"Multigrid level {result.level}: each cell of the file covers "
                         f"{factor}×{factor} cells of the mesh.")
        copies = max((p.copies for p in result.blocks.values()), default=1)
        if copies > 1:
            notes.append(f"The table is written {copies} times, once per material and "
                         "population: the colours are the first's; a click shows each.")
        self.empty.setVisible(False)
        self.legend.setVisible(True)
        self._set_notes(warnings, notes)
        return faces

    @staticmethod
    def _phase_blocks(bcb, phase, nblocks):
        """The mesh blocks of *phase* in the deck (from 1), None when the
        deck does not say (no block set up, or a deck of another mesh)."""
        if bcb is None or bcb.nblocks != nblocks:
            return None
        if not any(bcb.block_phases(b) for b in range(nblocks)):
            return None if phase else list(range(1, nblocks + 1))
        return [b + 1 for b in range(nblocks)
                if not bcb.block_phases(b) or phase in bcb.block_phases(b)]

    def _palette(self, counts, dark):
        palette = SERIES["dark" if dark else "light"]
        colours, slot = {}, 0
        for bc_id in sorted(counts):
            if bc_id in bcfile.INTERFACES or bc_id == 0:
                colours[bc_id] = NEUTRAL
            elif slot < len(palette):
                colours[bc_id] = palette[slot]
                slot += 1
            else:
                colours[bc_id] = OTHER
        return colours

    def _fill_legend(self, counts, family):
        self.legend.clear()
        for bc_id, count in sorted(counts.items()):
            what, _fields = bcfile.describe_id(bc_id, family)
            item = QListWidgetItem(f"  {bc_id} · {what}   · {count:,} cell"
                                   + ("" if count == 1 else "s"))
            item.setIcon(icons.dot(self.colours.get(bc_id, NEUTRAL), 11))
            item.setToolTip(f"BC {bc_id}, {what}: {count:,} boundary cell(s)"
                            + (" (between blocks)" if bc_id in bcfile.INTERFACES else ""))
            self.legend.addItem(item)
        rows = min(max(self.legend.count(), 1), 8)
        frame = 2 * self.legend.frameWidth() + 4
        self.legend.setFixedHeight(rows * max(self.legend.sizeHintForRow(0), 1) + frame)

    def _notes(self, result, info, ini_path, dirty):
        warnings, notes = [], []
        try:
            newer = bool(ini_path) and os.path.getmtime(ini_path) > info.mtime + 1
        except OSError:
            newer = False
        if newer:
            warnings.append("The INI was saved after BCB wrote this file: run BCB again to "
                            "see the boundaries as they are now.")
        elif dirty:
            warnings.append("The case has changes BCB has not run on: the file is the one of "
                            "the INI as last saved and run.")
        when = datetime.datetime.fromtimestamp(info.mtime)
        notes.append(f"{result.label}, written by BCB {when:%d %b %H:%M}: "
                     f"{result.records:,} records")
        return warnings, notes

    def _set_notes(self, warnings, notes):
        self.warning.setText("\n".join(warnings))
        self.warning.setVisible(bool(warnings))
        self.note.setText("\n".join(notes))
        self.note.setVisible(bool(notes))

    def _show_empty(self, text, run=True):
        self.result = None
        self.mapping = {}
        self.legend.clear()
        self.legend.setVisible(False)
        self.empty.setVisible(True)
        self.empty_text.setText(text)
        self.run_button.setVisible(run)
        self._set_notes([], [])

    # ------------------------------------------------------------ a cell
    def describe(self, b, face, m, n):
        """The record of cell *(m, n)* (from 0) of *face* of mesh block *b*
        (from 0), in words."""
        result = self.result
        if result is None:
            return ""
        local = next((k for k, v in self.mapping.items() if v == b + 1), None)
        if local is None:
            return f"Block {b + 1}: not in {result.label}"
        part = result.blocks[local]
        cells = part.faces.get(face)
        factor = 2 ** (result.level - 1)
        cm, cn = (m // factor, n // factor) if factor > 1 else (m, n)
        if cells is None or cm >= cells.ids.shape[0] or cn >= cells.ids.shape[1] \
                or cells.ids[cm, cn] < 0:
            return f"Block {b + 1}, face {face}: no record of this cell"
        bc_id = int(cells.ids[cm, cn])
        what, _fields = bcfile.describe_id(bc_id, result.family)
        lines = result.record(local, face, cm, cn)
        index = [int(t) for t in lines[0].split()[1:1 + result.ndim]]
        where = f"cell ({', '.join(map(str, index))})"
        block_text = f"Block {b + 1}" + (f" (block {local} of the file)" if local != b + 1 else "")
        text = f"{block_text}, face {face} · {FACE_NAMES.get(face, '')}, {where}: {bc_id} · {what}"
        parts = []
        for copy in range(part.copies):
            payload = result.record(local, face, cm, cn, copy)[1:] if copy else lines[1:]
            values = bcfile.decode(result, bc_id, payload)
            if not values:
                continue
            shown = ", ".join(f"{k} = {v}" for k, v in values[:12])
            parts.append(shown if part.copies == 1 else f"[{copy + 1}] {shown}")
            if len(parts) == 3 and part.copies > 3:
                parts.append(f"… {part.copies - 3} more")
                break
        return text + (" — " + "; ".join(parts) if parts else "")
