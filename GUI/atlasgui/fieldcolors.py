"""The colour scales of a field: how much (sequential) and which side of zero
(diverging), as lookup tables of 256 colours.

The rules are the data-viz ones the GUI follows elsewhere: a magnitude takes
one hue, from light to dark -- the blue ramp of the reference palette, steps
100 to 700 -- and a signed quantity two hues of the same lightness step for
step, blue below zero and red above, about a neutral grey; never a rainbow.
On a dark background both flip: the end that means *little* (the low end, or
zero) is the one closest to the background, so it recedes.  The steps are
interpolated in OKLab, where equal steps look equal, and the red arm is the
blue one turned to the red hue at the same lightness.  No Qt here.
"""

from __future__ import annotations

import numpy as np

# the blue ramp of the reference palette, steps 100 .. 700 (light to dark)
BLUE = ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5",
        "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b"]
RED_HUE = "#e34948"                   # the red of the reference palette: its hue
MIDPOINT = {False: "#f0efec", True: "#383835"}     # neutral grey, light / dark
SIZE = 256


# ---------------------------------------------------------------- OKLab
def _linear(c):
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _gamma(c):
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.abs(c) ** (1 / 2.4) - 0.055)


def hex_rgb(colour):
    colour = colour.lstrip("#")
    return np.array([int(colour[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def to_oklab(rgb):
    """sRGB (0..1, rows) to OKLab."""
    r, g, b = _linear(np.atleast_2d(rgb)).T
    lms = np.cbrt(np.stack([0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
                            0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
                            0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b]))
    l_, m_, s_ = lms
    return np.stack([0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
                     1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
                     0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_]).T


def from_oklab(lab):
    """OKLab (rows) to sRGB (0..1), unclipped."""
    L, a, b = np.atleast_2d(lab).T
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = np.stack([4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
                    -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
                    -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_]).T
    return _gamma(rgb)


def lightness(colours):
    """OKLab lightness of rows of sRGB (0..255 or 0..1)."""
    rgb = np.asarray(colours, dtype=float)
    if rgb.max() > 1.0:
        rgb = rgb / 255.0
    return to_oklab(rgb)[:, 0]


def _in_gamut(lab):
    rgb = from_oklab(lab)
    return np.all((rgb >= -1e-6) & (rgb <= 1 + 1e-6), axis=1)


def _turn(colour, hue_of):
    """*colour* at the hue of *hue_of*, same lightness, as much of its chroma
    as sRGB holds."""
    L, a, b = to_oklab(hex_rgb(colour))[0]
    chroma = np.hypot(a, b)
    _, ha, hb = to_oklab(hex_rgb(hue_of))[0]
    angle = np.arctan2(hb, ha)
    while chroma > 0:
        lab = np.array([[L, chroma * np.cos(angle), chroma * np.sin(angle)]])
        if _in_gamut(lab)[0]:
            return lab[0]
        chroma *= 0.97
    return np.array([L, 0.0, 0.0])


def _ramp(stops, size):
    """*size* colours through the OKLab points *stops*, evenly spaced."""
    stops = np.asarray(stops)
    where = np.linspace(0, len(stops) - 1, size)
    lab = np.stack([np.interp(where, np.arange(len(stops)), stops[:, c]) for c in range(3)],
                   axis=1)
    return np.clip(np.rint(from_oklab(lab) * 255), 0, 255).astype(np.uint8)


def sequential(dark=False, size=SIZE):
    """Low to high: light to dark blue (dark to light on a dark background)."""
    stops = to_oklab(np.array([hex_rgb(c) for c in BLUE]))
    return _ramp(stops[::-1] if dark else stops, size)


def diverging(dark=False, size=SIZE):
    """Negative to positive: blue, the neutral grey at zero, red; the ends
    darker than the middle (lighter on a dark background)."""
    # each arm from next to the grey out to its end: steps 250 .. 700 on a
    # light background, 550 .. 100 on a dark one (the grey's own lightness is
    # left out, so zero stays apart from the smallest values)
    arm = BLUE[9::-1] if dark else BLUE[3:]
    blue = to_oklab(np.array([hex_rgb(c) for c in arm]))
    red = np.array([_turn(c, RED_HUE) for c in arm])
    middle = to_oklab(hex_rgb(MIDPOINT[dark]))
    return _ramp(np.vstack([blue[::-1], middle, red]), size)


def colours(values, low, high, table, diverging_scale=False, missing=(128, 128, 128)):
    """``(n, 3)`` uint8: *values* through *table* over ``[low, high]`` (about
    zero, symmetric, for a diverging scale); a value that is not a number
    takes *missing*."""
    values = np.asarray(values, dtype=float)
    if diverging_scale:
        reach = max(abs(low), abs(high)) or 1.0
        low, high = -reach, reach
    span = high - low
    if span > 0:
        t = (values - low) / span
    else:
        t = np.full(values.shape, 0.5)
    index = np.clip(np.rint(np.nan_to_num(t, nan=0.0) * (len(table) - 1)), 0,
                    len(table) - 1).astype(int)
    out = table[index]
    bad = ~np.isfinite(values)
    if bad.any():
        out = out.copy()
        out[bad] = missing
    return out


def is_signed(low, high):
    """A diverging scale: values on both sides of zero."""
    return low < 0 < high
