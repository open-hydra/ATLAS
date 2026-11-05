"""The screenshots of the ATLAS GUI in the documentation (gui-*.png, next to this file).

usage, with the Python of ct-env, from the ATLAS directory, on a case the tools have run on
(the Quick Start case, after `ATLAS GPB BCB ICB`):

    python -B docs/user-guide/images/gui-screenshots.py <case-folder>

The window is drawn offscreen at 1440 x 900, with the settings and themes of a temporary directory
(yours are not read or changed). The 3-D views do not draw under the offscreen platform: their actors
are rendered again by an offscreen PyVista plotter, with the same camera, and pasted into the image.
"""
import os
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
HERE = os.path.dirname(os.path.abspath(__file__))
ATLAS = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ATLAS, "GUI"))

import PyQt6  # noqa: E402
import pyvista as pv  # noqa: E402
from PyQt6.QtCore import QCoreApplication, QPoint, QSettings  # noqa: E402
from PyQt6.QtGui import QImage, QPainter  # noqa: E402
from PyQt6.QtWidgets import QApplication  # noqa: E402

from atlasgui import preferences  # noqa: E402

CONFIG = tempfile.mkdtemp(prefix="atlas-shots-")
preferences.settings = lambda: QSettings(os.path.join(CONFIG, "settings.ini"), QSettings.Format.IniFormat)
preferences.config_dir = lambda: CONFIG

from atlasgui import mainwindow  # noqa: E402


def main(case):
    wheel = os.path.join(os.path.dirname(PyQt6.__file__), "Qt6", "plugins")
    if os.path.isdir(wheel):
        QCoreApplication.addLibraryPath(wheel)
    app = QApplication(sys.argv[:1])
    app.setStyle("Fusion")
    win = mainwindow.AtlasMainWindow()
    win.resize(1440, 900)
    win.show()
    win.open_case(case, confirm=False)

    def settle():
        for _ in range(40):
            app.processEvents()

    def shoot(name, viewport=None):
        settle()
        pix = win.grab()
        if viewport is not None:
            paste_3d(win, pix, viewport.plotter)
        pix.save(os.path.join(HERE, name))
        print("wrote", os.path.join(HERE, name))

    win.set_stage("gpb")
    shoot("gui-phases.png")

    win.set_stage("bcb")
    settle()
    win.bcb_panel.viewport.view_isometric()
    win.bcb_panel.set_view_mode("written")
    shoot("gui-boundaries-written.png", win.bcb_panel.viewport)

    win.set_stage("icb")
    settle()
    win.icb_panel.block_list.setCurrentRow(1)      # Block 1, below All blocks
    win.icb_panel.set_view_mode("field")
    shoot("gui-initial-field.png", win.icb_panel.view)


def paste_3d(win, pix, plotter):
    """Render the actors of the plotter offscreen and paint them where its widget is."""
    widget = plotter.interactor
    width, height = widget.width(), widget.height()
    off = pv.Plotter(off_screen=True, window_size=(width, height))
    off.set_background(plotter.background_color)
    for actor in plotter.renderer.actors.values():
        off.add_actor(actor, reset_camera=False)
    off.camera_position = plotter.camera_position
    off.camera.view_angle = plotter.camera.view_angle
    img = off.screenshot(return_img=True)
    off.close()
    image = QImage(img.tobytes(), img.shape[1], img.shape[0], 3 * img.shape[1], QImage.Format.Format_RGB888)
    painter = QPainter(pix)
    painter.drawImage(widget.mapTo(win, QPoint(0, 0)), image)
    painter.end()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(os.path.abspath(sys.argv[1]))
