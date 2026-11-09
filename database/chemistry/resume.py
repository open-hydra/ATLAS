#!/usr/bin/env python3
"""The figure of the mechanism catalog: the size of every mechanism of the database (species against reactions).

    python3 database/chemistry/resume.py            writes docs/databases/chemistry/mechs.svg
    python3 database/chemistry/resume.py --check    exits 1 when that file is not what the database gives now
    python3 database/chemistry/resume.py --out F    writes F instead

Needs Cantera only (the Python of ATLAS.sh); no plotting package. The figure is a pure function of the database, so a
rerun gives the same bytes, and `--check` (the ctest `database-figure-current`) tells when a mechanism was added or
changed and the figure was not regenerated.

The points are the files of database/chemistry (not the Cantera forms for KAnT, `*-ct.yaml`, and not the files of
`external/`, which a clone does not have) and the mechanisms that Cantera ships and the database lists (SHIPPED).
A new file must be given a family in FAMILY below: the figure refuses a mechanism it does not know, so that it and the
catalog (docs/databases/chemistry/list.md) are kept together.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DEFAULT_OUT = os.path.join(ROOT, "docs", "databases", "chemistry", "mechs.svg")

SHIPPED = ["gri30.yaml"]          # listed in the catalog, but a file of the Cantera that ATLAS employs

# Three families, the sections of the catalog grouped by the propellant system. Three is the most that a categorical
# colour carries on a scatter plot (every pair of marks can sit side by side); the shape is the second channel.
FAMILIES = [
    # key, legend, shape, light, dark
    ("h2", "H₂/O₂", "circle", "#2a78d6", "#3987e5"),
    ("carbon", "Carbon fuels", "square", "#eb6834", "#d95926"),
    ("srm", "SRM plume", "triangle", "#1baf7a", "#199e70"),
]
FAMILY = {}
for stem in ("Mevel2017 Jachimowski-7 ONERA-7 ONERA-7_rev Gerlinger-9 Nassini_Original Nassini_Montanari_Grossi "
             "Frolov Frolov_nopressure").split():
    FAMILY[stem] = "h2"
for stem in ("pelucchi cross ecker troyes").split():
    FAMILY[stem] = "srm"
for stem in ("ZhukovC1C4 FFCM1 FFCM2 FFCMy_12 dtu ZK coria smooke JL JLR-frassoldati JLR-nasuti WD WD-andersen "
             "aramco20 aramco30 USCII UCSD gri30 Zettervall CKJLR-10sp ciottoli20 CoronettiC4H6 Singh-WC32").split():
    FAMILY[stem] = "carbon"

# Geometry of the figure, in SVG user units. The page shows it at the width of its column, about 700 px, so W is about
# that: one unit is then about one pixel and FONT is the size of the text on the page. A wider canvas would be shrunk
# and its text with it; the room for the labels comes from H instead.
W, H = 720, 760
LEFT, RIGHT, TOP, BOTTOM = 90, 20, 62, 80
X_RANGE = (2.5, 900.0)             # species
Y_RANGE = (0.5, 4000.0)            # reactions
R = 6.0                            # marker size: half of the 12 units of the circle, the square and the triangle
FONT = 14.0                        # labels of the points and of the legend
TICK = round(FONT * 1.1, 1)        # numbers of the axes
AXIS = round(FONT * 1.3, 1)        # titles of the axes
CHAR = FONT * 0.54                 # width of a character of a label, for the placement (estimate of the font)


def mechanisms():
    """[(stem, phase name, species, reactions)] for every mechanism of the figure, sorted by stem."""
    import glob
    import warnings
    import cantera as ct
    ct.suppress_thermo_warnings()      # the polynomials of some files are discontinuous at their mid temperature
    warnings.simplefilter("ignore")
    paths = [p for p in sorted(glob.glob(os.path.join(HERE, "*.yaml"))) if not p.endswith("-ct.yaml")]
    items = [(os.path.splitext(os.path.basename(p))[0], p) for p in paths]
    items += [(os.path.splitext(f)[0], f) for f in SHIPPED]
    unknown = [stem for stem, _ in items if stem not in FAMILY]
    if unknown:
        sys.exit(f"[ERROR] resume.py: no family for {', '.join(unknown)}: add it to FAMILY (and to the catalog)")
    out = []
    for stem, path in items:
        try:
            gas = ct.Solution(path)
        except Exception as e:      # a mechanism that does not load must not vanish from the figure
            sys.exit(f"[ERROR] resume.py: {path} does not load: {e}")
        out.append((stem, gas.name, gas.n_species, gas.n_reactions))
    return out


def unique(items):
    """One point per (species, reactions): mechanisms of the same size share a marker and a label (two files of one
    phase, Nassini; Frolov and Frolov_nopressure). A point carries the `names` of its mechanisms."""
    points, index = [], {}
    for stem, name, ns, nr in items:
        key = (ns, nr)
        if key not in index:
            index[key] = {"names": [], "ns": ns, "nr": nr, "family": FAMILY[stem]}
            points.append(index[key])
        if name not in index[key]["names"]:
            index[key]["names"].append(name)
    for p in points:
        p["name"] = " / ".join(p["names"])
    return points


# ---------------------------------------------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------------------------------------------
def px(ns):
    a, b = math.log10(X_RANGE[0]), math.log10(X_RANGE[1])
    return LEFT + (math.log10(ns) - a) / (b - a) * (W - LEFT - RIGHT)


def py(nr):
    a, b = math.log10(Y_RANGE[0]), math.log10(Y_RANGE[1])
    return H - BOTTOM - (math.log10(nr) - a) / (b - a) * (H - TOP - BOTTOM)


def overlap(a, b):
    """Area shared by two boxes (x0, y0, x1, y1)."""
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w * h if w > 0 and h > 0 else 0.0


def place_labels(points):
    """Give every point a label box (x0, y0, x1, y1) with no overlap if one exists: the labels are tried around the
    marker, near to far, in a fixed order; the densest points choose first; then every label is chosen again with the
    others in place. Deterministic."""
    marks = [(p["x"] - R - 1, p["y"] - R - 1, p["x"] + R + 1, p["y"] + R + 1) for p in points]
    plot = (LEFT, TOP, W - RIGHT, H - BOTTOM)
    h = FONT + 3
    dirs = [(math.cos(a * math.pi / 8), math.sin(a * math.pi / 8)) for a in range(16)]
    # horizontal first (right, left), then the diagonals, then above and below
    order = [0, 8, 1, 15, 7, 9, 2, 14, 6, 10, 3, 13, 5, 11, 4, 12]

    def box(p, r, d):
        """The label box at distance r from the marker, in direction d (straight above or below: centred)."""
        w = len(p["name"]) * CHAR + 4
        ux, uy = dirs[d]
        cx = p["x"] if abs(ux) <= 0.3 else p["x"] + ux * r + math.copysign(w / 2, ux)
        cy = p["y"] + uy * r + (math.copysign(h / 2, uy) if abs(uy) > 0.3 else 0.0)
        return (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)

    def adjacent(r, d):
        """A label level with its marker, right or left, touching it: the one place that needs no leader."""
        return r <= R + 3 and d in (0, 8)

    def leader(i, b, r, d):
        """The segment from the marker to the label box, None when the label is adjacent."""
        if adjacent(r, d):
            return None
        p = points[i]
        ex = b[0] if p["x"] < b[0] else b[2] if p["x"] > b[2] else p["x"]
        ey = b[1] if p["y"] < b[1] else b[3] if p["y"] > b[3] else p["y"]
        return (p["x"], p["y"], ex, ey)

    def crosses(seg, b):
        """True when the segment passes through the box b (sampled)."""
        for t in range(1, 12):
            x = seg[0] + (seg[2] - seg[0]) * t / 12
            y = seg[1] + (seg[3] - seg[1]) * t / 12
            if b[0] <= x <= b[2] and b[1] <= y <= b[3]:
                return True
        return False

    def cost(i, b, r, d, rank, placed, radii, dirs_used):
        c = r * 0.6 + rank * 0.35 + (0 if adjacent(r, d) else 3)
        mine = leader(i, b, r, d)
        for j, other in enumerate(placed):
            if other is None or j == i:
                continue
            if mine and crosses(mine, other):                     # my leader runs through another label
                c += 60
            theirs = leader(j, other, radii[j], dirs_used[j])
            if theirs and crosses(theirs, b):                     # another leader runs through my label
                c += 60
        for j, other in enumerate(placed):
            if other is not None and j != i:
                c += overlap(b, other) * 40
        for j, m in enumerate(marks):
            if j != i:
                c += overlap(b, m) * 60
        # the label must be nearer to its own marker than to another one: else it reads as that one's
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        own = math.hypot(cx - points[i]["x"], cy - points[i]["y"])
        for j, q in enumerate(points):
            if j != i and math.hypot(cx - q["x"], cy - q["y"]) < own + 10:
                c += 45
        out = max(0, plot[0] - b[0]) + max(0, b[2] - plot[2]) + max(0, plot[1] - b[1]) + max(0, b[3] - plot[3])
        return c + out * 80

    def choose(i, placed, radii, dirs_used):
        best = None
        for r in (R + 3, R + 14, R + 28, R + 46, R + 68):
            for rank, d in enumerate(order):
                b = box(points[i], r, d)
                c = cost(i, b, r, d, rank, placed, radii, dirs_used)
                if best is None or c < best[0] - 1e-9:
                    best = (c, b, r, d)
            if best[0] < 10 and r == R + 3:
                break
        return best

    neighbours = [sum(1 for q in points if q is not p and math.hypot(p["x"] - q["x"], p["y"] - q["y"]) < 80)
                  for p in points]
    ranking = sorted(range(len(points)), key=lambda i: (-neighbours[i], points[i]["x"], points[i]["y"]))
    placed = [None] * len(points)
    radius = [0.0] * len(points)
    used = [0] * len(points)
    for i in ranking:
        _, placed[i], radius[i], used[i] = choose(i, placed, radius, used)
    for _ in range(4):
        for i in ranking:
            placed[i] = None
            _, placed[i], radius[i], used[i] = choose(i, placed, radius, used)
    for i, p in enumerate(points):
        p["box"], p["far"] = placed[i], not adjacent(radius[i], used[i])
    return points


# ---------------------------------------------------------------------------------------------------------------
# SVG
# ---------------------------------------------------------------------------------------------------------------
def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def marker(shape, x, y, cls):
    if shape == "circle":
        return f'<circle class="{cls}" cx="{x:.1f}" cy="{y:.1f}" r="{R:.1f}"/>'
    if shape == "square":
        return f'<rect class="{cls}" x="{x - R:.1f}" y="{y - R:.1f}" width="{2 * R:.1f}" height="{2 * R:.1f}" rx="1"/>'
    s = R * 1.25                                                    # triangle: same weight as the others
    return (f'<polygon class="{cls}" points="{x:.1f},{y - s:.1f} {x + s:.1f},{y + s * 0.8:.1f} '
            f'{x - s:.1f},{y + s * 0.8:.1f}"/>')


def css():
    light = "".join(f"--mech-{k}: {lc}; " for k, _, _, lc, _ in FAMILIES)
    dark = "".join(f"--mech-{k}: {dc}; " for k, _, _, _, dc in FAMILIES)
    fam = "\n".join(f".mechs .f-{k} {{ fill: var(--mech-{k}); }}" for k, *_ in FAMILIES)
    return f"""
.mechs {{ {light}--mech-ring: var(--md-default-bg-color, #fff); color: inherit; font-family: inherit; }}
[data-md-color-scheme="slate"] .mechs {{ {dark}}}
.mechs text {{ font-size: {FONT:g}px; fill: currentColor; }}
.mechs .tick text {{ font-size: {TICK:g}px; opacity: .85; }}
.mechs .axis-title {{ font-size: {AXIS:g}px; opacity: .95; }}
.mechs .grid {{ stroke: currentColor; stroke-width: 1; opacity: .13; }}
.mechs .grid-minor {{ stroke: currentColor; stroke-width: 1; opacity: .06; }}
.mechs .frame {{ fill: none; stroke: currentColor; stroke-width: 1; opacity: .35; }}
.mechs .leader {{ stroke: currentColor; stroke-width: 1; opacity: .4; }}
{fam}
.mechs .mk {{ stroke: var(--mech-ring); stroke-width: 2; paint-order: stroke; }}
.mechs .pt .hit {{ fill: transparent; }}
.mechs .pt:hover .mk {{ stroke: currentColor; stroke-width: 2; }}
.mechs .pt:hover text {{ font-weight: 700; }}
"""


def svg(points, total):
    x0, x1, y0, y1 = LEFT, W - RIGHT, TOP, H - BOTTOM
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" class="mechs" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" '
           f'aria-labelledby="mechs-title mechs-desc">',
           '<title id="mechs-title">Size of the mechanisms of the database: species against reactions</title>']
    desc = "; ".join(f"{name} {p['ns']} species {p['nr']} reactions"
                     for p in sorted(points, key=lambda p: p["name"].lower()) for name in p["names"])
    out.append(f'<desc id="mechs-desc">{total} mechanisms, logarithmic axes. {esc(desc)}.</desc>')
    out.append(f"<style>{css()}</style>")
    # grid: a line per decade, a fainter one at 2 and 5
    for decade in range(0, 4):
        for m in (1, 2, 5):
            v = m * 10 ** decade
            if X_RANGE[0] < v < X_RANGE[1]:
                x = px(v)
                out.append(f'<line class="{"grid" if m == 1 else "grid-minor"}" x1="{x:.1f}" y1="{y0}" x2="{x:.1f}" y2="{y1}"/>')
    for decade in range(0, 4):
        for m in (1, 2, 5):
            v = m * 10 ** decade
            if Y_RANGE[0] < v < Y_RANGE[1]:
                y = py(v)
                out.append(f'<line class="{"grid" if m == 1 else "grid-minor"}" x1="{x0}" y1="{y:.1f}" x2="{x1}" y2="{y:.1f}"/>')
    out.append(f'<rect class="frame" x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}"/>')
    for v in (10, 100):
        out.append(f'<g class="tick"><text x="{px(v):.1f}" y="{y1 + TICK + 8:.1f}" text-anchor="middle">{v}</text></g>')
    for v in (1, 10, 100, 1000):
        if Y_RANGE[0] < v < Y_RANGE[1]:
            out.append(f'<g class="tick"><text x="{x0 - 10}" y="{py(v) + TICK * 0.35:.1f}" text-anchor="end">{v:,}</text></g>')
    out.append(f'<text class="axis-title" x="{(x0 + x1) / 2:.1f}" y="{H - 16}" text-anchor="middle">Species</text>')
    out.append(f'<text class="axis-title" transform="translate({AXIS + 6:.1f} {(y0 + y1) / 2:.1f}) rotate(-90)" text-anchor="middle">Reactions</text>')
    # legend: one row above the plot, the shape and the colour of each family
    x = x0
    for key, label, shape, *_ in FAMILIES:
        n = sum(len(p["names"]) for p in points if p["family"] == key)
        out.append(marker(shape, x + R, 30, f"mk f-{key}"))
        text = f"{label} ({n})"
        out.append(f'<text x="{x + 2 * R + 8:.1f}" y="{30 + FONT * 0.35:.1f}">{esc(text)}</text>')
        x += 2 * R + 8 + len(text) * CHAR + 30
    # leaders first (under the markers), then the points with their labels
    for p in points:
        if p["far"]:
            bx0, by0, bx1, by1 = p["box"]
            ex = bx0 if p["x"] < bx0 else bx1 if p["x"] > bx1 else p["x"]
            ey = by0 if p["y"] < by0 else by1 if p["y"] > by1 else p["y"]
            out.append(f'<line class="leader" x1="{p["x"]:.1f}" y1="{p["y"]:.1f}" x2="{ex:.1f}" y2="{ey:.1f}"/>')
    shapes = {key: shape for key, _, shape, *_ in FAMILIES}
    for p in sorted(points, key=lambda p: p["name"].lower()):
        bx0, by0, bx1, by1 = p["box"]
        anchor_x = bx0 + 2 if abs((bx0 + bx1) / 2 - p["x"]) > 1 and (bx0 + bx1) / 2 > p["x"] else bx1 - 2
        anchor = "start" if anchor_x == bx0 + 2 else "end"
        if abs((bx0 + bx1) / 2 - p["x"]) <= 1:
            anchor, anchor_x = "middle", (bx0 + bx1) / 2
        tip = f'{p["name"]}: {p["ns"]} species, {p["nr"]} reaction{"" if p["nr"] == 1 else "s"}'
        out.append(f'<g class="pt"><title>{esc(tip)}</title>'
                   f'<circle class="hit" cx="{p["x"]:.1f}" cy="{p["y"]:.1f}" r="11"/>'
                   + marker(shapes[p["family"]], p["x"], p["y"], f'mk f-{p["family"]}')
                   + f'<text x="{anchor_x:.1f}" y="{(by0 + by1) / 2 + 3.8:.1f}" text-anchor="{anchor}">{esc(p["name"])}</text></g>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


def build():
    points = unique(mechanisms())
    for p in points:
        p["x"], p["y"] = px(p["ns"]), py(p["nr"])
    return svg(place_labels(points), sum(len(p["names"]) for p in points)), points


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true", help="compare with the file instead of writing it")
    args = ap.parse_args()
    text, points = build()
    if args.check:
        try:
            current = open(args.out, encoding="utf-8").read()
        except OSError:
            current = None
        if current != text:
            print(f"[ERROR] {os.path.relpath(args.out, ROOT)} is not what the database gives now "
                  f"({sum(len(p['names']) for p in points)} mechanisms): run python3 database/chemistry/resume.py")
            sys.exit(1)
        print(f"[ok] {os.path.relpath(args.out, ROOT)} is current ({sum(len(p['names']) for p in points)} mechanisms)")
        return
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"{os.path.relpath(args.out, ROOT)}: {sum(len(p['names']) for p in points)} mechanisms")


if __name__ == "__main__":
    main()
