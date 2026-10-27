"""The Boundaries stage: the BCB part of the case.

Left: the blocks and faces of the mesh.  Centre: the 3-D view, where a face is
picked with the mouse.  Right: what to assign to it, and the BCs that need
parameters.  The view controls live in the shell's header while this stage is
open (:meth:`BCBPanel.view_tools`).
"""

from __future__ import annotations

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QAbstractItemView, QComboBox, QDialog, QFormLayout, QFrame, QGridLayout,
    QGroupBox, QHBoxLayout, QHeaderView, QInputDialog, QLabel, QListWidget,
    QListWidgetItem, QMessageBox, QPushButton, QSplitter, QTableWidget,
    QTableWidgetItem, QTabWidget, QTreeWidget, QTreeWidgetItem, QVBoxLayout,
    QWidget,
)
from PyQt6.QtGui import QBrush, QColor, QFont, QIcon

from . import faces as facemod
from . import filekeys, icons, mesh_io
from .bcmodel import (
    BCSection, ENUM_KEY_VALUES, KEYWORD_BCS, TYPED_BCS, file_keys_of,
    suggested_keys,
)
from .bcbdialogs import NewBCDialog
from .filewidgets import FileColumn, FilesDialog
from .viewport import MeshViewport
from .widgets import Card

# Fixed hues for the keyword BCs; sections rotate through SECTION_PALETTE.
KEYWORD_COLORS = {
    "symmetry": "#7d8ea0",
    "outlet": "#4a90d9",
    "extrapolation": "#e67e22",
    "connection": "#1abc9c",
    "chimera": "#9b59b6",
    "null": "#5a6676",
    "axisymmetric": "#a8805a",
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

UNSET_TEXT = "—"          # em dash shown for an unassigned face


class BCBPanel(QWidget):
    """Mesh view and boundary-condition assignment."""

    changed = pyqtSignal()

    def __init__(self, shell):
        super().__init__()
        self.shell = shell
        self.kit = shell.kit
        self.blocks = []
        self.mesh_path = None
        self._editing_section = None   # name loaded in the section editor
        self._name_colors = {}
        self.color_mode = "bc"         # "bc" or "block"
        self._build_ui()

    @property
    def doc(self):
        return self.shell.doc.bcb

    @property
    def theme(self):
        return self.kit.theme

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(9)
        splitter.addWidget(self._build_left_panel())
        splitter.addWidget(self._build_center_panel())
        splitter.addWidget(self._build_right_panel())
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setStretchFactor(2, 0)
        splitter.setSizes([self.kit.px(340), self.kit.px(800), self.kit.px(520)])
        root.addWidget(splitter)

    def view_tools(self):
        """The viewport controls, shown in the shell header for this stage."""
        bar = QWidget()
        kit = self.kit
        lay = QHBoxLayout(bar)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(8)

        views = [("Iso", lambda: self.viewport.view_isometric(), "left"),
                 ("XY", lambda: self.viewport.view_xy(), "mid"),
                 ("XZ", lambda: self.viewport.view_xz(), "mid"),
                 ("YZ", lambda: self.viewport.view_yz(), "right")]
        seg = QHBoxLayout()
        seg.setSpacing(0)
        for text, slot, pos in views:
            seg.addWidget(kit.button(text, slot, None, None, seg=pos,
                                     tip=f"{text} view"))
        lay.addLayout(seg)
        lay.addWidget(kit.button("Fit", lambda: self.viewport.reset_camera(),
                                 "fit", "ghost", tip="Fit the mesh in the view",
                                 compactable=True))
        lay.addWidget(kit.vdivider())

        self.labels_chk = kit.toggle(
            "Labels", self._on_labels_toggled, "tag", True,
            tip="Show the BC name on every assigned face.")
        lay.addWidget(self.labels_chk)
        self.reveal_chk = kit.toggle(
            "Auto-reveal", lambda on: self.viewport.set_auto_reveal(on), "eye",
            True,
            tip="Make surrounding geometry transparent so a selected face "
                "stays visible even when it is covered by another block.")
        lay.addWidget(self.reveal_chk)

        self.color_combo = QComboBox()
        self.color_combo.addItem("By BC", "bc")
        self.color_combo.addItem("By block index", "block")
        self.color_combo.setToolTip("How faces are coloured in the 3-D view.")
        kit.sized(self.color_combo.setMinimumWidth, 130)
        self.color_combo.currentIndexChanged.connect(self._on_color_mode_changed)
        group = QHBoxLayout()
        group.setSpacing(6)
        group.addWidget(kit.icon_label("palette", "muted", 16))
        group.addWidget(kit.section_label("Colour", compactable=True))
        group.addWidget(self.color_combo)
        lay.addLayout(group)
        return bar

    def _build_left_panel(self):
        card = Card()
        kit = self.kit
        self.tree_badge = kit.badge("0")
        card.body.addLayout(
            kit.panel_header("layers", "BLOCKS & FACES", self.tree_badge))

        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["BLOCK / FACE", "ASSIGNED", "GHOST"])
        self.tree.setColumnWidth(1, 120)
        self.tree.setColumnWidth(2, 58)
        self.tree.setIndentation(14)
        self.tree.setUniformRowHeights(True)
        self.tree.setAlternatingRowColors(False)
        header = self.tree.header()
        header.setStretchLastSection(False)
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        header.setToolTip(
            "Column 1 checkbox: show/hide block. 'Ghost' checkbox: make block "
            "transparent.")
        self.tree.currentItemChanged.connect(self._on_tree_selection)
        self.tree.itemChanged.connect(self._on_tree_item_changed)
        card.body.addWidget(self.tree, 1)
        card.body.addWidget(kit.hint(
            "Click a face in the 3-D view or here, then assign a BC."))
        return card

    def _build_center_panel(self):
        frame = QFrame()
        frame.setObjectName("ViewportFrame")
        lay = QVBoxLayout(frame)
        lay.setContentsMargins(3, 3, 3, 3)
        self.viewport = MeshViewport()
        self.viewport.face_picked.connect(self._on_face_picked)
        lay.addWidget(self.viewport)
        return frame

    def _build_right_panel(self):
        card = Card(margins=(4, 2, 4, 4))
        tabs = QTabWidget()
        tabs.setDocumentMode(True)
        for widget, label, ico in [
            (self.kit.scrollable(self._build_assign_tab()), "Assign", "target"),
            (self.kit.scrollable(self._build_sections_tab()), "Build", "cube"),
        ]:
            index = tabs.addTab(widget, label)
            self.kit.register_icon(
                lambda ic, i=index, tw=tabs: tw.setTabIcon(i, ic), ico, "muted", 16)
        self.right_tabs = tabs
        card.body.addWidget(tabs)
        return card

    # -- assign tab ------------------------------------------------------
    def _build_assign_tab(self):
        w = QWidget()
        kit = self.kit
        lay = QVBoxLayout(w)
        lay.setContentsMargins(10, 12, 10, 10)
        lay.setSpacing(10)

        sel = QFrame()
        sel.setObjectName("SelCard")
        sl = QVBoxLayout(sel)
        sl.setContentsMargins(13, 11, 13, 12)
        sl.setSpacing(5)
        top = QHBoxLayout()
        top.setSpacing(8)
        top.addWidget(kit.icon_label("target", "accent", 17))
        self.sel_kind = kit.section_label("SELECTED FACE")
        top.addWidget(self.sel_kind)
        top.addStretch(1)
        sl.addLayout(top)
        self.sel_label = kit.title("No face selected")
        sl.addWidget(self.sel_label)
        self.sel_bc = QLabel("Click a face in the 3-D view")
        self.sel_bc.setProperty("role", "muted")
        sl.addWidget(self.sel_bc)

        # Shown when a block (not a face) is selected: which GPB phases live
        # in it, the one key that ties the two stages together.
        self.block_box = QWidget()
        block_layout = QVBoxLayout(self.block_box)
        block_layout.setContentsMargins(0, 6, 0, 0)
        block_layout.setSpacing(6)
        block_layout.addWidget(kit.section_label("PHASES IN THIS BLOCK"))
        self.phase_chips = QHBoxLayout()
        self.phase_chips.setSpacing(6)
        block_layout.addLayout(self.phase_chips)
        self.block_hint = QLabel("")
        self.block_hint.setProperty("role", "hint")
        self.block_hint.setWordWrap(True)
        block_layout.addWidget(self.block_hint)
        self.block_box.setVisible(False)
        sl.addWidget(self.block_box)
        lay.addWidget(sel)

        self.assign_caption = kit.section_label("ASSIGN BC")
        lay.addWidget(self.assign_caption)
        self.assign_combo = QComboBox()
        self.assign_combo.currentIndexChanged.connect(self._on_assign_combo)
        lay.addWidget(self.assign_combo)

        lay.addWidget(kit.section_label(
            "QUICK KEYWORD BCS · NO INPUT REQUIRED"))
        grid = QGridLayout()
        grid.setHorizontalSpacing(8)
        grid.setVerticalSpacing(8)
        self._face_only = []
        for i, kw in enumerate(KEYWORD_BCS):
            b = QPushButton("  " + kw)
            self._face_only.append(b)
            b.setProperty("role", "chip")
            b.setIcon(icons.dot(KEYWORD_COLORS.get(kw, "#7f8c8d"), 11))
            b.setToolTip(f"Assign '{kw}' to the selected face")
            b.clicked.connect(lambda _=False, k=kw: self._assign_current(k))
            grid.addWidget(b, i // 2, i % 2)
        lay.addLayout(grid)

        clear_button = kit.button(
            "Clear assignment", lambda: self._assign_current(None), "trash",
            "danger", tip="Remove the BC from the selected face")
        self._face_only.append(clear_button)
        lay.addWidget(clear_button)
        lay.addWidget(kit.hint(
            "Pick a keyword BC above, or a BC you defined in the Build tab."))

        lay.addLayout(kit.panel_header("palette", "BCS IN USE"))
        self.legend_list = QListWidget()
        self.legend_list.setSelectionMode(
            QAbstractItemView.SelectionMode.NoSelection)
        self.legend_list.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.legend_list.setToolTip(
            "Colour key for the 3-D view, with the number of faces using each BC.")
        lay.addWidget(self.legend_list, 1)
        return w

    # -- build tab -------------------------------------------------------
    def _build_sections_tab(self):
        w = QWidget()
        kit = self.kit
        lay = QVBoxLayout(w)
        lay.setContentsMargins(10, 12, 10, 10)
        lay.setSpacing(9)

        self.sections_badge = kit.badge("0")
        lay.addLayout(kit.panel_header("cube", "DEFINED BCS", self.sections_badge))

        self.sections_list = QListWidget()
        kit.sized(self.sections_list.setMinimumHeight, 120)
        self.sections_list.currentItemChanged.connect(self._on_section_selected)
        self.sections_list.itemDoubleClicked.connect(
            lambda _it: self._assign_current(self._current_section_name()))
        self.sections_list.setToolTip(
            "Double-click a BC to assign it to the selected face.")
        lay.addWidget(self.sections_list, 1)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(7)
        for text, slot, ico, role in [
            ("New", self._new_section, "plus", "primary"),
            ("Duplicate", self._duplicate_section, "copy", None),
            ("Rename", self._rename_section, "pencil", None),
            ("Delete", self._delete_section, "trash", "danger"),
        ]:
            btn_row.addWidget(kit.button(text, slot, ico, role,
                                         compactable=True))
        lay.addLayout(btn_row)

        editor = QGroupBox("BC DEFINITION")
        eform = QVBoxLayout(editor)
        eform.setSpacing(9)
        f = QFormLayout()
        f.setContentsMargins(0, 0, 0, 0)
        self.sec_type_combo = QComboBox()
        self.sec_type_combo.setEditable(True)
        self.sec_type_combo.addItems(list(TYPED_BCS.keys()))
        self.sec_type_combo.currentTextChanged.connect(self._on_section_type_changed)
        f.addRow("type:", self.sec_type_combo)
        eform.addLayout(f)

        self.param_table = QTableWidget(0, 2)
        self.param_table.setHorizontalHeaderLabels(["KEY", "VALUE"])
        self.param_table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.param_table.verticalHeader().setVisible(False)
        kit.table_rows(self.param_table)
        self.param_table.setShowGrid(False)
        self.param_table.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows)
        self.param_table.cellChanged.connect(lambda *_: self._commit_section_editor())
        self.file_column = FileColumn(
            self.param_table, kit, "bc-section",
            lambda: self.shell.case_dir, self._commit_section_editor)
        eform.addWidget(self.param_table, 1)

        prow = QHBoxLayout()
        prow.setSpacing(7)
        self.suggest_combo = QComboBox()
        self.suggest_combo.setEditable(True)
        self.suggest_combo.setToolTip(
            "Pick a suggested key or type any key name, then Add key.")
        prow.addWidget(self.suggest_combo, 1)
        prow.addWidget(kit.button("Add key", self._add_param_row, "plus",
                                  compactable=True))
        prow.addWidget(kit.button("Remove", self._remove_param_row, "trash",
                                  "danger", tip="Remove the selected key",
                                  compactable=True))
        eform.addLayout(prow)
        eform.addWidget(kit.button(
            "Files of this BC…", self._open_files_dialog, "file",
            tip="Every key of this boundary condition that takes a file: "
                "tables, time series, CEA decks."))
        eform.addWidget(kit.button(
            "Assign this BC to selected face",
            lambda: self._assign_current(self._current_section_name()),
            "check", "primary"))
        lay.addWidget(editor, 2)
        return w

    # -------------------------------------------------------------- colours
    def _rebuild_colors(self):
        self._name_colors = {}
        for idx, name in enumerate(self.doc.referenced_sections()):
            self._name_colors[name] = SECTION_PALETTE[idx % len(SECTION_PALETTE)]

    def color_for(self, name):
        if not name:
            return self.theme["unassigned"]
        if name in KEYWORD_COLORS:
            return KEYWORD_COLORS[name]
        return self._name_colors.get(name, "#7f8c8d")

    # ------------------------------------------------------------ mesh I/O
    def load_mesh(self, path):
        try:
            blocks = mesh_io.read_mesh(path)
        except Exception as exc:
            QMessageBox.critical(self, "Load failed", f"Could not read mesh:\n{exc}")
            return False
        self.blocks = blocks
        self.mesh_path = path
        self.doc.set_blocks([4 if b.is_2d else 6 for b in blocks])
        self.viewport.set_mesh(blocks)
        self.refresh()
        self.changed.emit()
        return True

    def sync_blocks_to_mesh(self):
        """After loading an INI, keep the mesh-derived block geometry."""
        if self.blocks:
            self.doc.set_blocks([4 if b.is_2d else 6 for b in self.blocks])

    # --------------------------------------------------------------- refresh
    def refresh(self):
        self._rebuild_colors()
        self._refresh_tree()
        self._refresh_sections_list()
        self._refresh_viewport_colors()
        self._refresh_assign_combo()
        self._refresh_legend()

    def _face_row_text(self, item, name):
        item.setText(1, name or UNSET_TEXT)
        item.setIcon(1, icons.dot(self.color_for(name), 11) if name else QIcon())
        item.setForeground(
            1, self._brush(self.theme["text_dim"] if name else self.theme["muted"]))

    def _refresh_tree(self):
        self.tree.blockSignals(True)
        self.tree.clear()
        block_font = QFont()
        block_font.setWeight(QFont.Weight.DemiBold)
        for b in range(self.doc.nblocks):
            block = self.blocks[b] if b < len(self.blocks) else None
            dims = "×".join(str(d) for d in block.dims) if block else ""
            top = QTreeWidgetItem([f"Block{b + 1}", dims, ""])
            top.setFlags(top.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            top.setCheckState(0, Qt.CheckState.Checked)
            ghost = self.viewport.block_opacity.get(b, 1.0) < 1.0
            top.setCheckState(
                2, Qt.CheckState.Checked if ghost else Qt.CheckState.Unchecked)
            top.setData(0, Qt.ItemDataRole.UserRole, ("block", b))
            top.setFont(0, block_font)
            top.setIcon(0, self._block_icon(b))
            top.setForeground(1, self._brush(self.theme["muted"]))
            if dims:
                top.setToolTip(0, f"Block{b + 1}: {dims} nodes")
                top.setToolTip(1, f"{dims} nodes")
            self.tree.addTopLevelItem(top)
            for f in sorted(self.doc.block_faces[b]):
                where = facemod.FACE_LABELS[f].replace(" = ", "=")
                child = QTreeWidgetItem([f"face{f}   · {where}", ""])
                child.setData(0, Qt.ItemDataRole.UserRole, ("face", b, f))
                child.setToolTip(
                    0, f"Block{b + 1} face{f}: {facemod.FACE_LABELS[f]}")
                child.setForeground(0, self._brush(self.theme["text_dim"]))
                self._face_row_text(child, self.doc.face_value(b, f) or "")
                top.addChild(child)
            top.setExpanded(True)
        self.tree.blockSignals(False)
        self.tree_badge.setText(str(self.doc.nblocks))

    def _brush(self, hexcolor):
        return QBrush(QColor(hexcolor))

    def _block_icon(self, b):
        if self.color_mode == "block":
            return icons.dot(BLOCK_PALETTE[b % len(BLOCK_PALETTE)], 10)
        return self.kit.icon("cube", "muted", 15)

    def restyle(self):
        """Re-apply theme colours in place, keeping the selection."""
        self.tree.blockSignals(True)
        for i in range(self.tree.topLevelItemCount()):
            top = self.tree.topLevelItem(i)
            data = top.data(0, Qt.ItemDataRole.UserRole)
            if not data:
                continue
            top.setIcon(0, self._block_icon(data[1]))
            top.setForeground(1, self._brush(self.theme["muted"]))
            for j in range(top.childCount()):
                child = top.child(j)
                cdata = child.data(0, Qt.ItemDataRole.UserRole)
                if not cdata:
                    continue
                child.setForeground(0, self._brush(self.theme["text_dim"]))
                self._face_row_text(child, self.doc.face_value(cdata[1], cdata[2]))
        self.tree.blockSignals(False)
        self._refresh_viewport_colors()
        self._refresh_legend()
        self.viewport.apply_theme(self.theme)

    def _refresh_sections_list(self):
        cur = self._current_section_name()
        self.sections_list.blockSignals(True)
        self.sections_list.clear()
        for name in self.doc.sections:
            item = QListWidgetItem(f"  {name}   · {self.doc.sections[name].type}")
            item.setIcon(icons.dot(self.color_for(name), 11))
            item.setData(Qt.ItemDataRole.UserRole, name)
            self.sections_list.addItem(item)
        self.sections_list.blockSignals(False)
        self.sections_badge.setText(str(len(self.doc.sections)))
        if cur:
            self._select_section_in_list(cur)

    def _refresh_legend(self):
        counts = {}
        for b in range(self.doc.nblocks):
            for f in self.doc.block_faces[b]:
                val = self.doc.face_value(b, f)
                if val:
                    counts[val] = counts.get(val, 0) + 1
        self.legend_list.clear()
        if not counts:
            item = QListWidgetItem("  Nothing assigned yet")
            item.setForeground(self._brush(self.theme["muted"]))
            self.legend_list.addItem(item)
            return
        for name, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
            kind = "section" if name in self.doc.sections else "keyword"
            item = QListWidgetItem(
                f"  {name}   · {n} face" + ("" if n == 1 else "s"))
            item.setIcon(icons.dot(self.color_for(name), 11))
            item.setToolTip(f"{name} ({kind}) is assigned to {n} face(s)")
            self.legend_list.addItem(item)

    def _on_color_mode_changed(self, _idx):
        self.color_mode = self.color_combo.currentData()
        self._refresh_viewport_colors()
        self.restyle()

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

    def _refresh_assign_combo(self):
        self.assign_combo.blockSignals(True)
        self.assign_combo.clear()
        self.assign_combo.addItem("(unassigned)", None)
        for kw in KEYWORD_BCS:
            self.assign_combo.addItem(
                icons.dot(KEYWORD_COLORS.get(kw, "#7f8c8d"), 11), kw, kw)
        for name in self.doc.sections:
            self.assign_combo.addItem(
                icons.dot(self.color_for(name), 11), f"{name}   · section", name)
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
        elif data and data[0] == "block":
            self._update_block_panel(data[1])

    def refresh_block_phases(self):
        """Rebuild the phase chips of the selected block, if one is selected:
        the GPB phases may have been renamed, added or removed meanwhile."""
        current = self.tree.currentItem()
        data = current.data(0, Qt.ItemDataRole.UserRole) if current else None
        if data and data[0] == "block":
            self._update_block_panel(data[1])

    def _update_block_panel(self, b):
        """Block selected: show which GPB phases it carries."""
        from .widgets import clear_layout
        block = self.blocks[b] if b < len(self.blocks) else None
        dims = "\u00d7".join(str(d) for d in block.dims) if block else ""
        self.sel_label.setText(f"Block{b + 1}" + (f"   ({dims})" if dims else ""))
        self.sel_bc.setText("whole block")
        self.sel_bc.setProperty("role", "muted")
        self.sel_bc.style().unpolish(self.sel_bc)
        self.sel_bc.style().polish(self.sel_bc)

        clear_layout(self.phase_chips)
        names = self.shell.doc.gpb.phase_names()
        selected = self.doc.block_phases(b)
        if names:
            for name in names:
                chip = self.kit.toggle(name, None, "check", name in selected,
                                       tip=f"Phase '{name}' is present in this block",
                                       compactable=False)
                chip.toggled.connect(
                    lambda on, n=name, blk=b: self._toggle_block_phase(blk, n, on))
                self.phase_chips.addWidget(chip)
            self.phase_chips.addStretch(1)
            self.block_hint.setText(
                "No phase selected means every phase of the deck, which is "
                "what BCB assumes when the key is absent."
                if not selected else
                "Written as the 'phase' key of this block's section.")
        else:
            self.block_hint.setText(
                "No GPB phase defined yet. Add phases in the Phases stage to "
                "assign them to single blocks.")
        self.sel_kind.setText("SELECTED BLOCK")
        self.block_box.setVisible(True)
        self._set_face_controls(False)

    def _toggle_block_phase(self, b, name, on):
        selected = self.doc.block_phases(b)
        if on and name not in selected:
            selected.append(name)
        elif not on and name in selected:
            selected.remove(name)
        # Every phase selected is the same as none: keep the file compact.
        if set(selected) == set(self.shell.doc.gpb.phase_names()):
            selected = []
        self.doc.set_block_key(b, "phase", " ".join(selected))
        self.block_hint.setText(
            "No phase selected means every phase of the deck, which is "
            "what BCB assumes when the key is absent."
            if not selected else
            "Written as the 'phase' key of this block's section.")
        self.changed.emit()

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
        for i in range(self.tree.topLevelItemCount()):
            top = self.tree.topLevelItem(i)
            for j in range(top.childCount()):
                child = top.child(j)
                if child.data(0, Qt.ItemDataRole.UserRole) == ("face", b, f):
                    self.tree.setCurrentItem(child)
                    self._update_assign_panel(b, f)
                    return

    def _set_face_controls(self, on):
        """Grey out the face actions while a whole block is selected."""
        self.assign_combo.setEnabled(on)
        self.assign_caption.setEnabled(on)
        for widget in self._face_only:
            widget.setEnabled(on)

    def _update_assign_panel(self, b, f):
        self.sel_kind.setText("SELECTED FACE")
        self.block_box.setVisible(False)
        self._set_face_controls(True)
        val = self.doc.face_value(b, f)
        self.sel_label.setText(
            f"Block{b + 1}  ·  face{f}   ({facemod.FACE_LABELS[f]})")
        self.sel_bc.setText(val or "unassigned")
        self.sel_bc.setProperty("role", "value" if val else "muted")
        self.sel_bc.style().unpolish(self.sel_bc)
        self.sel_bc.style().polish(self.sel_bc)
        self._sync_assign_combo()

    def _sync_assign_combo(self):
        sel = self._selected_face()
        self.assign_combo.blockSignals(True)
        if sel is None:
            self.assign_combo.setCurrentIndex(0)
        else:
            idx = self.assign_combo.findData(self.doc.face_value(*sel))
            self.assign_combo.setCurrentIndex(idx if idx >= 0 else 0)
        self.assign_combo.blockSignals(False)

    # ---------------------------------------------------------- assignment
    def _on_assign_combo(self, _idx):
        sel = self._selected_face()
        if sel is None:
            return
        self._assign(sel[0], sel[1], self.assign_combo.currentData())

    def _assign_current(self, name):
        sel = self._selected_face()
        if sel is None:
            QMessageBox.information(self, "No face", "Select a face first.")
            return
        self._assign(sel[0], sel[1], name)

    def _assign(self, b, f, name):
        self.doc.assign(b, f, name)
        self._rebuild_colors()
        item = self.tree.currentItem()
        if item is not None:
            self._face_row_text(item, name)
        self._refresh_viewport_colors()
        self._update_assign_panel(b, f)
        self._refresh_legend()
        self.changed.emit()

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
        dialog = NewBCDialog(
            self, self.kit, list(self.doc.sections) + KEYWORD_BCS,
            self.shell.case_dir)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        name, bc_type, files = dialog.result_values()
        if not name or name in self.doc.sections or name in KEYWORD_BCS:
            return
        section = BCSection(name, bc_type or "wall")
        section.params.update(files)
        self.doc.add_section(section)
        self._refresh_sections_list()
        self._refresh_assign_combo()
        self._select_section_in_list(name)
        self.changed.emit()

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
        self.changed.emit()

    def _rename_section(self):
        old = self._current_section_name()
        if not old:
            return
        new, ok = QInputDialog.getText(self, "Rename BC", "New name:", text=old)
        new = new.strip()
        if not ok or not new or new == old:
            return
        if new in self.doc.sections or new in KEYWORD_BCS:
            QMessageBox.warning(self, "Name in use", f"'{new}' is already used.")
            return
        self.doc.rename_section(old, new)
        self._editing_section = new
        self.refresh()
        self._select_section_in_list(new)
        self.changed.emit()

    def _delete_section(self):
        name = self._current_section_name()
        if not name:
            return
        if QMessageBox.question(
                self, "Delete BC", f"Delete '{name}' and clear it from any faces?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        ) != QMessageBox.StandardButton.Yes:
            return
        self.doc.remove_section(name)
        self._editing_section = None
        self.refresh()
        self.changed.emit()

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
                self.sec_type_combo.setCurrentText(sec.type)
            self.sec_type_combo.blockSignals(False)
            for k, v in sec.params.items():
                self._table_append(self.param_table, k, v)
        self.param_table.blockSignals(False)
        self._refresh_suggestions()
        self.file_column.refresh()

    def _on_section_type_changed(self, _text):
        self._commit_section_editor()
        self._refresh_suggestions()

    def _refresh_suggestions(self):
        self.suggest_combo.clear()
        for key in suggested_keys(self.sec_type_combo.currentText()):
            role = filekeys.role_of(key)
            self.suggest_combo.addItem(key)
            if role is not None:
                index = self.suggest_combo.count() - 1
                self.suggest_combo.setItemIcon(
                    index, self.kit.icon("file", "muted", 15))
                self.suggest_combo.setItemData(
                    index, f"{key}: {role.hint}", Qt.ItemDataRole.ToolTipRole)

    def _commit_section_editor(self):
        name = self._editing_section
        if not name or name not in self.doc.sections:
            return
        from collections import OrderedDict
        sec = self.doc.sections[name]
        sec.type = self.sec_type_combo.currentText().strip()
        params = OrderedDict()
        for r in range(self.param_table.rowCount()):
            k = self._cell(self.param_table, r, 0)
            v = self._cell(self.param_table, r, 1)
            if k:
                params[k] = v
        sec.params = params
        self.file_column.refresh()
        self._refresh_sections_list_label(name)
        self.changed.emit()

    def _open_files_dialog(self):
        """Every file key of the selected BC, set or not, in one window."""
        name = self._current_section_name()
        if not name or name not in self.doc.sections:
            QMessageBox.information(
                self, "No BC selected",
                "Select or create a boundary condition first.")
            return
        section = self.doc.sections[name]
        rows, seen = [], set()
        for key in list(section.params) + file_keys_of(section.type):
            role = filekeys.role_of(key)
            if role is not None and key not in seen:
                rows.append((key, role))
                seen.add(key)
        extra = [(key, role) for key, role
                 in filekeys.file_keys("bc-section") if key not in seen]
        for phase in self.doc_phases():
            for suffix in ("distribution", "krho-file"):
                key = f"{phase}-{suffix}"
                if key not in seen:
                    extra.append((key, filekeys.role_of(key)))
        dialog = FilesDialog(
            self, self.kit, f"Files of [{name}]",
            f"Keys of this {section.type or 'boundary'} that take a file. A "
            "path is stored relative to the case directory, which is where "
            "the tools run; a missing file is marked.",
            section.params, rows, extra, lambda: self.shell.case_dir,
            self._on_files_dialog_changed)
        dialog.exec()
        self._load_section_editor(name)

    def doc_phases(self):
        """GPB phase names, for the per-phase keys of a dispersed boundary."""
        try:
            return self.shell.doc.gpb.phase_names()
        except AttributeError:
            return []

    def _on_files_dialog_changed(self):
        self._refresh_sections_list_label(self._editing_section or "")
        self.changed.emit()

    def _refresh_sections_list_label(self, name):
        for i in range(self.sections_list.count()):
            it = self.sections_list.item(i)
            if it.data(Qt.ItemDataRole.UserRole) == name:
                it.setText(f"  {name}   · {self.doc.sections[name].type}")
                return

    def _add_param_row(self):
        key = self.suggest_combo.currentText().strip()
        allowed = ENUM_KEY_VALUES.get(key, [])
        self._table_append(self.param_table, key, allowed[0] if allowed else "")
        row = self.param_table.rowCount() - 1
        if allowed:
            self.param_table.item(row, 1).setToolTip(
                "Accepted values: " + ", ".join(allowed))
        self._commit_section_editor()
        self.file_column.refresh()
        if filekeys.role_of(key) is not None:
            # the key names a file: ask for it now instead of leaving it blank
            self.file_column.browse(row)

    def _remove_param_row(self):
        r = self.param_table.currentRow()
        if r >= 0:
            self.param_table.removeRow(r)
            self._commit_section_editor()

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

    def close_viewport(self):
        self.viewport.close()
