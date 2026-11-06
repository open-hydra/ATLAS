"""Launch the ATLAS GUI:  python -m atlasgui [mesh] [--ini input.ini | --case folder]"""

from __future__ import annotations

import argparse
import os
import sys


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="atlasgui",
        description="The ATLAS case in one window: the GPB phases, the BCB "
                    "boundary conditions and the ICB initial state of one "
                    "input.ini, and the runs of the tools on it.")
    parser.add_argument("mesh", nargs="?", help="mesh file to load on startup")
    parser.add_argument("--ini", help="existing ATLAS input.ini to open on startup")
    parser.add_argument("--case", metavar="FOLDER",
                        help="case folder to open on startup: its INI, its mesh and the "
                             "files the tools wrote there (a folder of files alone too)")
    args = parser.parse_args(argv)

    try:
        from PyQt6.QtWidgets import QApplication
    except ImportError as exc:  # pragma: no cover - environment guard
        sys.exit(
            "PyQt6 is required to run the ATLAS GUI.\n"
            f"  ({exc})\n"
            "Install the GUI dependencies, e.g.:\n"
            "  conda env update -f ct-env.yaml   (adds pyqt, pyvista, pyvistaqt)\n"
            "  or:  pip install PyQt6 pyvista pyvistaqt")

    try:
        import pyvista  # noqa: F401
        import pyvistaqt  # noqa: F401
    except ImportError as exc:  # pragma: no cover - environment guard
        sys.exit(
            "pyvista and pyvistaqt are required to run the ATLAS GUI.\n"
            f"  ({exc})\n"
            "Install with:  pip install pyvista pyvistaqt")

    from .mainwindow import AtlasMainWindow

    # A pip PyQt6 wheel bundles its own Qt, but inside a conda env the env's
    # bin/qt.conf sends every Qt to the conda prefix for its plugins, where the
    # wheel finds no platform plugin and aborts.  Search the wheel's own first.
    import PyQt6
    from PyQt6.QtCore import QCoreApplication
    wheel_plugins = os.path.join(os.path.dirname(PyQt6.__file__), "Qt6", "plugins")
    if os.path.isdir(wheel_plugins):
        QCoreApplication.addLibraryPath(wheel_plugins)

    app = QApplication(sys.argv)
    # Fusion is the most predictable base for the stylesheet: the native
    # platform styles ignore several of the rules the theme relies on.
    app.setStyle("Fusion")
    win = AtlasMainWindow()
    if args.ini:
        win.open_ini(args.ini)
    elif args.case:
        win.open_case(args.case)
    if args.mesh:
        win.load_mesh(args.mesh)
    win.set_stage("bcb" if args.mesh else "case")
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
