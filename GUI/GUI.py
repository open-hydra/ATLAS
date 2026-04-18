import sys
import os
import re
import configparser
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QPushButton, QTreeWidget,
    QTreeWidgetItem, QComboBox, QLineEdit, QMessageBox, QHBoxLayout,
    QSplitter, QGroupBox, QStyle, QFileDialog, QLabel, QListWidget,
    QListWidgetItem, QPlainTextEdit, QTabWidget, QFrame, QGridLayout,
    QFormLayout, QStackedWidget, QScrollArea, QCheckBox
)
from PyQt6.QtCore import Qt, QSize, QProcess, QProcessEnvironment, QUrl, QSettings
from PyQt6.QtGui import QDesktopServices, QShortcut, QKeySequence


class INIEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.config = configparser.ConfigParser()
        self.config.optionxform = str
        self.phase_count = 0
        self.current_file = None
        self.type_options = [
            "ideal-gas",
            "heavy-gas",
            "solid",
            "condensed-dispersed",
            "real-gas",
        ]
        self.thermo_options = ["NASA9", "NASA7", "Burcat"]
        self.transport_options = ["CEA", "cantera"]
        self.real_fluid_model_options = ["coolprop", "redlich-kwong", "peng-robinson"]
        self.available_keys = {
            "type": self.type_options,
            "thermo": self.thermo_options,
            "transport": self.transport_options,
            "model": self.real_fluid_model_options,
            "name": None,
            "phase": None,
            "species": None,
            "add-species": None,
            "reactions": None,
            "mixture": None,
            "mixture-name": None,
            "inerts-mixing": ["True", "False"],
            "fluid": None,
            "pmin": None,
            "pmax": None,
            "Tmin": None,
            "Tmax": None,
            "NP": None,
            "NH": None,
            "material": None,
            "groups": None,
            "cp": None,
            "cv": None,
            "gamma": None,
            "R": None,
            "mw": None,
            "mil": None,
            "kl": None,
            "Pr": None,
        }
        self.diagnostic_item_map = {}
        self.process = None
        self.atlas_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        self.gpb_entrypoint = os.path.join(self.atlas_root, "src", "GPB", "__main__.py")
        self.templates_root = os.path.join(self.atlas_root, "test", "GPB")
        self.settings = QSettings("ATLAS", "GPB-INI-Editor")
        self.recent_files = []
        self.compact_mode = False
        self.responsive_labels = []
        self.init_ui()
        restored = self.restore_session_state()
        if not restored:
            self.new_document()
        
    def init_ui(self):
        self.setWindowTitle("GPB INI Editor")
        self.setGeometry(70, 60, 1520, 940)

        # Styled, denser workspace theme.
        self.setStyleSheet("""
            QWidget {
                background-color: #11161c;
                font-family: "Avenir Next", "Segoe UI", "Helvetica Neue", sans-serif;
                font-size: 10.5pt;
                color: #e6edf3;
            }

            QFrame#HeaderFrame {
                border: 1px solid #2a3a4d;
                border-radius: 10px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #1b2836, stop:1 #132233);
            }

            QLabel#HeaderTitle {
                font-size: 18pt;
                font-weight: 700;
                color: #f1f6fb;
            }

            QLabel#HeaderSubtitle {
                font-size: 10.5pt;
                color: #a8c0d9;
            }

            QLabel#StatusChip {
                background-color: #23415f;
                border: 1px solid #2f5f8a;
                border-radius: 8px;
                padding: 5px 10px;
                color: #d5e9ff;
                font-weight: 600;
            }

            QLabel#StatusChip[state="idle"] {
                background-color: #23415f;
                border-color: #2f5f8a;
            }

            QLabel#StatusChip[state="running"] {
                background-color: #1f5c3c;
                border-color: #2b7d53;
            }

            QLabel#StatusChip[state="success"] {
                background-color: #2a5f46;
                border-color: #3a8a65;
            }

            QLabel#StatusChip[state="warning"] {
                background-color: #6a4b20;
                border-color: #9a6c2f;
            }

            QLabel#StatusChip[state="error"] {
                background-color: #6d2a2a;
                border-color: #a33d3d;
            }

            QTreeWidget {
                background-color: #18212b;
                alternate-background-color: #131b24;
                color: #e6edf3;
                border: 1px solid #304255;
                border-radius: 8px;
                gridline-color: #2a3a4d;
                padding: 4px;
            }

            QHeaderView::section {
                background-color: #203243;
                color: #dcecff;
                padding: 6px;
                border: 0px;
                border-right: 1px solid #2d4258;
                font-weight: 600;
            }

            QGroupBox {
                background-color: #11161c;
                border: 1px solid #2a3a4d;
                border-radius: 10px;
                font-weight: bold;
                margin-top: 12px;
                color: #e6edf3;
                padding: 10px;
            }

            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 6px;
                color: #a8c0d9;
            }

            QPushButton {
                background-color: #1f3a54;
                color: #e7f3ff;
                border: 1px solid #305879;
                border-radius: 8px;
                padding: 7px 10px;
                margin: 3px;
                font-weight: 600;
                min-height: 34px;
            }

            QPushButton:hover {
                background-color: #2b4f73;
            }

            QPushButton:pressed {
                background-color: #16334b;
            }

            QPushButton:disabled {
                background-color: #1b2632;
                color: #6f8397;
                border-color: #2a3a4d;
            }

            QPushButton[role="primary"] {
                background-color: #28628f;
                border-color: #3f84ba;
                color: #f3fbff;
            }

            QPushButton[role="primary"]:hover {
                background-color: #3475a8;
            }

            QPushButton[role="danger"] {
                background-color: #6b2f35;
                border-color: #a34a54;
                color: #ffecee;
            }

            QPushButton[role="danger"]:hover {
                background-color: #854048;
            }

            QPushButton[role="ghost"] {
                background-color: #1a2733;
                border-color: #34485d;
                color: #cde3f7;
            }

            QPushButton[role="ghost"]:hover {
                background-color: #223547;
            }

            QLineEdit, QComboBox {
                border: 1px solid #35516a;
                border-radius: 8px;
                padding: 6px;
                background-color: #16202a;
                color: #e6edf3;
                selection-background-color: #2c587f;
                min-height: 34px;
            }

            QLabel[role="section-title"] {
                font-size: 10pt;
                font-weight: 700;
                color: #cfe3f6;
                padding: 4px 2px 2px 2px;
            }

            QComboBox QAbstractItemView {
                background-color: #18222d;
                color: #e6edf3;
                border: 1px solid #35516a;
            }

            QListWidget {
                border: 1px solid #304255;
                border-radius: 8px;
                background-color: #141c24;
                color: #e6edf3;
            }

            QPlainTextEdit {
                border: 1px solid #304255;
                border-radius: 8px;
                background-color: #101820;
                color: #d5e9ff;
                padding: 6px;
                font-family: "Menlo", "Consolas", monospace;
                font-size: 10pt;
            }

            QLabel {
                color: #dce8f4;
            }

            QTabWidget::pane {
                border: 1px solid #2a3a4d;
                border-radius: 10px;
                background: #11161c;
            }

            QTabBar::tab {
                background: #172331;
                color: #b8d0e7;
                border: 1px solid #2a3a4d;
                border-bottom: none;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                min-width: 110px;
                padding: 7px 12px;
                margin-right: 4px;
            }

            QTabBar::tab:selected {
                background: #20384f;
                color: #f1f6fb;
            }

            QWidget[compact="true"] {
                font-size: 10pt;
            }

            QWidget[compact="true"] QLabel#HeaderTitle {
                font-size: 16pt;
            }

            QWidget[compact="true"] QPushButton,
            QWidget[compact="true"] QLineEdit,
            QWidget[compact="true"] QComboBox {
                min-height: 30px;
                padding-top: 5px;
                padding-bottom: 5px;
            }
        """)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(10)

        header = QFrame()
        header.setObjectName("HeaderFrame")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(14, 12, 14, 12)

        title_col = QVBoxLayout()
        title = QLabel("ATLAS GPB Workspace")
        title.setObjectName("HeaderTitle")
        subtitle = QLabel("Build phase inputs, validate constraints, run GPB, and inspect generated artifacts")
        subtitle.setObjectName("HeaderSubtitle")
        title_col.addWidget(title)
        title_col.addWidget(subtitle)
        header_layout.addLayout(title_col)
        header_layout.addStretch()

        self.run_status = QLabel("Runner: idle")
        self.run_status.setObjectName("StatusChip")
        self.run_status.setProperty("state", "idle")
        header_layout.addWidget(self.run_status)

        self.compact_toggle = QCheckBox("Compact")
        self.compact_toggle.toggled.connect(self.on_compact_toggled)
        header_layout.addWidget(self.compact_toggle)
        main_layout.addWidget(header)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(10)

        # Left: phase editor block
        left_group = QGroupBox("Phase Editor")
        left_layout = QVBoxLayout(left_group)
        left_layout.setContentsMargins(10, 14, 10, 10)
        left_layout.setSpacing(8)

        self.file_label = QLabel()
        self.file_label.setWordWrap(True)
        left_layout.addWidget(self.file_label)

        self.tree = QTreeWidget()
        self.tree.setAlternatingRowColors(True)
        self.tree.setUniformRowHeights(True)
        self.tree.setHeaderLabels(["Section/Key", "Value"])
        self.tree.setColumnWidth(0, 280)
        self.tree.currentItemChanged.connect(self.on_tree_current_item_changed)
        left_layout.addWidget(self.tree)
        splitter.addWidget(left_group)

        # Right: organized tabs
        right_tabs = QTabWidget()
        self.build_physics_tab(right_tabs)

        workflow_tab = QWidget()
        workflow_layout = QVBoxLayout(workflow_tab)
        workflow_layout.setContentsMargins(10, 10, 10, 10)
        workflow_layout.setSpacing(8)

        workdir_row = QHBoxLayout()
        self.workdir_edit = QLineEdit()
        self.workdir_edit.setPlaceholderText("Working directory for input.ini and outputs")
        self.workdir_edit.editingFinished.connect(self.on_workdir_edit_finished)
        workdir_row.addWidget(self.workdir_edit)
        btn_workdir = QPushButton("Browse")
        btn_workdir.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirIcon))
        btn_workdir.clicked.connect(self.select_working_directory)
        workdir_row.addWidget(btn_workdir)
        workflow_layout.addLayout(workdir_row)

        top_file_grid = QGridLayout()
        top_file_grid.setHorizontalSpacing(8)
        top_file_grid.setVerticalSpacing(6)

        btn_new = QPushButton("New")
        btn_new.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileIcon))
        btn_new.setIconSize(QSize(18, 18))
        btn_new.setProperty("role", "ghost")
        btn_new.clicked.connect(self.new_document)
        top_file_grid.addWidget(btn_new, 0, 0)

        btn_open = QPushButton("Open")
        btn_open.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirOpenIcon))
        btn_open.setIconSize(QSize(18, 18))
        btn_open.setProperty("role", "ghost")
        btn_open.clicked.connect(self.open_ini)
        top_file_grid.addWidget(btn_open, 0, 1)

        btn_import_legacy = QPushButton("Import Legacy")
        btn_import_legacy.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_BrowserReload))
        btn_import_legacy.setIconSize(QSize(18, 18))
        btn_import_legacy.setProperty("role", "ghost")
        btn_import_legacy.clicked.connect(self.import_legacy_config)
        self.btn_import_legacy = btn_import_legacy
        top_file_grid.addWidget(btn_import_legacy, 0, 2)

        btn_save = QPushButton("Save")
        btn_save.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogApplyButton))
        btn_save.setIconSize(QSize(18, 18))
        btn_save.setProperty("role", "primary")
        btn_save.clicked.connect(self.save_ini)
        top_file_grid.addWidget(btn_save, 1, 0)

        btn_save_as = QPushButton("Save As")
        btn_save_as.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogSaveButton))
        btn_save_as.setIconSize(QSize(18, 18))
        btn_save_as.setProperty("role", "ghost")
        btn_save_as.clicked.connect(self.save_ini_as)
        top_file_grid.addWidget(btn_save_as, 1, 1)

        btn_validate = QPushButton("Validate")
        btn_validate.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_MessageBoxInformation))
        btn_validate.setIconSize(QSize(18, 18))
        btn_validate.setProperty("role", "ghost")
        btn_validate.clicked.connect(self.validate_only)
        top_file_grid.addWidget(btn_validate, 1, 2)
        workflow_layout.addLayout(top_file_grid)

        recent_row = QHBoxLayout()
        self.recent_combo = QComboBox()
        self.recent_combo.setPlaceholderText("Recent files")
        recent_row.addWidget(self.recent_combo)
        btn_open_recent = QPushButton("Open Recent")
        btn_open_recent.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirOpenIcon))
        btn_open_recent.clicked.connect(self.open_recent_selected)
        self.btn_open_recent = btn_open_recent
        recent_row.addWidget(btn_open_recent)
        workflow_layout.addLayout(recent_row)

        template_row = QHBoxLayout()
        self.template_combo = QComboBox()
        self.template_combo.setPlaceholderText("Templates from test/GPB")
        template_row.addWidget(self.template_combo)
        btn_template = QPushButton("Load Template")
        btn_template.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogDetailedView))
        btn_template.clicked.connect(self.load_selected_template)
        self.btn_load_template = btn_template
        template_row.addWidget(btn_template)
        workflow_layout.addLayout(template_row)

        edit_grid = QGridLayout()
        edit_grid.setHorizontalSpacing(8)
        edit_grid.setVerticalSpacing(6)

        btn_add_phase = QPushButton("Add Phase")
        btn_add_phase.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileIcon))
        btn_add_phase.setIconSize(QSize(18, 18))
        btn_add_phase.clicked.connect(self.add_phase)
        edit_grid.addWidget(btn_add_phase, 0, 0)

        btn_add_key = QPushButton("Add Key")
        btn_add_key.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogNewFolder))
        btn_add_key.setIconSize(QSize(18, 18))
        btn_add_key.clicked.connect(self.add_key)
        edit_grid.addWidget(btn_add_key, 0, 1)

        btn_delete_section = QPushButton("Delete Section")
        btn_delete_section.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        btn_delete_section.setIconSize(QSize(18, 18))
        btn_delete_section.setProperty("role", "danger")
        btn_delete_section.clicked.connect(self.delete_section)
        self.btn_delete_section = btn_delete_section
        edit_grid.addWidget(btn_delete_section, 0, 2)

        btn_delete_key = QPushButton("Delete Key")
        btn_delete_key.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        btn_delete_key.setIconSize(QSize(18, 18))
        btn_delete_key.setProperty("role", "danger")
        btn_delete_key.clicked.connect(self.delete_key)
        self.btn_delete_key = btn_delete_key
        edit_grid.addWidget(btn_delete_key, 1, 0)

        self.context_hint = QLabel()
        self.context_hint.setWordWrap(True)
        self.context_hint.setMinimumHeight(70)
        self.context_hint.setStyleSheet(
            "QLabel {"
            "background-color: #152435;"
            "border: 1px solid #2f4760;"
            "border-radius: 8px;"
            "padding: 8px;"
            "color: #cfe3f6;"
            "}"
        )
        workflow_layout.addWidget(self.context_hint)
        workflow_layout.addLayout(edit_grid)

        run_row = QHBoxLayout()
        run_row.setSpacing(8)

        btn_run = QPushButton("Run GPB")
        btn_run.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_MediaPlay))
        btn_run.setIconSize(QSize(18, 18))
        btn_run.setProperty("role", "primary")
        btn_run.clicked.connect(self.run_gpb)
        run_row.addWidget(btn_run)
        self.btn_run = btn_run

        btn_stop = QPushButton("Stop GPB")
        btn_stop.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_MediaStop))
        btn_stop.setIconSize(QSize(18, 18))
        btn_stop.setProperty("role", "danger")
        btn_stop.clicked.connect(self.stop_gpb)
        btn_stop.setEnabled(False)
        run_row.addWidget(btn_stop)
        self.btn_stop = btn_stop
        workflow_layout.addLayout(run_row)

        workflow_layout.addStretch()
        right_tabs.addTab(workflow_tab, "Workflow")

        activity_tab = QWidget()
        activity_layout = QVBoxLayout(activity_tab)
        activity_layout.setContentsMargins(10, 10, 10, 10)
        activity_layout.setSpacing(8)

        diagnostics_title = QLabel("Diagnostics")
        activity_layout.addWidget(diagnostics_title)
        self.diagnostics = QListWidget()
        self.diagnostics.itemClicked.connect(self.focus_diagnostic_item)
        activity_layout.addWidget(self.diagnostics)

        logs_title = QLabel("Run Logs")
        activity_layout.addWidget(logs_title)
        self.logs = QPlainTextEdit()
        self.logs.setReadOnly(True)
        self.logs.setMaximumBlockCount(2000)
        activity_layout.addWidget(self.logs)

        btn_clear_logs = QPushButton("Clear Logs")
        btn_clear_logs.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogResetButton))
        btn_clear_logs.setProperty("role", "ghost")
        btn_clear_logs.clicked.connect(self.logs.clear)
        activity_layout.addWidget(btn_clear_logs)
        right_tabs.addTab(activity_tab, "Diagnostics & Logs")

        outputs_tab = QWidget()
        outputs_layout = QVBoxLayout(outputs_tab)
        outputs_layout.setContentsMargins(10, 10, 10, 10)
        outputs_layout.setSpacing(8)

        outputs_title = QLabel("Outputs")
        outputs_layout.addWidget(outputs_title)

        output_actions = QHBoxLayout()
        btn_refresh_outputs = QPushButton("Refresh")
        btn_refresh_outputs.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_BrowserReload))
        btn_refresh_outputs.setProperty("role", "ghost")
        btn_refresh_outputs.clicked.connect(self.refresh_output_browser)
        output_actions.addWidget(btn_refresh_outputs)

        btn_open_outputs_dir = QPushButton("Open Folder")
        btn_open_outputs_dir.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirIcon))
        btn_open_outputs_dir.setProperty("role", "ghost")
        btn_open_outputs_dir.clicked.connect(self.open_outputs_folder)
        output_actions.addWidget(btn_open_outputs_dir)
        outputs_layout.addLayout(output_actions)

        self.output_tree = QTreeWidget()
        self.output_tree.setHeaderLabels(["Output files"])
        self.output_tree.setAlternatingRowColors(True)
        self.output_tree.itemSelectionChanged.connect(self.on_output_selection_changed)
        outputs_layout.addWidget(self.output_tree)

        btn_open_selected = QPushButton("Open Selected Output")
        btn_open_selected.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogOpenButton))
        btn_open_selected.setProperty("role", "ghost")
        btn_open_selected.clicked.connect(self.open_selected_output)
        outputs_layout.addWidget(btn_open_selected)

        preview_title = QLabel("Output Preview")
        outputs_layout.addWidget(preview_title)
        self.output_preview = QPlainTextEdit()
        self.output_preview.setReadOnly(True)
        self.output_preview.setMaximumBlockCount(600)
        outputs_layout.addWidget(self.output_preview)
        right_tabs.addTab(outputs_tab, "Outputs")
        self.right_tabs = right_tabs

        splitter.addWidget(right_tabs)

        splitter.setStretchFactor(0, 1)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([760, 760])
        main_layout.addWidget(splitter)
        self.setLayout(main_layout)
        self.setup_shortcuts()
        self.setup_tooltips()
        self.apply_compact_mode(False)
        self.update_responsive_ui()
        self.update_context_help()
        self.populate_template_combo()
        self.populate_recent_combo()

    def _add_responsive_form_row(self, form_layout, long_text, short_text, field_widget, tooltip=""):
        label = QLabel(long_text)
        if tooltip:
            label.setToolTip(tooltip)
            field_widget.setToolTip(tooltip)
        form_layout.addRow(label, field_widget)
        self.responsive_labels.append((label, long_text, short_text))

    def build_physics_tab(self, right_tabs):
        physics_tab = QWidget()
        physics_layout = QVBoxLayout(physics_tab)
        physics_layout.setContentsMargins(10, 10, 10, 10)
        physics_layout.setSpacing(8)

        heading = QLabel("Physics-first phase builder")
        heading.setStyleSheet("QLabel { font-size: 12pt; font-weight: 700; color: #e9f4ff; }")
        physics_layout.addWidget(heading)

        phase_meta_group = QGroupBox("Phase selection")
        phase_meta_layout = QFormLayout(phase_meta_group)
        phase_meta_layout.setLabelAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        phase_meta_layout.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        phase_meta_layout.setHorizontalSpacing(10)
        phase_meta_layout.setVerticalSpacing(8)

        self.physics_type_combo = QComboBox()
        self.physics_type_combo.addItems([
            "ideal-gas",
            "heavy-gas",
            "condensed-dispersed",
            "solid",
            "real-gas",
        ])
        self.physics_type_combo.currentIndexChanged.connect(self.on_physics_type_changed)
        self._add_responsive_form_row(
            phase_meta_layout,
            "Phase type",
            "Type",
            self.physics_type_combo,
            "Select the physical model family for this phase.",
        )

        self.physics_name_edit = QLineEdit()
        self.physics_name_edit.setPlaceholderText("Optional phase name")
        self._add_responsive_form_row(
            phase_meta_layout,
            "Phase name",
            "Name",
            self.physics_name_edit,
            "Optional label to identify this phase.",
        )
        physics_layout.addWidget(phase_meta_group)

        self.physics_stack = QStackedWidget()

        ideal_content = QWidget()
        ideal_layout = QVBoxLayout(ideal_content)
        ideal_layout.setContentsMargins(0, 0, 0, 0)
        ideal_layout.setSpacing(8)

        ideal_models_group = QGroupBox("Models")
        ideal_models_form = QFormLayout(ideal_models_group)
        ideal_models_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        ideal_models_form.setHorizontalSpacing(10)
        ideal_models_form.setVerticalSpacing(8)

        self.physics_ideal_thermo = QComboBox()
        self.physics_ideal_thermo.addItems(self.thermo_options)
        self.physics_ideal_transport = QComboBox()
        self.physics_ideal_transport.addItems(self.transport_options)
        self.physics_ideal_inerts_mixing = QComboBox()
        self.physics_ideal_inerts_mixing.addItems(["False", "True"])
        self._add_responsive_form_row(ideal_models_form, "Thermo model", "Thermo", self.physics_ideal_thermo)
        self._add_responsive_form_row(ideal_models_form, "Transport model", "Transport", self.physics_ideal_transport)
        self._add_responsive_form_row(ideal_models_form, "Inerts mixing", "Inerts mix", self.physics_ideal_inerts_mixing)
        ideal_layout.addWidget(ideal_models_group)

        ideal_sources_group = QGroupBox("Composition sources")
        ideal_sources_form = QFormLayout(ideal_sources_group)
        ideal_sources_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        ideal_sources_form.setHorizontalSpacing(10)
        ideal_sources_form.setVerticalSpacing(8)
        self.physics_ideal_phase = QLineEdit()
        self.physics_ideal_phase.setPlaceholderText("Reference phase id")
        self.physics_ideal_reactions = QLineEdit()
        self.physics_ideal_reactions.setPlaceholderText("Reaction mechanism id")
        self.physics_ideal_species = QLineEdit()
        self.physics_ideal_species.setPlaceholderText("Species list, e.g. N2 O2")
        self.physics_ideal_add_species = QLineEdit()
        self.physics_ideal_add_species.setPlaceholderText("Additional species list")
        self.physics_ideal_mixture = QLineEdit()
        self.physics_ideal_mixture.setPlaceholderText("Mixture definition")
        self.physics_ideal_cp = QLineEdit()
        self.physics_ideal_cp.setPlaceholderText("cp definition")
        self._add_responsive_form_row(ideal_sources_form, "Reference phase", "Phase", self.physics_ideal_phase)
        self._add_responsive_form_row(ideal_sources_form, "Reactions", "Reactions", self.physics_ideal_reactions)
        self._add_responsive_form_row(ideal_sources_form, "Species", "Species", self.physics_ideal_species)
        self._add_responsive_form_row(ideal_sources_form, "Additional species", "Add-species", self.physics_ideal_add_species)
        self._add_responsive_form_row(ideal_sources_form, "Mixture", "Mixture", self.physics_ideal_mixture)
        self._add_responsive_form_row(ideal_sources_form, "cp", "cp", self.physics_ideal_cp)
        ideal_layout.addWidget(ideal_sources_group)

        ideal_mixture_group = QGroupBox("Mixture options")
        ideal_mixture_form = QFormLayout(ideal_mixture_group)
        ideal_mixture_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        ideal_mixture_form.setHorizontalSpacing(10)
        ideal_mixture_form.setVerticalSpacing(8)
        self.physics_ideal_mixture_name = QLineEdit()
        self.physics_ideal_mixture_name.setPlaceholderText("Optional label for selected mixture")
        self._add_responsive_form_row(ideal_mixture_form, "Mixture name", "Mix name", self.physics_ideal_mixture_name)
        ideal_layout.addWidget(ideal_mixture_group)
        ideal_layout.addStretch()

        ideal_scroll = QScrollArea()
        ideal_scroll.setWidgetResizable(True)
        ideal_scroll.setFrameShape(QFrame.Shape.NoFrame)
        ideal_scroll.setWidget(ideal_content)
        self.physics_stack.addWidget(ideal_scroll)

        condensed_content = QWidget()
        condensed_layout = QVBoxLayout(condensed_content)
        condensed_layout.setContentsMargins(0, 0, 0, 0)
        condensed_layout.setSpacing(8)

        condensed_models_group = QGroupBox("Models")
        condensed_models_form = QFormLayout(condensed_models_group)
        condensed_models_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        condensed_models_form.setHorizontalSpacing(10)
        condensed_models_form.setVerticalSpacing(8)
        self.physics_condensed_thermo = QComboBox()
        self.physics_condensed_thermo.addItems(self.thermo_options)
        self._add_responsive_form_row(condensed_models_form, "Thermo model", "Thermo", self.physics_condensed_thermo)
        condensed_layout.addWidget(condensed_models_group)

        condensed_material_group = QGroupBox("Material and properties")
        condensed_form = QFormLayout(condensed_material_group)
        condensed_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        condensed_form.setHorizontalSpacing(10)
        condensed_form.setVerticalSpacing(8)
        self.physics_condensed_material = QLineEdit()
        self.physics_condensed_material.setPlaceholderText("e.g. C(gr) or SiO2")
        self.physics_condensed_groups = QLineEdit()
        self.physics_condensed_groups.setPlaceholderText("Optional groups list")
        self.physics_condensed_cp = QLineEdit()
        self.physics_condensed_cp.setPlaceholderText("Optional cp values")
        self.physics_condensed_k = QLineEdit()
        self.physics_condensed_k.setPlaceholderText("Optional thermal conductivity values")
        self.physics_condensed_rho = QLineEdit()
        self.physics_condensed_rho.setPlaceholderText("Optional density values")
        self._add_responsive_form_row(condensed_form, "Material(s)", "Material", self.physics_condensed_material)
        self._add_responsive_form_row(condensed_form, "Groups", "Groups", self.physics_condensed_groups)
        self._add_responsive_form_row(condensed_form, "cp", "cp", self.physics_condensed_cp)
        self._add_responsive_form_row(condensed_form, "k", "k", self.physics_condensed_k)
        self._add_responsive_form_row(condensed_form, "rho", "rho", self.physics_condensed_rho)
        condensed_layout.addWidget(condensed_material_group)
        condensed_layout.addStretch()

        condensed_scroll = QScrollArea()
        condensed_scroll.setWidgetResizable(True)
        condensed_scroll.setFrameShape(QFrame.Shape.NoFrame)
        condensed_scroll.setWidget(condensed_content)
        self.physics_stack.addWidget(condensed_scroll)

        real_content = QWidget()
        real_layout = QVBoxLayout(real_content)
        real_layout.setContentsMargins(0, 0, 0, 0)
        real_layout.setSpacing(8)

        real_fluid_group = QGroupBox("Fluid and EOS")
        real_fluid_form = QFormLayout(real_fluid_group)
        real_fluid_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        real_fluid_form.setHorizontalSpacing(10)
        real_fluid_form.setVerticalSpacing(8)
        self.physics_real_fluid = QLineEdit()
        self.physics_real_fluid.setPlaceholderText("e.g. water, CO2")
        self.physics_real_model = QComboBox()
        self.physics_real_model.addItems(self.real_fluid_model_options)
        self._add_responsive_form_row(real_fluid_form, "Fluid", "Fluid", self.physics_real_fluid)
        self._add_responsive_form_row(real_fluid_form, "Model", "Model", self.physics_real_model)
        real_layout.addWidget(real_fluid_group)

        real_bounds_group = QGroupBox("Table bounds and resolution")
        real_form = QFormLayout(real_bounds_group)
        real_form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        real_form.setHorizontalSpacing(10)
        real_form.setVerticalSpacing(8)
        self.physics_real_tmin = QLineEdit("300")
        self.physics_real_tmax = QLineEdit("3000")
        self.physics_real_pmin = QLineEdit("100000")
        self.physics_real_pmax = QLineEdit("10000000")
        self.physics_real_np = QLineEdit("200")
        self.physics_real_nh = QLineEdit("200")
        self._add_responsive_form_row(real_form, "Tmin", "Tmin", self.physics_real_tmin)
        self._add_responsive_form_row(real_form, "Tmax", "Tmax", self.physics_real_tmax)
        self._add_responsive_form_row(real_form, "pmin", "pmin", self.physics_real_pmin)
        self._add_responsive_form_row(real_form, "pmax", "pmax", self.physics_real_pmax)
        self._add_responsive_form_row(real_form, "NP", "NP", self.physics_real_np)
        self._add_responsive_form_row(real_form, "NH", "NH", self.physics_real_nh)
        real_layout.addWidget(real_bounds_group)
        real_layout.addStretch()

        real_scroll = QScrollArea()
        real_scroll.setWidgetResizable(True)
        real_scroll.setFrameShape(QFrame.Shape.NoFrame)
        real_scroll.setWidget(real_content)
        self.physics_stack.addWidget(real_scroll)

        physics_layout.addWidget(self.physics_stack)

        self.physics_help = QLabel()
        self.physics_help.setWordWrap(True)
        self.physics_help.setStyleSheet(
            "QLabel {"
            "background-color: #152435;"
            "border: 1px solid #2f4760;"
            "border-radius: 8px;"
            "padding: 8px;"
            "color: #cfe3f6;"
            "}"
        )
        physics_layout.addWidget(self.physics_help)

        actions = QHBoxLayout()
        btn_create_phase = QPushButton("Create Phase from Physics")
        btn_create_phase.setProperty("role", "primary")
        btn_create_phase.clicked.connect(self.create_phase_from_physics)
        self.btn_create_phase = btn_create_phase
        actions.addWidget(btn_create_phase)

        btn_apply_phase = QPushButton("Apply to Selected Phase")
        btn_apply_phase.setProperty("role", "ghost")
        btn_apply_phase.clicked.connect(self.apply_physics_to_selected_phase)
        self.btn_apply_phase = btn_apply_phase
        actions.addWidget(btn_apply_phase)

        btn_load_phase = QPushButton("Load from Selected Phase")
        btn_load_phase.setProperty("role", "ghost")
        btn_load_phase.clicked.connect(self.load_selected_phase_to_physics)
        self.btn_load_phase = btn_load_phase
        actions.addWidget(btn_load_phase)
        physics_layout.addLayout(actions)

        physics_layout.addStretch()
        right_tabs.addTab(physics_tab, "Physics Builder")
        self.on_physics_type_changed()

    def setup_shortcuts(self):
        QShortcut(QKeySequence("Ctrl+N"), self, self.new_document)
        QShortcut(QKeySequence("Ctrl+O"), self, self.open_ini)
        QShortcut(QKeySequence("Ctrl+S"), self, self.save_ini)
        QShortcut(QKeySequence("Ctrl+Shift+S"), self, self.save_ini_as)
        QShortcut(QKeySequence("Ctrl+R"), self, self.run_gpb)
        QShortcut(QKeySequence("Ctrl+Return"), self, self.validate_only)
        QShortcut(QKeySequence("Ctrl+Shift+Return"), self, self.apply_physics_to_selected_phase)

    def setup_tooltips(self):
        self.workdir_edit.setToolTip("Directory where input.ini is written and GPB runs")
        self.recent_combo.setToolTip("Recent INI files opened or saved")
        self.template_combo.setToolTip("Reference templates discovered in test/GPB")
        self.tree.setToolTip("Phase sections and key/value entries. Click diagnostics to jump to issues.")
        self.diagnostics.setToolTip("Validation diagnostics and actionable issues")
        self.logs.setToolTip("Live GPB stdout/stderr stream")
        self.output_tree.setToolTip("Generated files grouped by GPB phase")
        self.output_preview.setToolTip("Preview of selected output file")
        self.physics_type_combo.setToolTip("Select the physics family you want to build")
        self.physics_name_edit.setToolTip("Optional readable phase name")

    def on_compact_toggled(self, checked):
        self.apply_compact_mode(bool(checked))
        self.update_responsive_ui()
        self.save_session_state()

    def apply_compact_mode(self, compact):
        self.compact_mode = compact
        self.setProperty("compact", "true" if compact else "false")
        self.style().unpolish(self)
        self.style().polish(self)

    def update_responsive_ui(self):
        narrow = self.width() < 1320

        for label, long_text, short_text in self.responsive_labels:
            label.setText(short_text if narrow else long_text)

        self.btn_import_legacy.setText("Import" if narrow else "Import Legacy")
        self.btn_open_recent.setText("Open" if narrow else "Open Recent")
        self.btn_load_template.setText("Load" if narrow else "Load Template")
        self.btn_delete_section.setText("Del Section" if narrow else "Delete Section")
        self.btn_delete_key.setText("Del Key" if narrow else "Delete Key")
        self.btn_create_phase.setText("Create Phase" if narrow else "Create Phase from Physics")
        self.btn_apply_phase.setText("Apply" if narrow else "Apply to Selected Phase")
        self.btn_load_phase.setText("Load Phase" if narrow else "Load from Selected Phase")

        if hasattr(self, "right_tabs"):
            self.right_tabs.setTabText(1, "Workflow")
            self.right_tabs.setTabText(2, "Activity" if narrow else "Diagnostics & Logs")

        self.adjust_tree_columns()

    def adjust_tree_columns(self):
        if not hasattr(self, "tree"):
            return
        viewport_width = max(200, self.tree.viewport().width())
        left_col = min(420, max(220, int(viewport_width * 0.46)))
        self.tree.setColumnWidth(0, left_col)

    def set_runner_status(self, state, text):
        self.run_status.setProperty("state", state)
        self.run_status.setText(text)
        self.run_status.style().unpolish(self.run_status)
        self.run_status.style().polish(self.run_status)

    def on_tree_current_item_changed(self, _current, _previous):
        self.update_context_help()
        self.load_selected_phase_to_physics(warn_on_missing=False)

    def on_physics_type_changed(self):
        phase_type = self.physics_type_combo.currentText().strip().lower()
        if "real" in phase_type:
            self.physics_stack.setCurrentIndex(2)
            self.physics_help.setText(
                "Real-fluid setup requires fluid + p/T bounds. NP and NH control lookup-table resolution."
            )
        elif "solid" in phase_type or "condensed" in phase_type:
            self.physics_stack.setCurrentIndex(1)
            self.physics_help.setText(
                "Condensed/solid setup focuses on material and thermo model; cp/k/rho can be explicit."
            )
        else:
            self.physics_stack.setCurrentIndex(0)
            self.physics_help.setText(
                "Ideal/heavy setup exposes all source entries at once (phase, reactions, species, add-species, mixture, cp)."
            )

    def _resolve_selected_phase_item(self):
        selected = self.tree.currentItem()
        if selected is None:
            return None
        if selected.parent() is None:
            return selected
        return selected.parent()

    def _find_phase_key_item(self, phase_item, key):
        for i in range(phase_item.childCount()):
            key_item = phase_item.child(i)
            if self._extract_key_from_item(key_item) == key:
                return key_item
        return None

    def _set_phase_key(self, phase_item, key, value):
        key_item = self._find_phase_key_item(phase_item, key)
        if key_item is None:
            key_item = QTreeWidgetItem(phase_item, [key])
        self._set_value_widget_for_loaded_key(key_item, key, str(value))

    def _remove_phase_key(self, phase_item, key):
        key_item = self._find_phase_key_item(phase_item, key)
        if key_item is not None:
            phase_item.removeChild(key_item)

    def collect_physics_payload(self):
        phase_type = self.physics_type_combo.currentText().strip()
        payload = {"type": phase_type}

        name = self.physics_name_edit.text().strip()
        if name:
            payload["name"] = name

        if "real" in phase_type:
            for key, widget in [
                ("fluid", self.physics_real_fluid),
                ("Tmin", self.physics_real_tmin),
                ("Tmax", self.physics_real_tmax),
                ("pmin", self.physics_real_pmin),
                ("pmax", self.physics_real_pmax),
                ("NP", self.physics_real_np),
                ("NH", self.physics_real_nh),
            ]:
                val = widget.text().strip()
                if val:
                    payload[key] = val
            payload["model"] = self.physics_real_model.currentText().strip()
            return payload

        if "solid" in phase_type or "condensed" in phase_type:
            payload["thermo"] = self.physics_condensed_thermo.currentText().strip()
            for key, widget in [
                ("material", self.physics_condensed_material),
                ("groups", self.physics_condensed_groups),
                ("cp", self.physics_condensed_cp),
                ("k", self.physics_condensed_k),
                ("rho", self.physics_condensed_rho),
            ]:
                val = widget.text().strip()
                if val:
                    payload[key] = val
            return payload

        payload["thermo"] = self.physics_ideal_thermo.currentText().strip()
        payload["transport"] = self.physics_ideal_transport.currentText().strip()
        payload["inerts-mixing"] = self.physics_ideal_inerts_mixing.currentText().strip()
        for key, widget in [
            ("phase", self.physics_ideal_phase),
            ("reactions", self.physics_ideal_reactions),
            ("species", self.physics_ideal_species),
            ("add-species", self.physics_ideal_add_species),
            ("mixture", self.physics_ideal_mixture),
            ("cp", self.physics_ideal_cp),
        ]:
            value = widget.text().strip()
            if value:
                payload[key] = value
        mixture_name = self.physics_ideal_mixture_name.text().strip()
        if mixture_name:
            payload["mixture-name"] = mixture_name
        return payload

    def apply_payload_to_phase_item(self, phase_item, payload):
        phase_type = payload.get("type", "").lower()
        base_keys = {"type", "name"}
        ideal_keys = base_keys | {
            "thermo", "transport", "inerts-mixing", "species", "add-species", "reactions", "phase", "mixture", "mixture-name"
        }
        condensed_keys = base_keys | {"thermo", "material", "groups", "cp", "k", "rho"}
        real_keys = base_keys | {"fluid", "model", "Tmin", "Tmax", "pmin", "pmax", "NP", "NH"}

        if "real" in phase_type:
            allowed = real_keys
        elif "solid" in phase_type or "condensed" in phase_type:
            allowed = condensed_keys
        else:
            allowed = ideal_keys

        existing = []
        for i in range(phase_item.childCount()):
            key_item = phase_item.child(i)
            existing.append((key_item, self._extract_key_from_item(key_item)))

        for key_item, key in existing:
            if key not in allowed:
                phase_item.removeChild(key_item)

        for key, value in payload.items():
            if str(value).strip() == "":
                continue
            self._set_phase_key(phase_item, key, value)

        self.tree.setCurrentItem(phase_item)
        self.collect_document()
        self.update_context_help()

    def apply_physics_to_selected_phase(self):
        phase_item = self._resolve_selected_phase_item()
        if phase_item is None:
            QMessageBox.warning(self, "No phase selected", "Select a phase in the tree, or create one from physics.")
            return
        payload = self.collect_physics_payload()
        self.apply_payload_to_phase_item(phase_item, payload)

    def create_phase_from_physics(self):
        self.add_phase()
        phase_item = self._resolve_selected_phase_item()
        if phase_item is None:
            return
        payload = self.collect_physics_payload()
        self.apply_payload_to_phase_item(phase_item, payload)

    def load_selected_phase_to_physics(self, warn_on_missing=True):
        phase_item = self._resolve_selected_phase_item()
        if phase_item is None:
            if warn_on_missing:
                QMessageBox.warning(self, "No phase selected", "Select a phase in the tree first.")
            return

        section = phase_item.text(0).strip()
        self.collect_document()
        if self.config.has_section(section):
            data = dict(self.config.items(section))
        else:
            data = {}

        phase_type = data.get("type", "ideal-gas").strip()
        idx = self.physics_type_combo.findText(phase_type)
        if idx >= 0:
            self.physics_type_combo.setCurrentIndex(idx)
        self.physics_name_edit.setText(data.get("name", "").strip())

        if "real" in phase_type.lower():
            self.physics_real_fluid.setText(data.get("fluid", "").strip())
            model_idx = self.physics_real_model.findText(data.get("model", "").strip().lower())
            if model_idx >= 0:
                self.physics_real_model.setCurrentIndex(model_idx)
            self.physics_real_tmin.setText(data.get("Tmin", "").strip())
            self.physics_real_tmax.setText(data.get("Tmax", "").strip())
            self.physics_real_pmin.setText(data.get("pmin", "").strip())
            self.physics_real_pmax.setText(data.get("pmax", "").strip())
            self.physics_real_np.setText(data.get("NP", "").strip())
            self.physics_real_nh.setText(data.get("NH", "").strip())
            self.on_physics_type_changed()
            return

        if "solid" in phase_type.lower() or "condensed" in phase_type.lower():
            thermo_idx = self.physics_condensed_thermo.findText(data.get("thermo", "").strip())
            if thermo_idx >= 0:
                self.physics_condensed_thermo.setCurrentIndex(thermo_idx)
            self.physics_condensed_material.setText(data.get("material", "").strip())
            self.physics_condensed_groups.setText(data.get("groups", "").strip())
            self.physics_condensed_cp.setText(data.get("cp", "").strip())
            self.physics_condensed_k.setText(data.get("k", "").strip())
            self.physics_condensed_rho.setText(data.get("rho", "").strip())
            self.on_physics_type_changed()
            return

        thermo_idx = self.physics_ideal_thermo.findText(data.get("thermo", "").strip())
        if thermo_idx >= 0:
            self.physics_ideal_thermo.setCurrentIndex(thermo_idx)
        transport_idx = self.physics_ideal_transport.findText(data.get("transport", "").strip())
        if transport_idx >= 0:
            self.physics_ideal_transport.setCurrentIndex(transport_idx)
        mix_idx = self.physics_ideal_inerts_mixing.findText(data.get("inerts-mixing", "False").strip())
        if mix_idx >= 0:
            self.physics_ideal_inerts_mixing.setCurrentIndex(mix_idx)
        self.physics_ideal_phase.setText(data.get("phase", "").strip())
        self.physics_ideal_reactions.setText(data.get("reactions", "").strip())
        self.physics_ideal_species.setText(data.get("species", "").strip())
        self.physics_ideal_add_species.setText(data.get("add-species", "").strip())
        self.physics_ideal_mixture.setText(data.get("mixture", "").strip())
        self.physics_ideal_cp.setText(data.get("cp", "").strip())
        self.physics_ideal_mixture_name.setText(data.get("mixture-name", "").strip())
        self.on_physics_type_changed()

    def update_context_help(self):
        selected = self.tree.currentItem()
        if selected is None:
            self.context_hint.setText(
                "Tip: Start with Add Phase, then set type and provide required keys. "
                "Use Validate before saving or running."
            )
            return

        parent = selected.parent()
        if parent is None:
            section = selected.text(0).strip()
            phase_type = self.config.get(section, "type", fallback="").strip().lower() if section in self.config else ""
            if "real" in phase_type:
                hint = "Real-fluid phase: required fluid, pmin, pmax, Tmin, Tmax. Optional NP and NH control table resolution."
            elif "ideal" in phase_type or "heavy" in phase_type:
                hint = "Ideal/heavy phase: provide at least one source among phase/reactions/species/add-species/mixture/cp."
            elif "solid" in phase_type or "condensed" in phase_type:
                hint = "Condensed/solid phase: usually define material and thermo model; cp/k/rho can be explicit."
            else:
                hint = "Set key type first, then fill required fields for that phase family."
            self.context_hint.setText(f"Selected section: {section}\n{hint}")
            return

        key = self._extract_key_from_item(selected)
        generic = {
            "type": "Choose the phase family; this drives validation and GPB builder routing.",
            "species": "Space-separated species list or add-species alternative.",
            "reactions": "Reaction mechanism identifier used by GPB chemistry build.",
            "fluid": "Fluid name for real-fluid tables (e.g., water, CO2).",
            "Tmin": "Minimum temperature bound for property generation.",
            "Tmax": "Maximum temperature bound for property generation.",
            "pmin": "Minimum pressure bound for real-fluid tables.",
            "pmax": "Maximum pressure bound for real-fluid tables.",
            "NP": "Pressure grid points. Higher values increase table cost.",
            "NH": "Enthalpy grid points. Higher values increase table cost.",
            "material": "Material names for condensed/solid phases.",
            "transport": "Transport model selection for ideal/condensed cases.",
        }
        message = generic.get(key, "Edit value and run Validate to ensure GPB compatibility.")
        self.context_hint.setText(f"Selected key: {key}\n{message}")

    def update_file_label(self):
        if self.current_file is None:
            current_text = "Current file: (unsaved) input.ini"
        else:
            current_text = f"Current file: {self.current_file}"

        workdir = self.workdir_edit.text().strip() if hasattr(self, "workdir_edit") else ""
        if workdir:
            current_text = f"{current_text}\nWorking directory: {workdir}"
        self.file_label.setText(current_text)

    def new_document(self):
        self.tree.clear()
        self.phase_count = 0
        self.current_file = os.path.join(os.getcwd(), "input.ini")
        self.workdir_edit.setText(os.getcwd())
        self.set_runner_status("idle", "Runner: idle")
        self.clear_diagnostics()
        self.refresh_output_browser()
        self.update_file_label()
        self.update_context_help()
        self.save_session_state()

    def add_phase(self):
        self.phase_count += 1
        phase_name = f"GPB-Phase{self.phase_count}"
        phase_item = QTreeWidgetItem(self.tree, [phase_name])
        self.tree.setCurrentItem(phase_item)

        # Automatically add the default required key
        type_item = QTreeWidgetItem(phase_item, ["type"])
        combo_box = QComboBox()
        combo_box.addItems(self.type_options)
        self.tree.setItemWidget(type_item, 1, combo_box)
        self.update_context_help()

    def add_key(self):
        selected_item = self.tree.currentItem()
        if not selected_item or selected_item.parent() is not None:
            QMessageBox.warning(self, "Warning", "Please select a phase to add a key.")
            return

        key_selector = QComboBox()
        key_selector.addItems(sorted(self.available_keys.keys()))
        key_item = QTreeWidgetItem(selected_item, [""])
        self.tree.setItemWidget(key_item, 0, key_selector)
        key_selector.currentIndexChanged.connect(
            lambda: self.update_value_widget(key_item, key_selector)
        )
        self.update_value_widget(key_item, key_selector)
        self.update_context_help()

    def delete_section(self):
        selected_item = self.tree.currentItem()
        if selected_item and selected_item.parent() is None:
            reply = QMessageBox.question(
                self, "Confirm Delete",
                f"Delete section '{selected_item.text(0)}'?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if reply == QMessageBox.StandardButton.Yes:
                index = self.tree.indexOfTopLevelItem(selected_item)
                self.tree.takeTopLevelItem(index)
                self.update_context_help()

    def delete_key(self):
        selected_item = self.tree.currentItem()
        if selected_item and selected_item.parent() is not None:
            reply = QMessageBox.question(
                self, "Confirm Delete", "Delete selected key?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if reply == QMessageBox.StandardButton.Yes:
                parent = selected_item.parent()
                parent.removeChild(selected_item)
                self.update_context_help()

    def update_value_widget(self, key_item, key_selector):
        key = key_selector.currentText()
        value_options = self.available_keys.get(key)
        if value_options is None:
            text_input = QLineEdit()
            self.tree.setItemWidget(key_item, 1, text_input)
        else:
            value_widget = QComboBox()
            value_widget.addItems(value_options)
            self.tree.setItemWidget(key_item, 1, value_widget)

    def _set_value_widget_for_loaded_key(self, key_item, key, value):
        value_options = self.available_keys.get(key)
        if value_options is None:
            value_widget = QLineEdit()
            value_widget.setText(value)
            self.tree.setItemWidget(key_item, 1, value_widget)
            return

        value_widget = QComboBox()
        value_widget.addItems(value_options)
        matched_index = value_widget.findText(value)
        if matched_index >= 0:
            value_widget.setCurrentIndex(matched_index)
        else:
            value_widget.setEditable(True)
            value_widget.setCurrentText(value)
        self.tree.setItemWidget(key_item, 1, value_widget)

    def _extract_key_from_item(self, key_item):
        key_widget = self.tree.itemWidget(key_item, 0)
        if isinstance(key_widget, QComboBox):
            return key_widget.currentText().strip()
        return key_item.text(0).strip()

    def _extract_value_from_item(self, key_item):
        value_widget = self.tree.itemWidget(key_item, 1)
        if isinstance(value_widget, QComboBox):
            return value_widget.currentText().strip()
        if isinstance(value_widget, QLineEdit):
            return value_widget.text().strip()
        return ""

    def collect_document(self):
        self.config.clear()
        section_items = {}
        duplicate_keys = []

        for i in range(self.tree.topLevelItemCount()):
            phase_item = self.tree.topLevelItem(i)
            section = phase_item.text(0).strip()
            self.config[section] = {}
            section_items[section] = phase_item
            seen_keys = set()

            for j in range(phase_item.childCount()):
                key_item = phase_item.child(j)
                key = self._extract_key_from_item(key_item)
                value = self._extract_value_from_item(key_item)
                if key in seen_keys:
                    duplicate_keys.append((section, key, key_item))
                seen_keys.add(key)
                self.config[section][key] = value

        return section_items, duplicate_keys

    def validate_document(self):
        section_items, duplicate_keys = self.collect_document()
        diagnostics = []

        if self.tree.topLevelItemCount() == 0:
            diagnostics.append(("error", "No GPB phase defined. Add at least one GPB-Phase section.", None))
            return diagnostics

        section_pattern = re.compile(r"^GPB-Phase\d+$")
        seen_sections = set()

        for i in range(self.tree.topLevelItemCount()):
            phase_item = self.tree.topLevelItem(i)
            section = phase_item.text(0).strip()

            if section in seen_sections:
                diagnostics.append(("error", f"Duplicated section name: {section}", phase_item))
            seen_sections.add(section)

            if not section_pattern.match(section):
                diagnostics.append(
                    (
                        "error",
                        f"Section {section} does not match GPB-PhaseN naming.",
                        phase_item,
                    )
                )

            if self.config.has_section(section):
                section_data = dict(self.config.items(section))
            else:
                section_data = {}
            phase_type = section_data.get("type", "").strip().lower()
            if not phase_type:
                diagnostics.append(("error", f"Section {section} is missing key type.", phase_item))
                continue

            if not any(token in phase_type for token in ["ideal", "heavy", "solid", "condensed", "real"]):
                diagnostics.append(
                    (
                        "error",
                        f"Section {section} has unsupported type {phase_type}.",
                        phase_item,
                    )
                )
                continue

            if "real" in phase_type:
                for required_key in ["fluid", "pmin", "pmax", "Tmin", "Tmax"]:
                    if not section_data.get(required_key, "").strip():
                        diagnostics.append(
                            (
                                "error",
                                f"Section {section}: missing required key {required_key} for real fluid.",
                                phase_item,
                            )
                        )

            if "ideal" in phase_type or "heavy" in phase_type:
                has_source = any(
                    section_data.get(key, "").strip()
                    for key in ["phase", "reactions", "species", "add-species", "mixture", "cp"]
                )
                if not has_source:
                    diagnostics.append(
                        (
                            "error",
                            f"Section {section}: add one source among phase/reactions/species/add-species/mixture/cp.",
                            phase_item,
                        )
                    )

        for section, key, key_item in duplicate_keys:
            diagnostics.append(("error", f"Section {section} contains duplicated key {key}.", key_item))

        if not diagnostics:
            diagnostics.append(("ok", "Validation passed. Document is ready to save.", None))

        return diagnostics

    def clear_diagnostics(self):
        self.diagnostics.clear()
        self.diagnostic_item_map = {}

    def show_diagnostics(self, diagnostics):
        self.clear_diagnostics()
        for idx, (severity, message, item) in enumerate(diagnostics):
            if severity == "error":
                prefix = "[ERROR]"
            elif severity == "ok":
                prefix = "[OK]"
            else:
                prefix = "[INFO]"

            row_text = f"{prefix} {message}"
            self.diagnostics.addItem(QListWidgetItem(row_text))
            if item is not None:
                self.diagnostic_item_map[idx] = item

    def focus_diagnostic_item(self, list_item):
        row = self.diagnostics.row(list_item)
        item = self.diagnostic_item_map.get(row)
        if item is None:
            return
        self.tree.setCurrentItem(item)
        self.tree.scrollToItem(item)

    def validate_only(self):
        diagnostics = self.validate_document()
        self.show_diagnostics(diagnostics)

    def open_ini(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Open INI File",
            os.getcwd(),
            "INI files (*.ini);;All files (*)",
        )
        if not file_path:
            return

        self.load_from_file(file_path)

        if os.path.basename(file_path) == "config.ini":
            QMessageBox.information(
                self,
                "Legacy file loaded",
                "Loaded legacy config.ini. Save As will default to input.ini.",
            )

    def import_legacy_config(self):
        default_path = os.path.join(os.getcwd(), "config.ini")
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Import legacy config.ini",
            default_path,
            "INI files (*.ini);;All files (*)",
        )
        if not file_path:
            return

        self.load_from_file(file_path)
        self.current_file = os.path.join(os.path.dirname(file_path), "input.ini")
        self.workdir_edit.setText(os.path.dirname(file_path))
        self.update_file_label()
        self.add_recent_file(file_path)
        self.save_session_state()
        QMessageBox.information(
            self,
            "Legacy import complete",
            "Legacy file imported. Next save target is input.ini.",
        )

    def load_from_file(self, file_path):
        loaded_cfg = configparser.ConfigParser()
        loaded_cfg.optionxform = str
        loaded_cfg.read(file_path)

        self.tree.clear()
        self.phase_count = 0

        for section in loaded_cfg.sections():
            phase_item = QTreeWidgetItem(self.tree, [section])
            phase_match = re.match(r"^GPB-Phase(\d+)$", section)
            if phase_match:
                self.phase_count = max(self.phase_count, int(phase_match.group(1)))

            for key, value in loaded_cfg[section].items():
                key_item = QTreeWidgetItem(phase_item, [key])
                self._set_value_widget_for_loaded_key(key_item, key, value)

        self.current_file = file_path
        self.workdir_edit.setText(os.path.dirname(file_path))
        self.update_file_label()
        self.clear_diagnostics()
        self.refresh_output_browser()
        self.add_recent_file(file_path)
        self.save_session_state()

    def save_ini(self):
        diagnostics = self.validate_document()
        self.show_diagnostics(diagnostics)
        has_error = any(severity == "error" for severity, _, _ in diagnostics)
        if has_error:
            QMessageBox.warning(self, "Validation failed", "Fix diagnostics before saving.")
            return

        target_file = self.current_file
        if target_file is None:
            target_file = os.path.join(os.getcwd(), "input.ini")

        self.write_ini_file(target_file)

    def save_ini_as(self):
        suggested = self.current_file if self.current_file else os.path.join(os.getcwd(), "input.ini")
        file_path, _ = QFileDialog.getSaveFileName(
            self,
            "Save INI File",
            suggested,
            "INI files (*.ini);;All files (*)",
        )
        if not file_path:
            return

        self.current_file = file_path
        self.update_file_label()
        self.save_session_state()
        self.save_ini()

    def write_ini_file(self, file_path, show_message=True):
        self.collect_document()
        
        with open(file_path, "w", encoding="utf-8") as file:
            self.config.write(file)

        self.add_recent_file(file_path)
        self.save_session_state()

        if show_message:
            QMessageBox.information(self, "Success", f"INI file saved successfully: {file_path}")

    def select_working_directory(self):
        selected = QFileDialog.getExistingDirectory(
            self,
            "Select GPB working directory",
            self.workdir_edit.text().strip() or os.getcwd(),
        )
        if selected:
            self.workdir_edit.setText(selected)
            self.update_file_label()
            self.refresh_output_browser()
            self.save_session_state()

    def on_workdir_edit_finished(self):
        self.update_file_label()
        self.refresh_output_browser()
        self.save_session_state()

    def append_log(self, text):
        if not text:
            return
        self.logs.appendPlainText(text.rstrip())

    def get_phase_definitions(self):
        self.collect_document()
        phases = []
        for i in range(self.tree.topLevelItemCount()):
            phase_item = self.tree.topLevelItem(i)
            section = phase_item.text(0).strip()
            phase_type = self.config.get(section, "type", fallback="").strip().lower()
            phases.append((section, phase_type))
        return phases

    def verify_output_artifacts(self):
        workdir = self.workdir_edit.text().strip()
        output_dir = os.path.join(workdir, "fromATLAStoSolver")
        if not os.path.isdir(output_dir):
            return ["Output directory fromATLAStoSolver does not exist."]

        missing = []
        for section, _phase_type in self.get_phase_definitions():
            required_suffixes = ["phase.txt", "thermo.dat", "transport.dat"]
            for suffix in required_suffixes:
                path = os.path.join(output_dir, f"{section}{suffix}")
                if not os.path.isfile(path):
                    missing.append(f"Missing {section}{suffix}")
        return missing

    def refresh_output_browser(self):
        self.output_tree.clear()
        self.output_preview.clear()

        workdir = self.workdir_edit.text().strip()
        if not workdir:
            return

        output_dir = os.path.join(workdir, "fromATLAStoSolver")
        if not os.path.isdir(output_dir):
            root = QTreeWidgetItem(self.output_tree, ["fromATLAStoSolver not found"])
            root.setData(0, Qt.ItemDataRole.UserRole, None)
            return

        phase_groups = {}
        pattern = re.compile(r"^(GPB-Phase\d+)(.+)$")
        for name in sorted(os.listdir(output_dir)):
            file_path = os.path.join(output_dir, name)
            if not os.path.isfile(file_path):
                continue
            match = pattern.match(name)
            if not match:
                continue
            phase, suffix = match.groups()
            phase_groups.setdefault(phase, []).append((name, suffix, file_path))

        if not phase_groups:
            root = QTreeWidgetItem(self.output_tree, ["No GPB-Phase files found"])
            root.setData(0, Qt.ItemDataRole.UserRole, None)
            return

        for phase in sorted(phase_groups.keys(), key=self._phase_sort_key):
            top = QTreeWidgetItem(self.output_tree, [phase])
            top.setData(0, Qt.ItemDataRole.UserRole, None)
            for file_name, _suffix, file_path in sorted(phase_groups[phase], key=lambda x: x[0]):
                child = QTreeWidgetItem(top, [file_name])
                child.setData(0, Qt.ItemDataRole.UserRole, file_path)

        self.output_tree.expandAll()

    def _phase_sort_key(self, section):
        match = re.match(r"^GPB-Phase(\d+)$", section)
        if match:
            return int(match.group(1))
        return 10**9

    def on_output_selection_changed(self):
        selected = self.output_tree.selectedItems()
        if not selected:
            self.output_preview.clear()
            return

        item = selected[0]
        file_path = item.data(0, Qt.ItemDataRole.UserRole)
        if not file_path:
            self.output_preview.clear()
            return

        self.output_preview.setPlainText(self.read_preview(file_path))

    def read_preview(self, file_path, max_lines=80):
        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as handle:
                lines = []
                for idx, line in enumerate(handle):
                    if idx >= max_lines:
                        lines.append("... [truncated]")
                        break
                    lines.append(line.rstrip("\n"))
                return "\n".join(lines)
        except OSError as exc:
            return f"Cannot read output file: {exc}"

    def open_outputs_folder(self):
        workdir = self.workdir_edit.text().strip()
        output_dir = os.path.join(workdir, "fromATLAStoSolver")
        if not os.path.isdir(output_dir):
            QMessageBox.warning(self, "Missing folder", "fromATLAStoSolver directory not found.")
            return
        QDesktopServices.openUrl(QUrl.fromLocalFile(output_dir))

    def open_selected_output(self):
        selected = self.output_tree.selectedItems()
        if not selected:
            return
        file_path = selected[0].data(0, Qt.ItemDataRole.UserRole)
        if not file_path:
            return
        QDesktopServices.openUrl(QUrl.fromLocalFile(file_path))

    def discover_templates(self):
        templates = []
        if not os.path.isdir(self.templates_root):
            return templates

        for case_name in sorted(os.listdir(self.templates_root)):
            input_path = os.path.join(self.templates_root, case_name, "input.ini")
            if os.path.isfile(input_path):
                templates.append((case_name, input_path))
        return templates

    def populate_template_combo(self):
        self.template_combo.clear()
        for case_name, input_path in self.discover_templates():
            self.template_combo.addItem(case_name, input_path)

    def load_selected_template(self):
        idx = self.template_combo.currentIndex()
        if idx < 0:
            QMessageBox.warning(self, "No template", "No template selected.")
            return

        template_path = self.template_combo.itemData(idx)
        if not template_path or not os.path.isfile(template_path):
            QMessageBox.warning(self, "Missing template", "Selected template file not found.")
            return

        self.load_from_file(template_path)
        template_dir = os.path.dirname(template_path)
        self.workdir_edit.setText(template_dir)
        self.current_file = os.path.join(template_dir, "input.ini")
        self.update_file_label()
        self.refresh_output_browser()
        self.save_session_state()
        self.append_log(f"[template] loaded {template_path}")

    def add_recent_file(self, file_path):
        if not file_path:
            return
        abs_path = os.path.abspath(file_path)
        if abs_path in self.recent_files:
            self.recent_files.remove(abs_path)
        self.recent_files.insert(0, abs_path)
        self.recent_files = [p for p in self.recent_files if os.path.isfile(p)][:12]
        self.populate_recent_combo()

    def populate_recent_combo(self):
        self.recent_combo.clear()
        for path in self.recent_files:
            label = os.path.basename(path)
            self.recent_combo.addItem(label, path)

    def open_recent_selected(self):
        idx = self.recent_combo.currentIndex()
        if idx < 0:
            return
        selected_path = self.recent_combo.itemData(idx)
        if not selected_path or not os.path.isfile(selected_path):
            QMessageBox.warning(self, "Missing file", "Selected recent file no longer exists.")
            return
        self.load_from_file(selected_path)

    def save_session_state(self):
        self.settings.setValue("windowGeometry", self.saveGeometry())
        self.settings.setValue("compactMode", self.compact_mode)
        self.settings.setValue("workingDirectory", self.workdir_edit.text().strip())
        self.settings.setValue("currentFile", self.current_file or "")
        self.settings.setValue("recentFiles", self.recent_files)

    def restore_session_state(self):
        geometry = self.settings.value("windowGeometry")
        if geometry:
            self.restoreGeometry(geometry)

        compact_mode = self.settings.value("compactMode", False)
        if isinstance(compact_mode, str):
            compact_mode = compact_mode.lower() in ["1", "true", "yes", "on"]
        compact_mode = bool(compact_mode)
        self.compact_toggle.blockSignals(True)
        self.compact_toggle.setChecked(compact_mode)
        self.compact_toggle.blockSignals(False)
        self.apply_compact_mode(compact_mode)

        recent = self.settings.value("recentFiles", [])
        if isinstance(recent, str):
            recent = [recent] if recent else []
        self.recent_files = [p for p in recent if p and os.path.isfile(p)]
        self.populate_recent_combo()

        workdir = self.settings.value("workingDirectory", "")
        if workdir and os.path.isdir(workdir):
            self.workdir_edit.setText(workdir)
        else:
            self.workdir_edit.setText(os.getcwd())

        current_file = self.settings.value("currentFile", "")
        if current_file and os.path.isfile(current_file):
            self.load_from_file(current_file)
            return True

        self.current_file = os.path.join(self.workdir_edit.text().strip(), "input.ini")
        self.update_file_label()
        self.refresh_output_browser()
        self.update_responsive_ui()
        return False

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.update_responsive_ui()

    def closeEvent(self, event):
        self.save_session_state()
        super().closeEvent(event)

    def run_preflight(self):
        diagnostics = self.validate_document()
        self.show_diagnostics(diagnostics)
        has_error = any(severity == "error" for severity, _, _ in diagnostics)
        if has_error:
            return False, "Validation failed. Fix diagnostics before running GPB."

        workdir = self.workdir_edit.text().strip()
        if not workdir:
            return False, "Working directory is empty."
        if not os.path.isdir(workdir):
            return False, f"Working directory does not exist: {workdir}"
        if not os.access(workdir, os.W_OK):
            return False, f"Working directory is not writable: {workdir}"

        atlasdir = os.environ.get("ATLASDIR", "").strip()
        if not atlasdir:
            atlasdir = self.atlas_root
        if not os.path.isdir(atlasdir):
            return False, f"ATLASDIR is invalid: {atlasdir}"

        data_dir = os.path.join(atlasdir, "database")
        if not os.path.isdir(data_dir):
            return False, f"ATLAS database directory not found: {data_dir}"

        if not os.path.isfile(self.gpb_entrypoint):
            return False, f"GPB entrypoint not found: {self.gpb_entrypoint}"

        input_path = os.path.join(workdir, "input.ini")
        try:
            self.write_ini_file(input_path, show_message=False)
        except OSError as exc:
            return False, f"Cannot write input.ini in working directory: {exc}"

        output_dir = os.path.join(workdir, "fromATLAStoSolver")
        try:
            os.makedirs(output_dir, exist_ok=True)
        except OSError as exc:
            return False, f"Cannot create output directory fromATLAStoSolver: {exc}"

        if not os.access(output_dir, os.W_OK):
            return False, f"Output directory is not writable: {output_dir}"

        return True, "Preflight checks passed."

    def run_gpb(self):
        if self.process is not None and self.process.state() != QProcess.ProcessState.NotRunning:
            QMessageBox.warning(self, "Runner busy", "GPB is already running.")
            return

        ok, message = self.run_preflight()
        self.append_log(f"[preflight] {message}")
        if not ok:
            self.set_runner_status("error", "Runner: preflight failed")
            QMessageBox.warning(self, "Preflight failed", message)
            return

        workdir = self.workdir_edit.text().strip()
        atlasdir = os.environ.get("ATLASDIR", "").strip() or self.atlas_root

        self.process = QProcess(self)
        self.process.setProgram(sys.executable)
        self.process.setArguments(["-B", self.gpb_entrypoint])
        self.process.setWorkingDirectory(workdir)

        env = QProcessEnvironment.systemEnvironment()
        env.insert("ATLASDIR", atlasdir)
        env.insert("PYTHONUNBUFFERED", "1")
        self.process.setProcessEnvironment(env)

        self.process.started.connect(self.on_process_started)
        self.process.readyReadStandardOutput.connect(self.on_process_stdout)
        self.process.readyReadStandardError.connect(self.on_process_stderr)
        self.process.finished.connect(self.on_process_finished)
        self.process.errorOccurred.connect(self.on_process_error)

        self.append_log(
            f"[run] launching: {sys.executable} -B {self.gpb_entrypoint} (cwd={workdir})"
        )
        self.process.start()

    def stop_gpb(self):
        if self.process is None:
            return
        if self.process.state() == QProcess.ProcessState.NotRunning:
            return
        self.append_log("[run] stop requested")
        self.process.terminate()

    def on_process_started(self):
        self.btn_run.setEnabled(False)
        self.btn_stop.setEnabled(True)
        self.set_runner_status("running", "Runner: running")
        self.append_log("[run] process started")

    def on_process_stdout(self):
        if self.process is None:
            return
        data = bytes(self.process.readAllStandardOutput()).decode("utf-8", errors="replace")
        self.append_log(data)

    def on_process_stderr(self):
        if self.process is None:
            return
        data = bytes(self.process.readAllStandardError()).decode("utf-8", errors="replace")
        self.append_log(data)

    def on_process_error(self, error):
        self.append_log(f"[run] process error: {error}")

    def on_process_finished(self, exit_code, _exit_status):
        self.btn_run.setEnabled(True)
        self.btn_stop.setEnabled(False)

        workdir = self.workdir_edit.text().strip()
        output_dir = os.path.join(workdir, "fromATLAStoSolver")
        generated = []
        if os.path.isdir(output_dir):
            generated = [name for name in os.listdir(output_dir) if name.startswith("GPB-Phase")]
        self.refresh_output_browser()

        if exit_code == 0:
            missing = self.verify_output_artifacts()
            if missing:
                self.set_runner_status("warning", "Runner: completed with missing outputs")
                self.append_log(f"[run] completed with missing expected outputs ({len(missing)})")
                for row in missing:
                    self.append_log(f"[verify] {row}")
            else:
                self.set_runner_status("success", "Runner: completed")
                self.append_log(f"[run] completed successfully (files: {len(generated)})")
        else:
            self.set_runner_status("error", "Runner: failed")
            self.append_log(f"[run] failed with exit code {exit_code}")
        self.save_session_state()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    editor = INIEditor()
    editor.show()
    sys.exit(app.exec())
