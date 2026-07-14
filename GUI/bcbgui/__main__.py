"""Launch the BCB GUI:  python -m bcbgui [mesh] [--ini input.ini]"""

from __future__ import annotations

import argparse
import sys


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="bcbgui",
        description="Interactive boundary-condition setup for BCB multiblock meshes.")
    parser.add_argument("mesh", nargs="?", help="mesh file to load on startup")
    parser.add_argument("--ini", help="existing BCB input.ini to open on startup")
    args = parser.parse_args(argv)

    try:
        from PyQt6.QtWidgets import QApplication
    except ImportError as exc:  # pragma: no cover - environment guard
        sys.exit(
            "PyQt6 is required to run the BCB GUI.\n"
            f"  ({exc})\n"
            "Install the GUI dependencies, e.g.:\n"
            "  conda env update -f ct-env.yaml   (adds pyqt, pyvista, pyvistaqt)\n"
            "  or:  pip install PyQt6 pyvista pyvistaqt")

    try:
        import pyvista  # noqa: F401
        import pyvistaqt  # noqa: F401
    except ImportError as exc:  # pragma: no cover - environment guard
        sys.exit(
            "pyvista and pyvistaqt are required to run the BCB GUI.\n"
            f"  ({exc})\n"
            "Install with:  pip install pyvista pyvistaqt")

    from .mainwindow import BCBMainWindow

    app = QApplication(sys.argv)
    win = BCBMainWindow()
    if args.mesh:
        win.load_mesh(args.mesh)
    if args.ini:
        win.open_ini(args.ini)
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
