"""BCB block-face numbering and node extraction.

Face convention (fixed by BCB, see docs/user-guide/bcb/bc-setup.md):

    face1 -> i = 1        face2 -> i = imax
    face3 -> j = 1        face4 -> j = jmax
    face5 -> k = 1        face6 -> k = kmax

For 2-D / planar blocks (``k`` has a single cell) BCB automatically assigns
faces 5 and 6, so only faces 1-4 are user-assignable.
"""

from __future__ import annotations

import numpy as np

# face -> (axis, index-into-axis)
FACE_DEFS = {
    1: ("i", 0), 2: ("i", -1),
    3: ("j", 0), 4: ("j", -1),
    5: ("k", 0), 6: ("k", -1),
}

FACE_LABELS = {
    1: "i = 1", 2: "i = imax",
    3: "j = 1", 4: "j = jmax",
    5: "k = 1", 6: "k = kmax",
}

# Stable, colour-blind-friendly hue per face (matches the docs figure spirit).
FACE_COLORS = {
    1: "#e05c5c", 2: "#4a90d9",
    3: "#f5a623", 4: "#5cb87a",
    5: "#9b59b6", 6: "#1abc9c",
}

ALL_FACES = (1, 2, 3, 4, 5, 6)


def assignable_faces(block):
    """Return the faces a user may assign for *block* (1-4 for 2-D, 1-6 for 3-D)."""
    return (1, 2, 3, 4) if block.is_2d else ALL_FACES


def context_faces(block):
    """Faces drawn for context but not user-assignable (the k-planes of 2-D blocks)."""
    return (5, 6) if block.is_2d else ()


def extract_face(block, face):
    """Return ``(Xf, Yf, Zf)`` nodal coordinate arrays for *face* of *block*.

    Each returned array is 2-D; one dimension may be length-1 for a
    single-cell-thick (2-D) block, in which case the face degenerates to a line.
    """
    axis, idx = FACE_DEFS[face]
    if axis == "i":
        sl = (idx, slice(None), slice(None))   # -> (Nj, Nk)
    elif axis == "j":
        sl = (slice(None), idx, slice(None))    # -> (Ni, Nk)
    else:
        sl = (slice(None), slice(None), idx)    # -> (Ni, Nj)
    return block.xn[sl], block.yn[sl], block.zn[sl]


def face_is_degenerate(block, face):
    """True when the face collapses to a poly-line (a 2-D block's i/j faces)."""
    xf, _, _ = extract_face(block, face)
    return 1 in xf.shape


def face_centroid(block, face):
    xf, yf, zf = extract_face(block, face)
    return float(np.mean(xf)), float(np.mean(yf)), float(np.mean(zf))
