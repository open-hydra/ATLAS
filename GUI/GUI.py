import sys
import configparser
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QPushButton, QTreeWidget,
    QTreeWidgetItem, QComboBox, QLineEdit, QMessageBox, QHBoxLayout,
    QSplitter, QGroupBox, QStyle
)
from PyQt6.QtCore import Qt, QSize

class INIEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.config = configparser.ConfigParser()
        self.phase_count = 0  # Track number of GPB-Phase sections
        self.type_options = ["ideal-gas", "heavy-gas", "solid"]
        self.thermo_options = ["NASA9", "NASA7"]
        self.transport_options = ["CEA", "cantera"]
        self.available_keys = {
            "type": self.type_options,
            "thermo": self.thermo_options,
            "transport": self.transport_options,
            "species": None  # Free text entry
        }
        
    def init_ui(self):
        self.setWindowTitle("INI File Editor")
        self.setGeometry(100, 100, 900, 600)
        
        # Dark theme style sheet
        self.setStyleSheet("""
            QWidget {
                background-color: #2b2b2b;
                font-family: Arial;
                font-size: 12pt;
                color: #dcdcdc;
            }
            QTreeWidget {
                background-color: #3c3f41;
                color: #dcdcdc;
                border: 1px solid #555;
            }
            QGroupBox {
                background-color: transparent;
                border: none;
                font-weight: bold;
                margin-top: 10px;
                color: #dcdcdc;
            }
            QPushButton {
                background-color: #5c5c5c;
                color: white;
                border: none;
                border-radius: 5px;
                padding: 10px;
                margin: 5px;
            }
            QPushButton:hover {
                background-color: #787878;
            }
            QLineEdit, QComboBox {
                border: 1px solid #555;
                border-radius: 5px;
                padding: 5px;
                background-color: #2b2b2b;
                color: #dcdcdc;
            }
            QComboBox QAbstractItemView {
                background-color: #2b2b2b;
                color: #dcdcdc;
            }
        """)
        
        main_layout = QHBoxLayout(self)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Left: Tree view for sections and keys
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["Section/Key", "Value"])
        splitter.addWidget(self.tree)
        
        # Right: Button panel in a group box
        button_widget = QGroupBox("Actions")
        button_layout = QVBoxLayout()
        
        btn_add_phase = QPushButton("Add GPB-Phase")
        btn_add_phase.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileIcon))
        btn_add_phase.setIconSize(QSize(24, 24))
        btn_add_phase.clicked.connect(self.add_phase)
        button_layout.addWidget(btn_add_phase)
        
        btn_add_key = QPushButton("Add Key to Selected Phase")
        btn_add_key.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogNewFolder))
        btn_add_key.setIconSize(QSize(24, 24))
        btn_add_key.clicked.connect(self.add_key)
        button_layout.addWidget(btn_add_key)
        
        btn_delete_section = QPushButton("Delete Selected Section")
        btn_delete_section.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        btn_delete_section.setIconSize(QSize(24, 24))
        btn_delete_section.clicked.connect(self.delete_section)
        button_layout.addWidget(btn_delete_section)
        
        btn_delete_key = QPushButton("Delete Selected Key")
        btn_delete_key.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        btn_delete_key.setIconSize(QSize(24, 24))
        btn_delete_key.clicked.connect(self.delete_key)
        button_layout.addWidget(btn_delete_key)
        
        btn_save = QPushButton("Save INI File")
        btn_save.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogApplyButton))
        btn_save.setIconSize(QSize(24, 24))
        btn_save.clicked.connect(self.save_ini)
        button_layout.addWidget(btn_save)
        
        button_layout.addStretch()  # Push buttons to the top
        button_widget.setLayout(button_layout)
        splitter.addWidget(button_widget)
        
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 1)
        main_layout.addWidget(splitter)
        self.setLayout(main_layout)
    
    def add_phase(self):
        self.phase_count += 1
        phase_name = f"GPB-Phase{self.phase_count}"
        phase_item = QTreeWidgetItem(self.tree, [phase_name])
        # Automatically add the default "type" key
        type_item = QTreeWidgetItem(phase_item, ["type"])
        combo_box = QComboBox()
        combo_box.addItems(self.type_options)
        self.tree.setItemWidget(type_item, 1, combo_box)
    
    def add_key(self):
        selected_item = self.tree.currentItem()
        if not selected_item or selected_item.parent() is not None:
            QMessageBox.warning(self, "Warning", "Please select a phase to add a key.")
            return
        
        key_selector = QComboBox()
        key_selector.addItems(self.available_keys.keys())
        key_item = QTreeWidgetItem(selected_item, [""])  # Empty text to avoid overlap
        self.tree.setItemWidget(key_item, 0, key_selector)
        # Connect to update value widget when key changes
        key_selector.currentIndexChanged.connect(lambda: self.update_value_widget(key_item, key_selector))
        self.update_value_widget(key_item, key_selector)
    
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
    
    def update_value_widget(self, key_item, key_selector):
        key = key_selector.currentText()
        if self.available_keys[key] is None:
            # For free text entry, use QLineEdit
            text_input = QLineEdit()
            self.tree.setItemWidget(key_item, 1, text_input)
        else:
            value_widget = QComboBox()
            value_widget.addItems(self.available_keys[key])
            self.tree.setItemWidget(key_item, 1, value_widget)
    
    def save_ini(self):
        self.config.clear()
        for i in range(self.tree.topLevelItemCount()):
            phase_item = self.tree.topLevelItem(i)
            section = phase_item.text(0)
            self.config[section] = {}
            for j in range(phase_item.childCount()):
                key_item = phase_item.child(j)
                key_widget = self.tree.itemWidget(key_item, 0)
                key = key_widget.currentText() if key_widget else key_item.text(0)
                value_widget = self.tree.itemWidget(key_item, 1)
                if isinstance(value_widget, QComboBox):
                    value = value_widget.currentText()
                elif isinstance(value_widget, QLineEdit):
                    value = value_widget.text()
                else:
                    value = ""
                self.config[section][key] = value
        
        with open("config.ini", "w") as file:
            self.config.write(file)
        
        QMessageBox.information(self, "Success", "INI file saved successfully!")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    editor = INIEditor()
    editor.show()
    sys.exit(app.exec())
