"""Tests that the GUI's pages fit the windows a laptop gives them, and of the
counters in its status bar.

usage: python3 -B GUI/tests/test_layout.py [-v]

The window is opened on simulated screens (1280 x 720, 1440 x 900, as the
operating system leaves room for the menu bar and the Dock) at three text
sizes, both as the GUI fits it to the screen and at the smallest size it
allows; on a case with a finite-rate mechanism of sixty reactions, a real
fluid, a mesh, a boundary file and an initial state.  Each stage, the
header and the status bar (with a long run message and a long count of
issues showing) are then searched for what a window that is too small does
to a layout: a widget smaller than the least it asks for, a label or a button
narrower than its text, two widgets one over the other -- text printed over
text.  A page that cannot fit scrolls; nothing may be squeezed.

The Initial counter of the status bar is the blocks ICB can write: those with
a state, their own or ``[ICB-Block*]``'s, and no error in it.

Needs PyQt6 and pyvistaqt (offscreen); exit status 77 (skipped) without them.
"""

import os
import shutil
import sys
import tempfile
import textwrap
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    import numpy as np
    import PyQt6
    import pyvistaqt  # noqa: F401
    from PyQt6.QtCore import QCoreApplication, QRect, QSettings, Qt
    from PyQt6.QtGui import QScreen
    from PyQt6.QtWidgets import (QAbstractButton, QApplication, QComboBox, QFrame, QLabel,
                                 QLineEdit, QMessageBox, QProgressBar, QTabBar, QToolButton,
                                 QWidget)
except ImportError as exc:              # the GUI needs these; its tests say so
    print(f"{exc}: GUI-layout skipped")
    sys.exit(77)

from atlasgui import preferences, runner  # noqa: E402
from atlasgui.document import AtlasDocument  # noqa: E402

ATLAS = runner.ATLAS_ROOT
IG_BASIC = os.path.join(ATLAS, "test", "BCB", "IG-basic")
LEAF = (QLabel, QAbstractButton, QComboBox, QLineEdit, QProgressBar)
SCREENS = ((1280, 720), (1440, 900))
TEXT_SIZES = (0.9, 1.0, 1.25)
REACTIONS = 60


def _where(widget, page):
    names = []
    while widget is not None and widget is not page:
        names.append(widget.objectName() or type(widget).__name__)
        widget = widget.parentWidget()
    return "/".join(reversed(names[:4]))


def squeezed(page):
    """What *page* shows of a layout that has less room than it asks for:
    ``[(what, widget kind, text, detail, where)]``."""
    found = []
    for w in page.findChildren(QWidget):
        if not w.isVisibleTo(page) or w.width() < 2 or w.height() < 2:
            continue
        kind = type(w).__name__
        if isinstance(w, QLabel) and kind == "ElidedLabel":
            # it shortens its text on purpose, but never below the least it asks for
            if w.width() + 1 < w.minimumSizeHint().width():
                found.append(("narrow", kind, w.text()[:40],
                              f"{w.width()} < {w.minimumSizeHint().width()}", _where(w, page)))
        elif isinstance(w, QLabel) and w.wordWrap():
            if w.height() + 1 < w.heightForWidth(w.width()):
                found.append(("short", kind, w.text()[:40],
                              f"{w.height()} < {w.heightForWidth(w.width())}", _where(w, page)))
        elif isinstance(w, QLabel):
            pixmap = w.pixmap()
            if (pixmap is None or pixmap.isNull()) and w.text() \
                    and w.width() + 1 < w.sizeHint().width():
                found.append(("narrow", kind, w.text()[:40],
                              f"{w.width()} < {w.sizeHint().width()}", _where(w, page)))
        elif isinstance(w, QAbstractButton) and not isinstance(w, QToolButton):
            if w.text().strip() and w.width() + 1 < w.sizeHint().width():
                found.append(("narrow", kind, w.text()[:40],
                              f"{w.width()} < {w.sizeHint().width()}", _where(w, page)))
        elif w.layout() is not None and not isinstance(w, LEAF):
            least = w.minimumSizeHint()
            if w.width() + 1 < least.width() or w.height() + 1 < least.height():
                found.append(("squeezed", kind, w.objectName(),
                              f"{w.width()}x{w.height()} < {least.width()}x{least.height()}",
                              _where(w, page)))
    for parent in [page] + page.findChildren(QWidget):
        if not parent.isVisibleTo(page) or isinstance(parent, QTabBar):
            continue
        kids = [c for c in parent.children()
                if isinstance(c, QWidget) and not c.isWindow() and c.isVisibleTo(page)
                and c.width() > 3 and c.height() > 3
                and isinstance(c, LEAF + (QFrame,)) and not isinstance(c, QToolButton)]
        for i, a in enumerate(kids):
            for b in kids[i + 1:]:
                inter = a.geometry().intersected(b.geometry())
                if inter.width() > 3 and inter.height() > 3:
                    found.append(("overlap", f"{type(a).__name__}+{type(b).__name__}",
                                  f"{getattr(a, 'text', lambda: '')()!s:.20}/"
                                  f"{getattr(b, 'text', lambda: '')()!s:.20}",
                                  f"{inter.width()}x{inter.height()}", _where(parent, page)))
    return found


class Layout(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.mkdtemp(prefix="atlas-layout-")
        wheel = os.path.join(os.path.dirname(PyQt6.__file__), "Qt6", "plugins")
        if os.path.isdir(wheel):
            QCoreApplication.addLibraryPath(wheel)
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setStyle("Fusion")
        cls.store = os.path.join(cls.root, "settings.ini")
        preferences.settings = lambda: QSettings(cls.store, QSettings.Format.IniFormat)
        preferences.config_dir = lambda: os.path.join(cls.root, "config")
        cls.question = QMessageBox.question
        QMessageBox.question = staticmethod(lambda *a, **k: QMessageBox.StandardButton.Yes)
        cls.screen = QScreen.availableGeometry
        cls.case = os.path.join(cls.root, "case")
        make_case(cls.case)

    @classmethod
    def tearDownClass(cls):
        QMessageBox.question = cls.question
        QScreen.availableGeometry = cls.screen
        shutil.rmtree(cls.root, ignore_errors=True)

    def settle(self, n=5):
        for _ in range(n):
            self.app.processEvents()

    def screen_of(self, width, height):
        # the menu bar above, the Dock below
        area = QRect(0, 25, width, int(height * 0.95) - 25)
        QScreen.availableGeometry = lambda self, a=area: a

    def window(self, scale):
        from atlasgui.mainwindow import AtlasMainWindow
        win = AtlasMainWindow()
        win.show()
        self.settle()
        win.open_case(self.case)
        win.set_text_size(scale)
        self.settle()
        win._fit_to_screen()
        self.settle()
        return win

    # -- the pages ---------------------------------------------------------
    def test_pages_fit_laptop_screens(self):
        problems = []
        for width, height in SCREENS:
            self.screen_of(width, height)
            for scale in TEXT_SIZES:
                win = self.window(scale)
                self.assertEqual(win._text_size, scale)
                views = [("case", lambda: None)]
                tables = lambda: win.gpb_panel.tables_view
                for sheet in ("thermo", "arrhenius"):
                    views.append((f"gpb:{sheet}", lambda s=sheet: tables().select(
                        tables().phase.currentData(), s)))
                views.append(("gpb:grid", lambda: win.gpb_panel.show_tables("co2", "grid")))
                views += [("bcb", lambda: win.bcb_panel.set_view_mode("assigned")),
                          ("bcb:written", lambda: win.bcb_panel.set_view_mode("written")),
                          ("icb", lambda: win.icb_panel.set_view_mode("states")),
                          ("icb:field", lambda: win.icb_panel.set_view_mode("field")),
                          ("review", lambda: None), ("run", lambda: None)]
                for mode in ("fitted", "smallest"):
                    if mode == "smallest":
                        win.resize(10, 10)
                        self.settle()
                    for name, setup in views:
                        win.set_stage(name.split(":")[0])
                        setup()
                        self.settle()
                        # a long run message and a long count: the worst the strip shows
                        win.run_state.setText("● BCB failed · 123.4 s")
                        for widget in (win.run_dot, win.run_state, win.run_divider):
                            widget.setVisible(True)
                        win.issues_label.setText("12 error(s), 34 warning(s)")
                        self.settle(3)
                        found = squeezed(win.stack.currentWidget())
                        for chrome in ("HeaderBar", "StatusStrip"):
                            frame = win.findChild(QFrame, chrome)
                            found += squeezed(frame)
                            if frame.width() + 1 < frame.minimumSizeHint().width():
                                found.append(("squeezed", "QFrame", chrome,
                                              f"{frame.width()} < {frame.minimumSizeHint().width()}",
                                              chrome))
                        where = (f"{width}x{height} screen, text {round(scale * 100)} %, "
                                 f"{mode} window {win.width()}x{win.height()}, {name}")
                        problems += [f"{where}: {' | '.join(map(str, p))}" for p in found]
                win._dirty = False
                win.close()
                self.settle()
        self.assertEqual(problems[:12], [], f"{len(problems)} problem(s)")

    def test_minimum_size_follows_the_text(self):
        self.screen_of(1920, 1200)             # room for the larger window
        small, large = self.window(1.0), self.window(1.25)
        try:
            self.assertGreater(large.minimumWidth(), small.minimumWidth())
            self.assertGreater(large.minimumHeight(), small.minimumHeight())
        finally:
            for win in (small, large):
                win._dirty = False
                win.close()
        self.screen_of(1280, 720)              # a small screen caps it
        win = self.window(1.25)
        try:
            self.assertLessEqual(win.minimumWidth(), 1280)
            self.assertLessEqual(win.minimumHeight(), 720)
        finally:
            win._dirty = False
            win.close()

    # -- the status bar ----------------------------------------------------
    def test_initial_counter(self):
        self.screen_of(1440, 900)
        win = self.window(1.0)
        try:
            blocks = len(win.bcb_panel.blocks)
            self.assertEqual(blocks, 3)

            def counted(text):
                win.doc = AtlasDocument.from_ini(textwrap.dedent(text))
                win.bcb_panel.sync_blocks_to_mesh()
                win.refresh_all()
                self.settle()
                return win.initial_label.text(), win._initial_coverage(win._issues())

            state = "p = 1e5\nT = 300\nyN2 = 1\n"          # a state ICB can write
            no_gas = "p = 2e5\nT = 400\n"                   # the phase file lists species: it needs y
            # no initial state at all
            self.assertEqual(counted("[ATLAS-Parameters]\nIC-format = tec\n")[1], (0, 3))
            # one state for every block
            label, got = counted(f"[ICB-Block*]\n{state}")
            self.assertEqual((label, got), ("3 / 3 blocks", (3, 3)))
            self.assertEqual(win.initial_progress.value(), 3)
            self.assertEqual(win.initial_progress.property("state"), "done")
            # a block of its own, and the others take the default
            self.assertEqual(counted(f"[ICB-Block*]\n{state}\n[ICB-Block2]\n{state}")[1], (3, 3))
            # only some blocks have a section: the others stop ICB
            self.assertEqual(counted(f"[ICB-Block1]\n{state}")[1], (1, 3))
            self.assertEqual(win.initial_progress.property("state"), "open")
            # an error in a block's own state: it is not counted, the others are
            self.assertEqual(counted(f"[ICB-Block*]\n{state}\n[ICB-Block2]\n{no_gas}")[1], (2, 3))
            # an error in the state they share: none of the blocks that take it ...
            self.assertEqual(counted(f"[ICB-Block*]\n{no_gas}")[1], (0, 3))
            # ... but the one with a state of its own
            self.assertEqual(counted(f"[ICB-Block*]\n{no_gas}\n[ICB-Block1]\n{state}")[1], (1, 3))
            self.assertIn("1 of 3 blocks", win.initial_label.toolTip())
        finally:
            win._dirty = False
            win.close()

    def test_no_mesh_no_blocks(self):
        self.screen_of(1440, 900)
        from atlasgui.mainwindow import AtlasMainWindow
        win = AtlasMainWindow()
        win.show()
        self.settle()
        try:
            self.assertEqual(win.initial_label.text(), "0 / 0 blocks")
            self.assertEqual(win._initial_coverage(win._issues()), (0, 0))
        finally:
            win._dirty = False
            win.close()

    def test_elided_label(self):
        from atlasgui.widgets import ElidedLabel
        label = ElidedLabel("a-long-case-name-that-does-not-fit.ini", Qt.TextElideMode.ElideMiddle,
                            keep=12)
        label.show()
        self.settle()
        label.resize(label.sizeHint())
        self.settle()
        self.assertEqual(label.text(), "a-long-case-name-that-does-not-fit.ini")
        self.assertEqual(QLabel.text(label), label.text())            # room: shown whole
        label.resize(90, label.height())
        self.settle()
        shown = QLabel.text(label)
        self.assertIn("…", shown)
        self.assertTrue(shown.startswith("a-") and shown.endswith(".ini"), shown)   # the middle goes
        self.assertEqual(label.toolTip(), label.text())               # the whole name, on hover
        self.assertLess(label.minimumSizeHint().width(), label.sizeHint().width())
        short = ElidedLabel("input.ini", keep=12)
        self.assertEqual(short.minimumSizeHint().width(), short.sizeHint().width())  # never shortened
        label.close()


def make_case(case):
    """A case whose tables, boundary file and deck fill every stage: a gas with
    a mechanism of REACTIONS reactions, a real fluid, the mesh and the
    boundary conditions of IG-basic and its boundary file, one initial state."""
    out = os.path.join(case, "fromATLAStoSolver")
    os.makedirs(out)
    shutil.copy(os.path.join(IG_BASIC, "mesh.tec"), case)
    with open(os.path.join(IG_BASIC, "input.ini")) as handle:
        bcb = handle.read()
    with open(os.path.join(case, "input.ini"), "w") as handle:
        handle.write(textwrap.dedent("""\
            [GPB-Phase1]
            name = gas
            reactions = JLR-nasuti
            thermo = NASA9
            transport = cantera

            [GPB-Phase2]
            type = real-fluid
            name = co2
            fluid = CO2
            pmin = 8e6
            pmax = 1.5e7
            Tmin = 320
            Tmax = 450
            NP = 6
            NH = 5

            [ATLAS-Parameters]
            IC-format = tec

            [ICB-Block*]
            p = 1e5
            T = 300
            u = 20
            yO2 = 0.23
            yN2 = 0.77

            """) + bcb)
    species = ["O2", "CH4", "H2O", "CO", "CO2", "H2", "H", "O", "OH", "N2"]
    with open(os.path.join(out, "gas-phase.txt"), "w") as handle:
        handle.write("ideal-gas phase\n" + "".join(f"{s} 28.0\n" for s in species))
    T = np.arange(1, 301)

    def one_d(name, title, variables, columns, zones):
        with open(os.path.join(out, name), "w") as handle:
            handle.write(f'TITLE = "{title}"\nVARIABLES = '
                         + ", ".join(f'"{v}"' for v in variables) + "\n")
            for zone in zones:
                handle.write(f'ZONE T="{zone}"\nI={len(T)}, F=POINT\n')
                for i, t in enumerate(T):
                    handle.write(f"{t} " + " ".join(f"{c(i, t):.6f}" for c in columns) + "\n")
    one_d("gas-thermo.dat", "Mass Thermodynamic Properties",
          ["Temperature", "Cp", "Enthalpy", "Entropy", "dCp"],
          [lambda i, t: 900 + t, lambda i, t: 1e3 * t, lambda i, t: 7 * t, lambda i, t: 0.0],
          species)
    one_d("gas-transport.dat", "Transport Properties", ["Temperature", "Viscosity", "Conductivity"],
          [lambda i, t: 1e-5 + 1e-8 * t, lambda i, t: 0.01 + 1e-4 * t], species)
    one_d("gas-chemistry-Arrhenius.dat", "Arrhenius data", ["Temperature", "kf", "kb"],
          [lambda i, t: 1e3 * t ** 2, lambda i, t: 1e-3 * t ** 2],
          [f"Reaction {n}" for n in range(1, REACTIONS + 1)])
    with open(os.path.join(out, "gas-chemistry-info.txt"), "w") as handle:
        handle.write(f"mechanism\nN.ro species = {len(species)}\nN.ro reactions = {REACTIONS}\n\n"
                     "Reaction type\n")
        handle.write("".join(f"{n} Arrhenius\n" for n in range(1, REACTIONS + 1)))
        handle.write("\nReaction definition\n")
        for n in range(1, REACTIONS + 1):
            a, b = species[n % 9], species[(n + 3) % 9]
            handle.write(f"{n} {a} 1.0 0.0 0.0\n{n} {b} 0.0 1.0 0.0\n")
    with open(os.path.join(out, "co2-phase.txt"), "w") as handle:
        handle.write("real-fluid phase\nCO2\n")
    p = np.linspace(8e6, 1.5e7, 6)
    h = np.linspace(0, 1.5e5, 5)
    P, H = np.meshgrid(p, h)
    for name, variables, values in (
            ("co2-thermo.dat", ("Pressure", "Enthalpy", "Density", "Temperature"),
             (P, H, 300 + P / 1e5 - H / 1e3, 320 + H / 1e3)),
            ("co2-transport.dat", ("Pressure", "Enthalpy", "Viscosity", "Conductivity"),
             (P, H, 2e-5 + 0 * P, 0.03 + 0 * P))):
        with open(os.path.join(out, name), "w") as handle:
            handle.write('TITLE = "x"\nVARIABLES = ' + ", ".join(f'"{v}"' for v in variables)
                         + f"\nZONE T=real-gas, I={len(p)}, J={len(h)}, K=1, DATAPACKING=BLOCK\n")
            for v in values:
                handle.write("".join(f"{x}\n" for x in v.ravel()))
    shutil.copy(os.path.join(IG_BASIC, "reference", "bc.txt"), out)


if __name__ == "__main__":
    unittest.main()
