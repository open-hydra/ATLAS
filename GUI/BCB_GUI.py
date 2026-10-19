#!/usr/bin/env python3
"""Launcher kept for ``ATLAS BCB-GUI``: opens the ATLAS GUI on the boundaries stage.

The boundary-condition editor is now one stage of the case-setup GUI
(``ATLAS_GUI.py``), which also covers the GPB phases and the shared
``[ATLAS-Parameters]`` of the same input.ini.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from atlasgui.__main__ import main  # noqa: E402

if __name__ == "__main__":
    argv = sys.argv[1:]
    if "--stage" not in argv:
        argv += ["--stage", "bcb"]
    main(argv)
