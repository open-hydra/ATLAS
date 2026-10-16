"""Launch the ATLAS GUI:  python -m atlasgui [mesh] [--ini input.ini]"""

from __future__ import annotations

import argparse
import sys


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="atlasgui",
        description="Interactive case setup for ATLAS: GPB phases and BCB "
                    "boundary conditions in one input.ini.")
    parser.add_argument("mesh", nargs="?", help="mesh file to load on startup")
    parser.add_argument("--ini", help="existing ATLAS input.ini to open on startup")
    parser.add_argument("--stage", choices=["case", "gpb", "bcb", "review"],
                        help="stage to open on (default: case, or boundaries "
                             "when a mesh is given)")
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

    app = QApplication(sys.argv)
    # Fusion is the most predictable base for the stylesheet: the native
    # platform styles ignore several of the rules the theme relies on.
    app.setStyle("Fusion")
    win = AtlasMainWindow()
    if args.ini:
        win.open_ini(args.ini)
    if args.mesh:
        win.load_mesh(args.mesh)
    win.set_stage(args.stage or ("bcb" if args.mesh else "case"))
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
