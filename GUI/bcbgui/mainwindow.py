"""Main window for the BCB boundary-condition setup GUI."""

from __future__ import annotations

import os

from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QSplitter, QTreeWidget, QTreeWidgetItem,
    QPushButton, QComboBox, QLineEdit, QLabel, QGroupBox, QFormLayout,
    QTabWidget, QListWidget, QListWidgetItem, QTableWidget, QTableWidgetItem,
    QPlainTextEdit, QFileDialog, QMessageBox, QToolBar, QHeaderView,
    QInputDialog, QCheckBox,
)
from PyQt6.QtCore import Qt, QSettings

from . import mesh_io
from . import faces as facemod
from . import theme as thememod
from .bcmodel import BCBDocument, BCSection, KEYWORD_BCS, TYPED_BCS, ATLAS_PARAM_KEYS
from .viewport import MeshViewport, UNASSIGNED_COLOR

# Fixed hues for the keyword BCs; sections rotate through SECTION_PALETTE.
KEYWORD_COLORS = {
    "symmetry": "#6b7b8c",
    "outlet": "#4a90d9",
    "extrapolation": "#e67e22",
    "connection": "#1abc9c",
    "chimera": "#9b59b6",
    "null": "#3a4652",
    "axisymmetric": "#8e6f4e",
}
SECTION_PALETTE = [
    "#e05c5c", "#5cb87a", "#f5a623", "#3498db", "#e84393",
    "#2ecc71", "#e67e22", "#00b8d4", "#c0392b", "#8e44ad",
]
# Distinct colour per block, used in the "Color by block index" mode.
BLOCK_PALETTE = [
    "#4a90d9", "#e05c5c", "#5cb87a", "#f5a623", "#9b59b6",
    "#1abc9c", "#e84393", "#e67e22", "#3498db", "#2ecc71",
    "#c0392b", "#16a085", "#8e44ad", "#d35400", "#2980b9",
]

class BCBMainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.doc = BCBDocument()
        self.blocks = []
        self.mesh_path = None
        self.ini_path = None
        self._editing_section = None  # name currently loaded in the section editor
        self._name_colors = {}
        self.color_mode = "bc"        # "bc" or "block"

        self.settings = QSettings("ATLAS", "BCB-GUI")
        self._theme_name = self.settings.value("theme", thememod.DEFAULT_THEME)
        if self._theme_name not in thememod.THEMES:
            self._theme_name = thememod.DEFAULT_THEME
        self._theme = thememod.get_theme(self._theme_name)

        self.setWindowTitle("ATLAS BCB - Boundary Condition Setup")
        self.setGeometry(60, 50, 1600, 940)
        self.setStyleSheet(thememod.build_stylesheet(self._theme))
        self._build_ui()
        self.viewport.apply_theme(self._theme)
        self._refresh_all()

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.addWidget(self._build_toolbar())

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.addWidget(self._build_left_panel())
        splitter.addWidget(self._build_center_panel())
        splitter.addWidget(self._build_right_panel())
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)
        splitter.setSizes([320, 900, 400])
        root.addWidget(splitter)

    def _build_toolbar(self):
        bar = QToolBar()
        for text, slot, role in [
            ("Load Mesh", self.load_mesh_dialog, "primary"),
            ("Open INI", self.open_ini_dialog, None),
            ("Save INI", self.save_ini, "primary"),
            ("Save As", self.save_ini_as, None),
        ]:
            btn = QPushButton(text)
            if role:
                btn.setProperty("role", role)
            btn.clicked.connect(slot)
            bar.addWidget(btn)

        bar.addSeparator()
        for text, slot in [
            ("Iso", lambda: self.viewport.view_isometric()),
            ("XY", lambda: self.viewport.view_xy()),
            ("XZ", lambda: self.viewport.view_xz()),
            ("YZ", lambda: self.viewport.view_yz()),
            ("Fit", lambda: self.viewport.reset_camera()),
        ]:
            b = QPushButton(text)
            b.clicked.connect(slot)
            bar.addWidget(b)

        self.labels_chk = QCheckBox("Labels")
        self.labels_chk.setChecked(True)
        self.labels_chk.toggled.connect(self._on_labels_toggled)
        bar.addWidget(self.labels_chk)

        self.reveal_chk = QCheckBox("Auto-reveal")
        self.reveal_chk.setChecked(True)
        self.reveal_chk.setToolTip(
            "Make surrounding geometry transparent so a selected face stays "
            "visible even when it is covered by another block or face.")
        self.reveal_chk.toggled.connect(
            lambda on: self.viewport.set_auto_reveal(on))
        bar.addWidget(self.reveal_chk)

        bar.addWidget(QLabel(" Colour: "))
        self.color_combo = QComboBox()
        self.color_combo.addItem("By BC", "bc")
        self.color_combo.addItem("By block index", "block")
        self.color_combo.currentIndexChanged.connect(self._on_color_mode_changed)
        bar.addWidget(self.color_combo)

        bar.addWidget(QLabel(" Theme: "))
        self.theme_combo = QComboBox()
        for name in thememod.THEMES:
            self.theme_combo.addItem(name, name)
        idx = self.theme_combo.findData(self._theme_name)
        if idx >= 0:
            self.theme_combo.setCurrentIndex(idx)
        self.theme_combo.currentIndexChanged.connect(self._on_theme_changed)
        bar.addWidget(self.theme_combo)

        self.status = QLabel("No mesh loaded")
        self.status.setProperty("role", "muted")
        self.status.setStyleSheet("padding:0 10px;")
        bar.addWidget(self.status)
        return bar

    def _build_left_panel(self):
        group = QGroupBox("Blocks && Faces")
        lay = QVBoxLayout(group)
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["Block / Face", "Assigned", "Ghost"])
        self.tree.setColumnWidth(0, 170)
        self.tree.setColumnWidth(1, 110)
        self.tree.setColumnWidth(2, 44)
        self.tree.header().setToolTip(
            "Column 1 checkbox: show/hide block. 'Ghost' checkbox: make block "
            "transparent.")
        self.tree.currentItemChanged.connect(self._on_tree_selection)
        self.tree.itemChanged.connect(self._on_tree_item_changed)
        lay.addWidget(self.tree)
        hint = QLabel("Tip: click a face in the 3-D view or here, then assign a BC.")
        hint.setWordWrap(True)
        hint.setProperty("role", "muted")
        lay.addWidget(hint)
        return group

    def _build_center_panel(self):
        container = QWidget()
        lay = QVBoxLayout(container)
        lay.setContentsMargins(0, 0, 0, 0)
        self.viewport = MeshViewport()
        self.viewport.face_picked.connect(self._on_face_picked)
        lay.addWidget(self.viewport)
        return container

    def _build_right_panel(self):
        tabs = QTabWidget()
        tabs.addTab(self._build_assign_tab(), "Assign")
        tabs.addTab(self._build_sections_tab(), "Build")
        tabs.addTab(self._build_globals_tab(), "Global")
        tabs.addTab(self._build_preview_tab(), "INI Preview")
        self.right_tabs = tabs
        return tabs

    def _build_assign_tab(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        intro = QLabel(
            "Apply a boundary condition to the selected face. Choose a no-input "
            "keyword BC below, or a BC you defined in the Build tab.")
        intro.setWordWrap(True)
        intro.setProperty("role", "muted")
        lay.addWidget(intro)

        self.sel_label = QLabel("No face selected")
        self.sel_label.setStyleSheet("font-weight:700;")
        lay.addWidget(self.sel_label)

        form = QFormLayout()
        self.assign_combo = QComboBox()
        self.assign_combo.currentIndexChanged.connect(self._on_assign_combo)
        form.addRow("Assign BC:", self.assign_combo)
        lay.addLayout(form)

        lay.addWidget(QLabel("Quick keyword BCs (no input required):"))
        grid = QHBoxLayout()
        self._kw_wrap = QVBoxLayout()
        row = QHBoxLayout()
        for i, kw in enumerate(KEYWORD_BCS):
            b = QPushButton(kw)
            b.clicked.connect(lambda _=False, k=kw: self._assign_current(k))
            row.addWidget(b)
            if (i + 1) % 2 == 0:
                self._kw_wrap.addLayout(row)
                row = QHBoxLayout()
        if row.count():
            self._kw_wrap.addLayout(row)
        lay.addLayout(self._kw_wrap)

        btn_clear = QPushButton("Clear assignment")
        btn_clear.setProperty("role", "danger")
        btn_clear.clicked.connect(lambda: self._assign_current(None))
        lay.addWidget(btn_clear)
        lay.addStretch()
        return w

    def _build_sections_tab(self):
        w = QWidget()
        lay = QVBoxLayout(w)

        intro = QLabel(
            "Define BCs that need input (a type plus parameters). Each one you "
            "build here becomes selectable in the Assign tab.")
        intro.setWordWrap(True)
        intro.setProperty("role", "muted")
        lay.addWidget(intro)

        self.sections_list = QListWidget()
        self.sections_list.currentItemChanged.connect(self._on_section_selected)
        self.sections_list.itemDoubleClicked.connect(
            lambda _it: self._assign_current(self._current_section_name()))
        lay.addWidget(self.sections_list)

        btn_row = QHBoxLayout()
        for text, slot, role in [
            ("New", self._new_section, "primary"),
            ("Duplicate", self._duplicate_section, None),
            ("Rename", self._rename_section, None),
            ("Delete", self._delete_section, "danger"),
        ]:
            b = QPushButton(text)
            if role:
                b.setProperty("role", role)
            b.clicked.connect(slot)
            btn_row.addWidget(b)
        lay.addLayout(btn_row)

        editor = QGroupBox("BC definition")
        eform = QVBoxLayout(editor)
        f = QFormLayout()
        self.sec_type_combo = QComboBox()
        self.sec_type_combo.setEditable(True)
        self.sec_type_combo.addItems(list(TYPED_BCS.keys()))
        self.sec_type_combo.currentTextChanged.connect(self._on_section_type_changed)
        f.addRow("type:", self.sec_type_combo)
        eform.addLayout(f)

        self.param_table = QTableWidget(0, 2)
        self.param_table.setHorizontalHeaderLabels(["key", "value"])
        self.param_table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.param_table.cellChanged.connect(lambda *_: self._commit_section_editor())
        eform.addWidget(self.param_table)

        prow = QHBoxLayout()
        self.suggest_combo = QComboBox()
        self.suggest_combo.setEditable(True)   # type a custom key too
        self.suggest_combo.setToolTip(
            "Pick a suggested key or type any key name, then Add key.")
        prow.addWidget(self.suggest_combo)
        b_add = QPushButton("Add key")
        b_add.clicked.connect(self._add_param_row)
        prow.addWidget(b_add)
        b_custom = QPushButton("Add blank")
        b_custom.setToolTip("Add an empty row to type a key and value freely.")
        b_custom.clicked.connect(self._add_blank_param_row)
        prow.addWidget(b_custom)
        b_del = QPushButton("Remove key")
        b_del.setProperty("role", "danger")
        b_del.clicked.connect(self._remove_param_row)
        prow.addWidget(b_del)
        eform.addLayout(prow)

        assign_btn = QPushButton("Assign this BC to selected face")
        assign_btn.setProperty("role", "primary")
        assign_btn.clicked.connect(
            lambda: self._assign_current(self._current_section_name()))
        eform.addWidget(assign_btn)

        lay.addWidget(editor)
        return w

    def _build_globals_tab(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.addWidget(QLabel("[ATLAS-Parameters]"))
        self.param_global = QTableWidget(0, 2)
        self.param_global.setHorizontalHeaderLabels(["key", "value"])
        self.param_global.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.param_global.cellChanged.connect(lambda *_: self._commit_globals())
        lay.addWidget(self.param_global)

        prow = QHBoxLayout()
        self.global_suggest = QComboBox()
        self.global_suggest.addItems(ATLAS_PARAM_KEYS)
        prow.addWidget(self.global_suggest)
        b_add = QPushButton("Add key")
        b_add.clicked.connect(self._add_global_row)
        prow.addWidget(b_add)
        b_del = QPushButton("Remove key")
        b_del.setProperty("role", "danger")
        b_del.clicked.connect(self._remove_global_row)
        prow.addWidget(b_del)
        lay.addLayout(prow)
        lay.addStretch()
        return w

    def _build_preview_tab(self):
        w = QWidget()
        lay = QVBoxLayout(w)
        self.preview = QPlainTextEdit()
        self.preview.setReadOnly(True)
        lay.addWidget(self.preview)
        return w

    # -------------------------------------------------------------- colours
    def _rebuild_colors(self):
        self._name_colors = {}
        idx = 0
        for name in self.doc.referenced_sections():
            self._name_colors[name] = SECTION_PALETTE[idx % len(SECTION_PALETTE)]
            idx += 1

    def color_for(self, name):
        if not name:
            return self._theme["unassigned"]
        if name in KEYWORD_COLORS:
            return KEYWORD_COLORS[name]
        return self._name_colors.get(name, "#7f8c8d")

    # ------------------------------------------------------------ file ops
    def load_mesh_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Load mesh",
            os.path.dirname(self.mesh_path) if self.mesh_path else "",
            "Meshes (*.tec *.dat *.p3d *.xyz *.g *.grd *.plt);;All files (*)")
        if path:
            self.load_mesh(path)

    def load_mesh(self, path):
        try:
            blocks = mesh_io.read_mesh(path)
        except Exception as exc:
            QMessageBox.critical(self, "Load failed", f"Could not read mesh:\n{exc}")
            return
        self.blocks = blocks
        self.mesh_path = path
        ndims = [4 if b.is_2d else 6 for b in blocks]
        self.doc.set_blocks(ndims)
        self.viewport.set_mesh(blocks)
        self.status.setText(
            f"{os.path.basename(path)} - {len(blocks)} block(s)")
        self._refresh_all()

    def open_ini_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open BCB INI", "", "INI files (*.ini);;All files (*)")
        if path:
            self.open_ini(path)

    def open_ini(self, path):
        try:
            with open(path) as fh:
                text = fh.read()
        except OSError as exc:
            QMessageBox.critical(self, "Open failed", str(exc))
            return
        new_doc = BCBDocument.from_ini(text)
        if self.blocks:
            if new_doc.nblocks != len(self.blocks):
                QMessageBox.warning(
                    self, "Block count mismatch",
                    f"INI defines {new_doc.nblocks} block(s) but the loaded mesh "
                    f"has {len(self.blocks)}. Assignments applied where they fit.")
            # Keep mesh-derived geometry; copy over assignments/sections/params.
            new_doc.set_blocks([4 if b.is_2d else 6 for b in self.blocks])
        self.doc = new_doc
        self.ini_path = path
        self._refresh_all()

    def save_ini(self):
        if not self.ini_path:
            return self.save_ini_as()
        self._commit_section_editor()
        self._commit_globals()
        missing = self.doc.unassigned_faces()
        if missing and not self._confirm_missing(missing):
            return
        try:
            with open(self.ini_path, "w") as fh:
                fh.write(self.doc.to_ini())
        except OSError as exc:
            QMessageBox.critical(self, "Save failed", str(exc))
            return
        self.status.setText(f"Saved {os.path.basename(self.ini_path)}")

    def save_ini_as(self):
        start = self.ini_path or (
            os.path.join(os.path.dirname(self.mesh_path), "input.ini")
            if self.mesh_path else "input.ini")
        path, _ = QFileDialog.getSaveFileName(
            self, "Save BCB INI", start, "INI files (*.ini);;All files (*)")
        if path:
            self.ini_path = path
            self.save_ini()

    def _confirm_missing(self, missing):
        preview = ", ".join(f"Block{b + 1}.face{f}" for b, f in missing[:8])
        if len(missing) > 8:
            preview += ", ..."
        reply = QMessageBox.question(
            self, "Unassigned faces",
            f"{len(missing)} face(s) have no BC assigned "
            f"(BCB will error on these):\n{preview}\n\nSave anyway?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        return reply == QMessageBox.StandardButton.Yes

    # --------------------------------------------------------------- refresh
    def _refresh_all(self):
        self._rebuild_colors()
        self._refresh_tree()
        self._refresh_sections_list()
        self._refresh_globals_table()
        self._refresh_viewport_colors()
        self._refresh_preview()
        self._refresh_assign_combo()

    def _refresh_tree(self):
        self.tree.blockSignals(True)
        self.tree.clear()
        for b in range(self.doc.nblocks):
            block = self.blocks[b] if b < len(self.blocks) else None
            dims = f"  {block.dims}" if block else ""
            top = QTreeWidgetItem([f"Block{b + 1}{dims}", "", ""])
            top.setFlags(top.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            top.setCheckState(0, Qt.CheckState.Checked)
            ghost = self.viewport.block_opacity.get(b, 1.0) < 1.0 \
                if hasattr(self, "viewport") else False
            top.setCheckState(
                2, Qt.CheckState.Checked if ghost else Qt.CheckState.Unchecked)
            top.setData(0, Qt.ItemDataRole.UserRole, ("block", b))
            self.tree.addTopLevelItem(top)
            for f in sorted(self.doc.block_faces[b]):
                val = self.doc.face_value(b, f) or ""
                label = f"face{f}  ({facemod.FACE_LABELS[f]})"
                child = QTreeWidgetItem([label, val])
                child.setData(0, Qt.ItemDataRole.UserRole, ("face", b, f))
                child.setForeground(1, self._brush(self.color_for(val or None)))
                top.addChild(child)
            top.setExpanded(True)
        self.tree.blockSignals(False)

    def _brush(self, hexcolor):
        from PyQt6.QtGui import QBrush, QColor
        return QBrush(QColor(hexcolor))

    def _refresh_sections_list(self):
        cur = self._current_section_name()
        self.sections_list.blockSignals(True)
        self.sections_list.clear()
        for name in self.doc.sections:
            item = QListWidgetItem(f"{name}  [{self.doc.sections[name].type}]")
            item.setData(Qt.ItemDataRole.UserRole, name)
            self.sections_list.addItem(item)
        self.sections_list.blockSignals(False)
        if cur:
            self._select_section_in_list(cur)

    def _refresh_globals_table(self):
        self.param_global.blockSignals(True)
        self.param_global.setRowCount(0)
        for k, v in self.doc.parameters.items():
            self._table_append(self.param_global, k, v)
        self.param_global.blockSignals(False)

    def _on_color_mode_changed(self, _idx):
        self.color_mode = self.color_combo.currentData()
        self._refresh_viewport_colors()

    def _on_theme_changed(self, _idx):
        name = self.theme_combo.currentData()
        self.apply_theme(name)

    def apply_theme(self, name):
        self._theme_name = name
        self._theme = thememod.get_theme(name)
        self.setStyleSheet(thememod.build_stylesheet(self._theme))
        self.viewport.apply_theme(self._theme)
        # Repaint unassigned face fills (and assigned ones) for the new theme.
        self._refresh_viewport_colors()
        self.settings.setValue("theme", name)

    def _face_display_color(self, b, val):
        if self.color_mode == "block":
            return BLOCK_PALETTE[b % len(BLOCK_PALETTE)]
        return self.color_for(val)

    def _refresh_viewport_colors(self):
        if not self.blocks:
            return
        label_map = {}
        for b in range(self.doc.nblocks):
            for f in self.doc.block_faces[b]:
                if (b, f) in self.viewport.face_actors:
                    val = self.doc.face_value(b, f)
                    self.viewport.set_face_color(b, f, self._face_display_color(b, val))
                    if val:
                        label_map[(b, f)] = val
        self.viewport.update_labels(label_map)

    def _refresh_preview(self):
        self.preview.setPlainText(self.doc.to_ini())

    def _refresh_assign_combo(self):
        self.assign_combo.blockSignals(True)
        self.assign_combo.clear()
        self.assign_combo.addItem("(unassigned)", None)
        for kw in KEYWORD_BCS:
            self.assign_combo.addItem(kw, kw)
        for name in self.doc.sections:
            self.assign_combo.addItem(f"{name}  [section]", name)
        self.assign_combo.blockSignals(False)
        self._sync_assign_combo()

    # ---------------------------------------------------------- selection
    def _selected_face(self):
        item = self.tree.currentItem()
        if item is None:
            return None
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if data and data[0] == "face":
            return data[1], data[2]
        return None

    def _on_tree_selection(self, current, _prev):
        if current is None:
            return
        data = current.data(0, Qt.ItemDataRole.UserRole)
        if data and data[0] == "face":
            b, f = data[1], data[2]
            self.viewport.select_face(b, f)
            self._update_assign_panel(b, f)

    def _on_tree_item_changed(self, item, column):
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not (data and data[0] == "block"):
            return
        if column == 0:
            visible = item.checkState(0) == Qt.CheckState.Checked
            self.viewport.set_block_visible(data[1], visible)
            self._refresh_viewport_colors()
        elif column == 2:
            ghost = item.checkState(2) == Qt.CheckState.Checked
            self.viewport.set_block_ghost(data[1], ghost)

    def _on_face_picked(self, b, f):
        # Sync the tree selection to the picked face.
        for i in range(self.tree.topLevelItemCount()):
            top = self.tree.topLevelItem(i)
            for j in range(top.childCount()):
                child = top.child(j)
                data = child.data(0, Qt.ItemDataRole.UserRole)
                if data == ("face", b, f):
                    self.tree.setCurrentItem(child)
                    self._update_assign_panel(b, f)
                    return

    def _update_assign_panel(self, b, f):
        val = self.doc.face_value(b, f)
        self.sel_label.setText(
            f"Block{b + 1} . face{f}  ({facemod.FACE_LABELS[f]})"
            f"  ->  {val or '(unassigned)'}")
        self._sync_assign_combo()

    def _sync_assign_combo(self):
        sel = self._selected_face()
        self.assign_combo.blockSignals(True)
        if sel is None:
            self.assign_combo.setCurrentIndex(0)
        else:
            val = self.doc.face_value(*sel)
            idx = self.assign_combo.findData(val)
            self.assign_combo.setCurrentIndex(idx if idx >= 0 else 0)
        self.assign_combo.blockSignals(False)

    # ---------------------------------------------------------- assignment
    def _on_assign_combo(self, _idx):
        sel = self._selected_face()
        if sel is None:
            return
        name = self.assign_combo.currentData()
        self._assign(sel[0], sel[1], name)

    def _assign_current(self, name):
        sel = self._selected_face()
        if sel is None:
            QMessageBox.information(self, "No face", "Select a face first.")
            return
        self._assign(sel[0], sel[1], name)

    def _assign(self, b, f, name):
        self.doc.assign(b, f, name)
        self._rebuild_colors()
        # Update just the affected row + viewport, then preview.
        item = self.tree.currentItem()
        if item is not None:
            item.setText(1, name or "")
            item.setForeground(1, self._brush(self.color_for(name)))
        self._refresh_viewport_colors()
        self._refresh_preview()
        self._update_assign_panel(b, f)

    # ------------------------------------------------------------ sections
    def _current_section_name(self):
        item = self.sections_list.currentItem()
        return item.data(Qt.ItemDataRole.UserRole) if item else None

    def _select_section_in_list(self, name):
        for i in range(self.sections_list.count()):
            it = self.sections_list.item(i)
            if it.data(Qt.ItemDataRole.UserRole) == name:
                self.sections_list.setCurrentRow(i)
                return

    def _new_section(self):
        name, ok = QInputDialog.getText(self, "New BC section", "Section name:")
        name = name.strip()
        if not ok or not name:
            return
        if name in self.doc.sections or name in KEYWORD_BCS:
            QMessageBox.warning(self, "Name in use", f"'{name}' is already used.")
            return
        self.doc.add_section(BCSection(name, "wall"))
        self._refresh_sections_list()
        self._refresh_assign_combo()
        self._select_section_in_list(name)
        self._refresh_preview()

    def _duplicate_section(self):
        name = self._current_section_name()
        if not name:
            return
        new = f"{name}_copy"
        i = 2
        while new in self.doc.sections:
            new = f"{name}_copy{i}"; i += 1
        self.doc.add_section(self.doc.sections[name].clone_as(new))
        self._refresh_sections_list()
        self._refresh_assign_combo()
        self._select_section_in_list(new)
        self._refresh_preview()

    def _rename_section(self):
        old = self._current_section_name()
        if not old:
            return
        new, ok = QInputDialog.getText(self, "Rename section", "New name:", text=old)
        new = new.strip()
        if not ok or not new or new == old:
            return
        if new in self.doc.sections or new in KEYWORD_BCS:
            QMessageBox.warning(self, "Name in use", f"'{new}' is already used.")
            return
        self.doc.rename_section(old, new)
        self._editing_section = new
        self._refresh_all()
        self._select_section_in_list(new)

    def _delete_section(self):
        name = self._current_section_name()
        if not name:
            return
        if QMessageBox.question(
                self, "Delete section",
                f"Delete '{name}' and clear it from any faces?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        ) != QMessageBox.StandardButton.Yes:
            return
        self.doc.remove_section(name)
        self._editing_section = None
        self._refresh_all()

    def _on_section_selected(self, current, _prev):
        self._commit_section_editor()
        name = current.data(Qt.ItemDataRole.UserRole) if current else None
        self._editing_section = name
        self._load_section_editor(name)

    def _load_section_editor(self, name):
        self.param_table.blockSignals(True)
        self.param_table.setRowCount(0)
        if name and name in self.doc.sections:
            sec = self.doc.sections[name]
            idx = self.sec_type_combo.findText(sec.type)
            self.sec_type_combo.blockSignals(True)
            if idx >= 0:
                self.sec_type_combo.setCurrentIndex(idx)
            else:
                self.sec_type_combo.setEditable(True)
                self.sec_type_combo.setCurrentText(sec.type)
            self.sec_type_combo.blockSignals(False)
            for k, v in sec.params.items():
                self._table_append(self.param_table, k, v)
        self.param_table.blockSignals(False)
        self._refresh_suggestions()

    def _on_section_type_changed(self, _text):
        self._commit_section_editor()
        self._refresh_suggestions()

    def _refresh_suggestions(self):
        self.suggest_combo.clear()
        keys = TYPED_BCS.get(self.sec_type_combo.currentText(), [])
        self.suggest_combo.addItems(keys)

    def _commit_section_editor(self):
        name = self._editing_section
        if not name or name not in self.doc.sections:
            return
        sec = self.doc.sections[name]
        sec.type = self.sec_type_combo.currentText().strip()
        from collections import OrderedDict
        params = OrderedDict()
        for r in range(self.param_table.rowCount()):
            k = self._cell(self.param_table, r, 0)
            v = self._cell(self.param_table, r, 1)
            if k:
                params[k] = v
        sec.params = params
        self._refresh_sections_list_label(name)
        self._refresh_preview()

    def _refresh_sections_list_label(self, name):
        for i in range(self.sections_list.count()):
            it = self.sections_list.item(i)
            if it.data(Qt.ItemDataRole.UserRole) == name:
                it.setText(f"{name}  [{self.doc.sections[name].type}]")
                return

    def _add_param_row(self):
        key = self.suggest_combo.currentText().strip()
        self._table_append(self.param_table, key, "")
        self._commit_section_editor()

    def _add_blank_param_row(self):
        # Empty row for a fully custom key/value; committed once a key is typed.
        self._table_append(self.param_table, "", "")

    def _remove_param_row(self):
        r = self.param_table.currentRow()
        if r >= 0:
            self.param_table.removeRow(r)
            self._commit_section_editor()

    # -------------------------------------------------------------- globals
    def _commit_globals(self):
        from collections import OrderedDict
        params = OrderedDict()
        for r in range(self.param_global.rowCount()):
            k = self._cell(self.param_global, r, 0)
            v = self._cell(self.param_global, r, 1)
            if k:
                params[k] = v
        self.doc.parameters = params
        self._refresh_preview()

    def _add_global_row(self):
        self._table_append(self.param_global, self.global_suggest.currentText(), "")
        self._commit_globals()

    def _remove_global_row(self):
        r = self.param_global.currentRow()
        if r >= 0:
            self.param_global.removeRow(r)
            self._commit_globals()

    # --------------------------------------------------------------- labels
    def _on_labels_toggled(self, checked):
        label_map = {}
        for b in range(self.doc.nblocks):
            for f in self.doc.block_faces[b]:
                val = self.doc.face_value(b, f)
                if val:
                    label_map[(b, f)] = val
        self.viewport.set_labels_visible(checked, label_map)

    # --------------------------------------------------------------- helpers
    def _table_append(self, table, key, value):
        r = table.rowCount()
        table.insertRow(r)
        table.setItem(r, 0, QTableWidgetItem(str(key)))
        table.setItem(r, 1, QTableWidgetItem(str(value)))

    def _cell(self, table, r, c):
        it = table.item(r, c)
        return it.text().strip() if it else ""

    def closeEvent(self, event):
        self.viewport.close()
        super().closeEvent(event)
