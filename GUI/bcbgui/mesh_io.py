"""Robust multiblock structured-grid reader for the BCB GUI.

Supports the mesh formats used across the ATLAS/BCB test suite:

* Tecplot ASCII (``.tec``/``.dat``), single- or multi-zone, ``BLOCK`` or
  ``POINT`` datapacking, reading only the first three variables (X, Y, Z).
* Plot3D formatted multiblock (``.p3d``/``.xyz``/``.g``), 2-D or 3-D,
  auto-detecting the block dimensionality.

Only nodal coordinates are needed by the GUI, so field variables are skipped.

The public entry point is :func:`read_mesh`, returning a list of
:class:`MeshBlock`.  Coordinate arrays are indexed ``a[i, j, k]`` with shape
``(Ni, Nj, Nk)`` -- the same convention used by ORION and by the BCB face
numbering (face1: ``i=1``, face2: ``i=imax``, ...).
"""

from __future__ import annotations

import re
from pathlib import Path

import numpy as np


class MeshBlock:
    """One structured block, holding nodal coordinates as ``(Ni, Nj, Nk)`` arrays."""

    def __init__(self, xn, yn, zn):
        self.xn = np.asarray(xn, dtype=float)
        self.yn = np.asarray(yn, dtype=float)
        self.zn = np.asarray(zn, dtype=float)
        if not (self.xn.shape == self.yn.shape == self.zn.shape):
            raise ValueError("x/y/z coordinate arrays must share the same shape")
        if self.xn.ndim != 3:
            raise ValueError("coordinate arrays must be 3-D (Ni, Nj, Nk)")
        self.ni, self.nj, self.nk = self.xn.shape

    @property
    def is_2d(self) -> bool:
        """True for planar / single-cell-thick blocks (k faces auto-assigned by BCB)."""
        return self.nk <= 2

    @property
    def dims(self):
        return (self.ni, self.nj, self.nk)

    def bounds(self):
        """Return ``(xmin, xmax, ymin, ymax, zmin, zmax)``."""
        return (
            float(self.xn.min()), float(self.xn.max()),
            float(self.yn.min()), float(self.yn.max()),
            float(self.zn.min()), float(self.zn.max()),
        )


# ---------------------------------------------------------------------------
# Format dispatch
# ---------------------------------------------------------------------------

def read_mesh(path):
    """Read *path* and return a list of :class:`MeshBlock`.

    Format is chosen from the file extension, falling back to content sniffing.
    """
    path = Path(path)
    suffix = path.suffix.lower()
    if suffix in (".p3d", ".xyz", ".g", ".grd"):
        return read_plot3d(path)
    if suffix in (".tec", ".dat", ".plt", ".tp"):
        return read_tecplot_ascii(path)

    # Unknown extension: sniff the first non-blank line.
    with open(path, "r", errors="replace") as fh:
        head = fh.read(2048)
    if re.search(r"VARIABLES|ZONE|TITLE", head, re.IGNORECASE):
        return read_tecplot_ascii(path)
    return read_plot3d(path)


# ---------------------------------------------------------------------------
# Tecplot ASCII
# ---------------------------------------------------------------------------

_ZONE_SPLIT = re.compile(r"^\s*ZONE\b", re.IGNORECASE | re.MULTILINE)
_NUM_TOKEN = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eEdD][-+]?\d+)?")


def _to_float(tok: str) -> float:
    # Fortran doubles sometimes use 'D' as the exponent marker.
    return float(tok.replace("D", "E").replace("d", "e"))


def _count_variables(header: str) -> int:
    """Count variables declared on a ``VARIABLES = "x", "y", ...`` header block."""
    m = re.search(r"VARIABLES\s*=", header, re.IGNORECASE)
    if not m:
        return 3
    # Gather text until the first ZONE keyword.
    rest = header[m.end():]
    zone = re.search(r"\bZONE\b", rest, re.IGNORECASE)
    if zone:
        rest = rest[:zone.start()]
    names = re.findall(r'"[^"]*"', rest)
    if names:
        return len(names)
    # Fall back to comma-separated bare names.
    return max(1, len([t for t in rest.split(",") if t.strip()]))


def read_tecplot_ascii(path):
    with open(path, "r", errors="replace") as fh:
        text = fh.read()

    parts = _ZONE_SPLIT.split(text)
    if len(parts) < 2:
        raise ValueError(f"No ZONE found in Tecplot file: {path}")

    header = parts[0]
    nvar = _count_variables(header)

    blocks = []
    for chunk in parts[1:]:
        block = _parse_tec_zone(chunk, nvar)
        if block is not None:
            blocks.append(block)
    if not blocks:
        raise ValueError(f"Could not parse any zone from Tecplot file: {path}")
    return blocks


def _parse_tec_zone(chunk: str, nvar: int):
    """Parse a single zone body (text after the ``ZONE`` keyword)."""
    dims = _parse_ijk(chunk)
    if dims is None:
        return None
    ni, nj, nk = dims
    npts = ni * nj * nk

    packing = "POINT"
    if re.search(r"DATAPACKING\s*=\s*BLOCK", chunk, re.IGNORECASE) or \
       re.search(r"\bF\s*=\s*BLOCK", chunk, re.IGNORECASE):
        packing = "BLOCK"

    # Data begins at the first numeric token that is not part of the header
    # key=value pairs.  Drop header lines (those containing '=' or letters
    # like ZONETYPE/DATAPACKING) then read numbers.
    lines = chunk.splitlines()
    data_start = 0
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        # Header lines contain '=' or known keywords; data lines are numbers.
        if "=" in stripped or re.search(r"[A-Za-z]{2,}", re.sub(r"[eEdD][-+]?\d", "", stripped)):
            continue
        data_start = idx
        break

    body = "\n".join(lines[data_start:])
    tokens = _NUM_TOKEN.findall(body)
    need = npts * nvar
    if len(tokens) < need:
        raise ValueError(
            f"Zone declares I={ni} J={nj} K={nk} ({need} values for {nvar} vars) "
            f"but only {len(tokens)} numbers were found"
        )
    vals = np.array([_to_float(t) for t in tokens[:need]], dtype=float)

    if packing == "BLOCK":
        # var0 (all pts), var1 (all pts), ...  -- i fastest within each var.
        var = vals.reshape(nvar, npts)
    else:
        # interleaved per point: v0 v1 v2 ... -- i fastest across points.
        var = vals.reshape(npts, nvar).T

    def as_ijk(flat):
        # flat index p = i + ni*(j + nj*k)  ->  reshape (nk, nj, ni), transpose.
        return flat.reshape(nk, nj, ni).transpose(2, 1, 0)

    xn = as_ijk(var[0])
    yn = as_ijk(var[1]) if nvar > 1 else np.zeros((ni, nj, nk))
    zn = as_ijk(var[2]) if nvar > 2 else np.zeros((ni, nj, nk))
    return MeshBlock(xn, yn, zn)


def _parse_ijk(chunk: str):
    def grab(letter):
        m = re.search(rf"\b{letter}\s*=\s*(\d+)", chunk, re.IGNORECASE)
        return int(m.group(1)) if m else None

    ni = grab("I")
    nj = grab("J")
    nk = grab("K")
    if ni is None:
        return None
    nj = nj or 1
    nk = nk or 1
    return ni, nj, nk


# ---------------------------------------------------------------------------
# Plot3D formatted multiblock
# ---------------------------------------------------------------------------

def read_plot3d(path):
    with open(path, "r", errors="replace") as fh:
        tokens = fh.read().split()
    if not tokens:
        raise ValueError(f"Empty Plot3D file: {path}")

    it = iter(tokens)
    nblocks = int(next(it))
    remaining = tokens[1:]

    # Try 3-D layout first, then 2-D, choosing whichever consumes the file
    # exactly.  (Formatted Plot3D does not record ndim explicitly.)
    for ndim in (3, 2):
        blocks = _try_plot3d(remaining, nblocks, ndim)
        if blocks is not None:
            return blocks
    raise ValueError(
        f"Could not interpret Plot3D file {path} as 2-D or 3-D multiblock"
    )


def _try_plot3d(tokens, nblocks, ndim):
    if len(tokens) < ndim * nblocks:
        return None
    dims = []
    pos = 0
    try:
        for _ in range(nblocks):
            d = [int(tokens[pos + a]) for a in range(ndim)]
            pos += ndim
            dims.append(d)
    except ValueError:
        # A coordinate float was read where a dimension was expected: this
        # dimensionality guess is wrong.
        return None

    total = 0
    for d in dims:
        npts = 1
        for v in d:
            npts *= v
        total += ndim * npts
    if len(tokens) - pos != total:
        return None  # dimensionality guess did not consume the file exactly

    vals = np.array([_to_float(t) for t in tokens[pos:]], dtype=float)

    blocks = []
    cur = 0
    for d in dims:
        if ndim == 3:
            ni, nj, nk = d
        else:
            ni, nj = d
            nk = 1
        npts = ni * nj * nk

        def as_ijk(flat):
            return flat.reshape(nk, nj, ni).transpose(2, 1, 0)

        xn = as_ijk(vals[cur:cur + npts]); cur += npts
        yn = as_ijk(vals[cur:cur + npts]); cur += npts
        if ndim == 3:
            zn = as_ijk(vals[cur:cur + npts]); cur += npts
        else:
            zn = np.zeros((ni, nj, nk))
        blocks.append(MeshBlock(xn, yn, zn))
    return blocks
