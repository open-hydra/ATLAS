#!/usr/bin/env python3
"""Standalone launcher for the BCB boundary-condition setup GUI.

Usage:
    python BCB_GUI.py [mesh] [--ini input.ini]

This simply forwards to the ``bcbgui`` package next to this file.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bcbgui.__main__ import main  # noqa: E402

if __name__ == "__main__":
    main()
