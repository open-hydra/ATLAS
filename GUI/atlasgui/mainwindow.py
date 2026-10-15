"""The ATLAS setup window: one case file, one stage at a time.

The shell owns the case (:class:`~atlasgui.document.AtlasDocument`), the file
actions, the theme and the status bar.  Each stage is a panel over the same
document, in the order the tools run:

* **Case** -- where the case lives, the global ``[ATLAS-Parameters]``, and what
  is set up so far;
* **Phases** -- GPB: the property tables the solver will read;
* **Boundaries** -- BCB: the mesh and its boundary conditions;
* **Review** -- the INI as it will be written, with everything the GUI can
  check about it.
"""

from __future__ import annotations

import os

from PyQt6.QtCore import Qt, QSettings
from PyQt6.QtGui import QBrush, QColor, QFont, QSyntaxHighlighter, QTextCharFormat
from PyQt6.QtWidgets import (
    QAbstractItemView, QApplication, QButtonGroup, QComboBox, QFileDialog,
    QFrame, QHBoxLayout, QHeaderView, QLabel, QLineEdit, QListWidget,
    QListWidgetItem, QMessageBox, QPlainTextEdit, QProgressBar, QPushButton,
    QSplitter, QStackedWidget, QTableWidget, QTableWidgetItem, QVBoxLayout,
    QWidget,
)

from . import icons
from . import theme as thememod
from .bcbpanel import BCBPanel
from .bcmodel import ATLAS_PARAM_KEYS
from .document import AtlasDocument
from .gpbpanel import GPBPanel
from .widgets import Card, UIKit

STAGES = [
    ("case", "Case", "sliders", "Where the case lives and what it contains"),
    ("gpb", "Phases", "layers", "GPB: the phases and their property tables"),
    ("bcb", "Boundaries", "cube", "BCB: boundary conditions on the mesh"),
    ("review", "Review", "code", "The INI file and what can be checked in it"),
]

LEVEL_COLORS = {"error": "danger", "warning": "warning", "info": "muted"}
LEVEL_ICONS = {"error": "info", "warning": "info", "info": "info"}


class IniHighlighter(QSyntaxHighlighter):
    """Minimal INI colouring for the preview pane."""

    def __init__(self, document, tokens):
        super().__init__(document)
        self.set_theme(tokens)

    def set_theme(self, t):
        def fmt(colour, bold=False):
            f = QTextCharFormat()
            f.setForeground(QBrush(QColor(colour)))
            if bold:
                f.setFontWeight(QFont.Weight.Bold)
            return f

        self._section = fmt(t["syn_section"], bold=True)
        self._key = fmt(t["syn_key"])
        self._value = fmt(t["syn_value"])
        self._punct = fmt(t["muted"])
        self._comment = fmt(t["syn_comment"])
        self.rehighlight()

    def highlightBlock(self, text):
        stripped = text.strip()
        if not stripped:
            return
        if stripped[0] in ";#":
            self.setFormat(0, len(text), self._comment)
        elif stripped[0] == "[":
            self.setFormat(0, len(text), self._section)
        elif "=" in text:
            i = text.index("=")
            self.setFormat(0, i, self._key)
            self.setFormat(i, 1, self._punct)
            self.setFormat(i + 1, len(text) - i - 1, self._value)


class AtlasMainWindow(QWidget):
    """The application window."""

    COMPACT_WIDTH = 1420

    def __init__(self):
        super().__init__()
        self.doc = AtlasDocument()
        self.ini_path = None
        self.case_dir = os.getcwd()
        self._dirty = False
        self._compact = False

        self.settings = QSettings("ATLAS", "ATLAS-GUI")
        self._theme_name = self.settings.value("theme", thememod.DEFAULT_THEME)
        if self._theme_name not in thememod.THEMES:
            self._theme_name = thememod.DEFAULT_THEME
        self._theme = thememod.get_theme(self._theme_name)
        self.kit = UIKit(self)

        self.setObjectName("Root")
        self.setWindowTitle("ATLAS — case setup")
        self.setGeometry(40, 30, 1760, 1000)
        self.setMinimumSize(1080, 680)
        self._apply_stylesheet()
        self._build_ui()
        self.kit.retint()
        self.bcb_panel.viewport.apply_theme(self._theme)
        self.set_stage("case")
        self.refresh_all()

    @property
    def theme(self):
        return self._theme

    # ------------------------------------------------------------- chrome
    def _apply_stylesheet(self):
        sheet = thememod.build_stylesheet(self._theme)
        app = QApplication.instance()
        if app is not None:
            app.setStyleSheet(sheet)
            app.setPalette(thememod.build_palette(self._theme))
        else:                                            # pragma: no cover
            self.setStyleSheet(sheet)
        self.setWindowIcon(icons.app_icon(self._theme["accent"], self._theme["bg"]))

    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(10, 10, 10, 10)
        root.setSpacing(9)
        root.addWidget(self._build_header())

        body = QHBoxLayout()
        body.setSpacing(9)
        body.addWidget(self._build_stage_rail())

        self.stack = QStackedWidget()
        self.case_page = self._build_case_stage()
        self.gpb_panel = GPBPanel(self)
        self.bcb_panel = BCBPanel(self)
        self.review_page = self._build_review_stage()
        self.gpb_panel.changed.connect(self.document_changed)
        self.bcb_panel.changed.connect(self.document_changed)
        for widget in (self.case_page, self.gpb_panel, self.bcb_panel,
                       self.review_page):
            self.stack.addWidget(widget)
        body.addWidget(self.stack, 1)
        root.addLayout(body, 1)

        # The view controls belong to the Boundaries stage only.
        self.tool_stack.addWidget(QWidget())
        self.tool_stack.addWidget(QWidget())
        self.tool_stack.addWidget(self.bcb_panel.view_tools())
        self.tool_stack.addWidget(QWidget())

        root.addWidget(self._build_status_strip())

    def _build_header(self):
        bar = QFrame()
        bar.setObjectName("HeaderBar")
        kit = self.kit
        lay = QHBoxLayout(bar)
        lay.setContentsMargins(12, 8, 12, 8)
        lay.setSpacing(8)

        lay.addWidget(kit.icon_label("mesh", "accent", 26))
        title_box = QVBoxLayout()
        title_box.setSpacing(0)
        brand = QLabel("ATLAS")
        brand.setObjectName("Brand")
        sub = QLabel("CASE SETUP")
        sub.setObjectName("BrandSub")
        kit._compact_labels.append(sub)
        title_box.addWidget(brand)
        title_box.addWidget(sub)
        lay.addLayout(title_box)
        lay.addSpacing(6)
        lay.addWidget(kit.vdivider())

        for text, slot, ico, role, tip in [
            ("Open INI", self.open_ini_dialog, "open", None,
             "Load an existing ATLAS input.ini"),
            ("Save INI", self.save_ini, "save", "primary",
             "Write the case file"),
            ("Save As", self.save_ini_as, "save-as", None,
             "Write the case file to a new path"),
            ("Load Mesh", self.load_mesh_dialog, "mesh", None,
             "Open a Tecplot or Plot3D multiblock mesh for the boundary stage"),
        ]:
            lay.addWidget(kit.button(text, slot, ico, role, tip=tip,
                                     compactable=True))

        lay.addWidget(kit.vdivider())
        self.tool_stack = QStackedWidget()
        self.tool_stack.setSizePolicy(self.tool_stack.sizePolicy().horizontalPolicy(),
                                      self.tool_stack.sizePolicy().verticalPolicy())
        lay.addWidget(self.tool_stack)
        lay.addStretch(1)

        self.theme_combo = QComboBox()
        for name in thememod.THEMES:
            self.theme_combo.addItem(name, name)
        index = self.theme_combo.findData(self._theme_name)
        if index >= 0:
            self.theme_combo.setCurrentIndex(index)
        self.theme_combo.setToolTip("Application colour theme (remembered).")
        self.theme_combo.setMinimumWidth(115)
        self.theme_combo.currentIndexChanged.connect(
            lambda _i: self.apply_theme(self.theme_combo.currentData()))
        group = QHBoxLayout()
        group.setSpacing(6)
        group.addWidget(kit.icon_label("contrast", "muted", 16))
        group.addWidget(kit.section_label("Theme", compactable=True))
        group.addWidget(self.theme_combo)
        lay.addLayout(group)
        return bar

    def _build_stage_rail(self):
        rail = QFrame()
        rail.setObjectName("StageRail")
        lay = QVBoxLayout(rail)
        lay.setContentsMargins(8, 10, 8, 10)
        lay.setSpacing(6)
        lay.addWidget(self.kit.section_label("WORKFLOW"))

        self.stage_buttons = {}
        self._stage_group = QButtonGroup(self)
        self._stage_group.setExclusive(True)
        for index, (key, label, ico, tip) in enumerate(STAGES):
            button = QPushButton("  " + label)
            button.setProperty("role", "stage")
            button.setCheckable(True)
            button.setToolTip(tip)
            button.setMinimumHeight(38)
            self.kit.bind_icon(button, ico, "text_dim", 19)
            button.clicked.connect(lambda _c=False, k=key: self.set_stage(k))
            self._stage_group.addButton(button, index)
            self.stage_buttons[key] = button
            lay.addWidget(button)
        lay.addSpacing(8)

        self.rail_notes = QVBoxLayout()
        self.rail_notes.setSpacing(4)
        lay.addLayout(self.rail_notes)
        lay.addStretch(1)
        rail.setFixedWidth(176)
        return rail

    # ---------------------------------------------------------- case stage
    def _build_case_stage(self):
        page = QWidget()
        outer = QVBoxLayout(page)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(10)
        kit = self.kit

        row = QHBoxLayout()
        row.setSpacing(10)
        left = QVBoxLayout()
        left.setSpacing(10)

        where = Card()
        where.body.addLayout(kit.panel_header("open", "CASE FILES"))
        self.case_dir_edit = QLineEdit(self.case_dir)
        self.case_dir_edit.setToolTip(
            "Where the INI and the mesh live; GPB writes fromATLAStoSolver/ here.")
        self.case_dir_edit.editingFinished.connect(
            lambda: self.set_case_dir(self.case_dir_edit.text()))
        dir_row = QHBoxLayout()
        dir_row.setSpacing(7)
        dir_row.addWidget(self.case_dir_edit, 1)
        dir_row.addWidget(kit.button("Browse…", self.browse_case_dir, "open"))
        where.body.addWidget(kit.section_label("CASE DIRECTORY"))
        where.body.addLayout(dir_row)
        where.body.addWidget(kit.section_label("INI FILE"))
        self.case_ini_label = QLabel("not saved yet")
        self.case_ini_label.setProperty("role", "value")
        where.body.addWidget(self.case_ini_label)
        where.body.addWidget(kit.section_label("MESH"))
        self.case_mesh_label = QLabel("no mesh loaded")
        self.case_mesh_label.setProperty("role", "value")
        where.body.addWidget(self.case_mesh_label)
        mesh_row = QHBoxLayout()
        mesh_row.setSpacing(7)
        mesh_row.addWidget(kit.button("Load mesh…", self.load_mesh_dialog, "mesh"))
        mesh_row.addStretch(1)
        where.body.addLayout(mesh_row)
        left.addWidget(where)

        params = Card()
        params.body.addLayout(
            kit.panel_header("sliders", "[ATLAS-PARAMETERS]"))
        self.param_global = QTableWidget(0, 2)
        self.param_global.setHorizontalHeaderLabels(["KEY", "VALUE"])
        self.param_global.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeMode.Stretch)
        self.param_global.verticalHeader().setVisible(False)
        self.param_global.verticalHeader().setDefaultSectionSize(28)
        self.param_global.setShowGrid(False)
        self.param_global.setSelectionBehavior(
            QAbstractItemView.SelectionBehavior.SelectRows)
        self.param_global.cellChanged.connect(lambda *_: self._commit_globals())
        params.body.addWidget(self.param_global, 1)
        prow = QHBoxLayout()
        prow.setSpacing(7)
        self.global_suggest = QComboBox()
        self.global_suggest.setEditable(True)
        self.global_suggest.addItems(ATLAS_PARAM_KEYS)
        prow.addWidget(self.global_suggest, 1)
        prow.addWidget(kit.button("Add key", self._add_global_row, "plus"))
        prow.addWidget(kit.button("Remove", self._remove_global_row, "trash",
                                  "danger"))
        params.body.addLayout(prow)
        params.body.addWidget(kit.hint(
            "Global settings shared by the ATLAS tools, written as the "
            "[ATLAS-Parameters] section."))

        overview = Card()
        overview.body.addLayout(kit.panel_header("layers", "CASE OVERVIEW"))
        self.overview_row = QHBoxLayout()
        self.overview_row.setSpacing(10)
        overview.body.addLayout(self.overview_row)
        left.addWidget(overview)
        left.addStretch(1)

        row.addLayout(left, 1)
        row.addWidget(params, 1)
        outer.addLayout(row, 1)
        return page

    def _overview_tile(self, icon_name, title, value, note, stage):
        tile = QFrame()
        tile.setObjectName("Tile")
        lay = QVBoxLayout(tile)
        lay.setContentsMargins(14, 12, 14, 12)
        lay.setSpacing(4)
        head = QHBoxLayout()
        head.setSpacing(7)
        head.addWidget(self.kit.icon_label(icon_name, "muted", 15))
        head.addWidget(self.kit.section_label(title))
        head.addStretch(1)
        lay.addLayout(head)
        big = QLabel(value)
        big.setObjectName("TileValue")
        lay.addWidget(big)
        lay.addWidget(self.kit.hint(note))
        button = self.kit.button("Open", lambda: self.set_stage(stage), None,
                                 "ghost")
        lay.addWidget(button)
        return tile

    # -------------------------------------------------------- review stage
    def _build_review_stage(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setContentsMargins(0, 0, 0, 0)
        kit = self.kit
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(9)

        checks = Card()
        self.issue_badge = kit.badge("0")
        checks.body.addLayout(
            kit.panel_header("check", "CHECKS", self.issue_badge))
        self.issue_list = QListWidget()
        self.issue_list.setWordWrap(True)
        self.issue_list.setTextElideMode(Qt.TextElideMode.ElideNone)
        self.issue_list.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.issue_list.itemDoubleClicked.connect(self._goto_issue)
        self.issue_list.setToolTip(
            "What the GUI can check without running the tools. "
            "Double-click an entry to go to it.")
        checks.body.addWidget(self.issue_list, 1)
        checks.body.addWidget(kit.hint(
            "GPB and BCB run their own checks too; these are the ones that can "
            "be made from the file alone."))
        splitter.addWidget(checks)

        preview = Card()
        preview.body.addLayout(
            kit.panel_header("code", "INPUT.INI · LIVE PREVIEW",
                             trailing=[kit.button("Save INI", self.save_ini,
                                                  "save", "primary")]))
        self.preview = QPlainTextEdit()
        self.preview.setReadOnly(True)
        self.preview.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.highlighter = IniHighlighter(self.preview.document(), self._theme)
        preview.body.addWidget(self.preview, 1)
        splitter.addWidget(preview)
        splitter.setSizes([420, 900])
        lay.addWidget(splitter)
        return page

    def _goto_issue(self, item):
        target = item.data(Qt.ItemDataRole.UserRole)
        if not target:
            return
        stage, index = target
        self.set_stage(stage)
        if stage == "gpb" and index is not None:
            self.gpb_panel.phase_list.setCurrentRow(index)

    # -------------------------------------------------------- status strip
    def _build_status_strip(self):
        bar = QFrame()
        bar.setObjectName("StatusStrip")
        kit = self.kit
        lay = QHBoxLayout(bar)
        lay.setContentsMargins(12, 6, 12, 6)
        lay.setSpacing(10)

        lay.addWidget(kit.icon_label("save", "muted", 16))
        self.status = QLabel("new case")
        self.status.setProperty("role", "value")
        lay.addWidget(self.status)
        self.dirty_badge = kit.badge("unsaved")
        self.dirty_badge.setVisible(False)
        lay.addWidget(self.dirty_badge)

        lay.addWidget(kit.vdivider())
        lay.addWidget(kit.section_label("PHASES"))
        self.phases_badge = kit.badge("0")
        lay.addWidget(self.phases_badge)
        lay.addWidget(kit.section_label("BLOCKS"))
        self.blocks_badge = kit.badge("0")
        lay.addWidget(self.blocks_badge)

        lay.addWidget(kit.vdivider())
        lay.addWidget(kit.section_label("COVERAGE"))
        self.progress = QProgressBar()
        self.progress.setTextVisible(False)
        self.progress.setFixedWidth(150)
        lay.addWidget(self.progress)
        self.faces_label = QLabel("0 / 0 faces")
        self.faces_label.setProperty("role", "muted")
        lay.addWidget(self.faces_label)

        lay.addStretch(1)
        self.issues_label = QLabel("no issues")
        self.issues_label.setProperty("role", "muted")
        lay.addWidget(self.issues_label)
        return bar

    # ------------------------------------------------------------- stages
    def set_stage(self, key):
        index = [k for k, _l, _i, _t in STAGES].index(key)
        self.stack.setCurrentIndex(index)
        self.tool_stack.setCurrentIndex(index)
        button = self.stage_buttons[key]
        if not button.isChecked():
            button.setChecked(True)
        self.current_stage = key
        if key == "gpb":
            self.gpb_panel.refresh()
        elif key == "review":
            self.refresh_review()

    # ------------------------------------------------------------ file ops
    def set_case_dir(self, path):
        path = os.path.abspath(os.path.expanduser(path.strip() or "."))
        if os.path.isdir(path):
            self.case_dir = path
        self.case_dir_edit.setText(self.case_dir)

    def browse_case_dir(self):
        path = QFileDialog.getExistingDirectory(self, "Case directory",
                                                self.case_dir)
        if path:
            self.set_case_dir(path)
            self.refresh_all()

    def load_mesh_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Load mesh", self.bcb_panel.mesh_path or self.case_dir,
            "Meshes (*.tec *.dat *.p3d *.xyz *.g *.grd *.plt);;All files (*)")
        if path:
            self.load_mesh(path)

    def load_mesh(self, path):
        if self.bcb_panel.load_mesh(path):
            self.set_case_dir(os.path.dirname(os.path.abspath(path)))
            self.set_stage("bcb")
            self.refresh_all()

    def open_ini_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open ATLAS INI", self.case_dir,
            "INI files (*.ini);;All files (*)")
        if path:
            self.open_ini(path)

    def open_ini(self, path):
        try:
            with open(path) as handle:
                text = handle.read()
        except OSError as exc:
            QMessageBox.critical(self, "Open failed", str(exc))
            return
        new_doc = AtlasDocument.from_ini(text)
        if self.bcb_panel.blocks:
            if new_doc.bcb.nblocks and \
                    new_doc.bcb.nblocks != len(self.bcb_panel.blocks):
                QMessageBox.warning(
                    self, "Block count mismatch",
                    f"The file defines {new_doc.bcb.nblocks} block(s) but the "
                    f"loaded mesh has {len(self.bcb_panel.blocks)}. "
                    f"Assignments applied where they fit.")
        self.doc = new_doc
        self.ini_path = path
        self.set_case_dir(os.path.dirname(os.path.abspath(path)))
        self.bcb_panel.sync_blocks_to_mesh()
        self._dirty = False
        self.refresh_all()

    def save_ini(self):
        if not self.ini_path:
            return self.save_ini_as()
        missing = self.doc.bcb.unassigned_faces()
        if missing and not self._confirm_missing(missing):
            return
        try:
            with open(self.ini_path, "w") as handle:
                handle.write(self.doc.to_ini())
        except OSError as exc:
            QMessageBox.critical(self, "Save failed", str(exc))
            return
        self._dirty = False
        self.status.setText(f"Saved {os.path.basename(self.ini_path)}")
        self.refresh_status()

    def save_ini_as(self):
        start = self.ini_path or os.path.join(self.case_dir, "input.ini")
        path, _ = QFileDialog.getSaveFileName(
            self, "Save ATLAS INI", start, "INI files (*.ini);;All files (*)")
        if path:
            self.ini_path = path
            self.set_case_dir(os.path.dirname(os.path.abspath(path)))
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

    def warn(self, title, text):
        QMessageBox.information(self, title, text)

    # -------------------------------------------------------------- refresh
    def document_changed(self):
        self._dirty = True
        self.refresh_status()
        if getattr(self, "current_stage", None) == "review":
            self.refresh_review()

    def refresh_all(self):
        self.bcb_panel.refresh()
        self.gpb_panel.refresh()
        self._refresh_globals_table()
        self.refresh_case()
        self.refresh_review()
        self.refresh_status()

    def refresh_case(self):
        from .widgets import clear_layout
        self.case_ini_label.setText(
            os.path.basename(self.ini_path) if self.ini_path else "not saved yet")
        self.case_ini_label.setToolTip(self.ini_path or "")
        mesh = self.bcb_panel.mesh_path
        self.case_mesh_label.setText(
            os.path.basename(mesh) if mesh else "no mesh loaded")
        self.case_mesh_label.setToolTip(mesh or "")
        self.case_dir_edit.setText(self.case_dir)

        clear_layout(self.overview_row)
        nphases, nblocks = self.doc.summary()
        total, done = self._coverage()
        issues = self._issues()
        errors = sum(1 for level, _t, _m in issues if level == "error")
        self.overview_row.addWidget(self._overview_tile(
            "layers", "PHASES", str(nphases),
            ", ".join(self.doc.gpb.names()) or "none defined yet", "gpb"))
        self.overview_row.addWidget(self._overview_tile(
            "cube", "BLOCKS", str(nblocks),
            f"{done} of {total} faces assigned" if total else "no mesh loaded",
            "bcb"))
        self.overview_row.addWidget(self._overview_tile(
            "check", "CHECKS", str(errors),
            "error(s) to fix before running" if errors else "nothing blocking",
            "review"))
        self.overview_row.addStretch(1)

    def _coverage(self):
        total = sum(len(f) for f in self.doc.bcb.block_faces)
        done = total - len(self.doc.bcb.unassigned_faces())
        return total, done

    def _issues(self):
        """``[(level, (stage, index), message), ...]`` across the case."""
        issues = [(level, ("gpb", index), message)
                  for level, index, message in self.doc.gpb.validate()]
        missing = self.doc.bcb.unassigned_faces()
        if missing:
            preview = ", ".join(f"Block{b + 1}.face{f}" for b, f in missing[:4])
            if len(missing) > 4:
                preview += ", …"
            issues.append(("error", ("bcb", None), (
                f"{len(missing)} face(s) have no boundary condition: {preview}")))
        for name, section in self.doc.bcb.sections.items():
            if not section.type:
                issues.append(("warning", ("bcb", None), (
                    f"BC '{name}' has no type")))
        if not self.doc.gpb.phases:
            issues.append(("info", ("gpb", None), (
                "no phase defined: GPB has nothing to build")))
        return issues

    def refresh_review(self):
        self.preview.setPlainText(self.doc.to_ini())
        self.issue_list.clear()
        issues = self._issues()
        order = {"error": 0, "warning": 1, "info": 2}
        for level, target, message in sorted(issues, key=lambda i: order[i[0]]):
            item = QListWidgetItem(f"  {message}")
            item.setIcon(icons.dot(self._theme[LEVEL_COLORS[level]], 10))
            item.setData(Qt.ItemDataRole.UserRole, target)
            item.setToolTip(f"{level}: {message}")
            self.issue_list.addItem(item)
        if not issues:
            item = QListWidgetItem("  Nothing to report")
            item.setForeground(QBrush(QColor(self._theme["muted"])))
            self.issue_list.addItem(item)
        errors = sum(1 for level, _t, _m in issues if level == "error")
        self.issue_badge.setText(str(len(issues)))
        self.issue_badge.setToolTip(f"{errors} error(s)")

    def refresh_status(self):
        total, done = self._coverage()
        self.progress.setMaximum(max(total, 1))
        self.progress.setValue(done)
        state = "done" if total and done == total else "open"
        if self.progress.property("state") != state:
            self.progress.setProperty("state", state)
            self.progress.style().unpolish(self.progress)
            self.progress.style().polish(self.progress)
        self.faces_label.setText(f"{done} / {total} faces")
        nphases, nblocks = self.doc.summary()
        self.phases_badge.setText(str(nphases))
        self.blocks_badge.setText(str(nblocks))
        self.dirty_badge.setVisible(self._dirty)
        self.status.setText(
            os.path.basename(self.ini_path) if self.ini_path else "new case")
        self.status.setToolTip(self.ini_path or "not written to a file yet")
        issues = self._issues()
        errors = sum(1 for level, _t, _m in issues if level == "error")
        warnings = sum(1 for level, _t, _m in issues if level == "warning")
        if errors:
            self.issues_label.setText(f"{errors} error(s), {warnings} warning(s)")
        elif warnings:
            self.issues_label.setText(f"{warnings} warning(s)")
        else:
            self.issues_label.setText("no issues")
        self.refresh_case_badges()

    def refresh_case_badges(self):
        if getattr(self, "current_stage", None) == "case":
            self.refresh_case()

    # -------------------------------------------------------------- globals
    def _refresh_globals_table(self):
        self.param_global.blockSignals(True)
        self.param_global.setRowCount(0)
        for key, value in self.doc.parameters.items():
            row = self.param_global.rowCount()
            self.param_global.insertRow(row)
            self.param_global.setItem(row, 0, QTableWidgetItem(str(key)))
            self.param_global.setItem(row, 1, QTableWidgetItem(str(value)))
        self.param_global.blockSignals(False)

    def _commit_globals(self):
        from collections import OrderedDict
        params = OrderedDict()
        for row in range(self.param_global.rowCount()):
            key = self.param_global.item(row, 0)
            value = self.param_global.item(row, 1)
            key = key.text().strip() if key else ""
            value = value.text().strip() if value else ""
            if key:
                params[key] = value
        self.doc.parameters = params
        self.document_changed()

    def _add_global_row(self):
        row = self.param_global.rowCount()
        self.param_global.insertRow(row)
        self.param_global.setItem(
            row, 0, QTableWidgetItem(self.global_suggest.currentText()))
        self.param_global.setItem(row, 1, QTableWidgetItem(""))
        self._commit_globals()

    def _remove_global_row(self):
        row = self.param_global.currentRow()
        if row >= 0:
            self.param_global.removeRow(row)
            self._commit_globals()

    # ---------------------------------------------------------------- theme
    def apply_theme(self, name):
        self._theme_name = name
        self._theme = thememod.get_theme(name)
        self._apply_stylesheet()
        self.kit.retint()
        self.highlighter.set_theme(self._theme)
        self.bcb_panel.restyle()
        self.gpb_panel.refresh()
        self.refresh_review()
        index = self.theme_combo.findData(name)
        if index >= 0 and index != self.theme_combo.currentIndex():
            self.theme_combo.blockSignals(True)
            self.theme_combo.setCurrentIndex(index)
            self.theme_combo.blockSignals(False)
        self.settings.setValue("theme", name)

    # ----------------------------------------------------------- responsive
    def resizeEvent(self, event):
        super().resizeEvent(event)
        width = event.size().width()
        if width < self.COMPACT_WIDTH - 40 and not self._compact:
            self._compact = True
            self.kit.set_compact(True)
        elif width > self.COMPACT_WIDTH and self._compact:
            self._compact = False
            self.kit.set_compact(False)

    def closeEvent(self, event):
        if self._dirty:
            reply = QMessageBox.question(
                self, "Unsaved changes",
                "The case has changes that are not written to the INI file.\n"
                "Save before closing?",
                QMessageBox.StandardButton.Save | QMessageBox.StandardButton.Discard
                | QMessageBox.StandardButton.Cancel)
            if reply == QMessageBox.StandardButton.Cancel:
                event.ignore()
                return
            if reply == QMessageBox.StandardButton.Save:
                self.save_ini()
        self.bcb_panel.close_viewport()
        super().closeEvent(event)


# The window used to be the BCB GUI; keep the old name importable.
BCBMainWindow = AtlasMainWindow
