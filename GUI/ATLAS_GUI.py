#!/usr/bin/env python3
"""Launcher for the ATLAS case-setup GUI.

Usage:
    python ATLAS_GUI.py [mesh] [--ini input.ini] [--stage case|gpb|bcb|review]

This simply forwards to the ``atlasgui`` package next to this file.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from atlasgui.__main__ import main  # noqa: E402

if __name__ == "__main__":
    main()
