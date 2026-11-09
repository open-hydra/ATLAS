#!/usr/bin/env python3
"""DP-chimera-pure2D: write mesh.tec, the first node plane of ../DP-chimera/mesh.tec.

DP-chimera's mesh is a planar slab: two zones in BLOCK packing, each with two node planes (K = 2) of identical x-y
at z = -0.0005 and +0.0005. Keeping the first plane of every zone (K = 1, z = -0.0005 on every node, constant)
gives the same x-y geometry as one node plane, which ATLAS reads as a pure-2D mesh. The values are copied as
they are written in the source file.
  python3 make_mesh.py      writes mesh.tec in this folder
Python >= 3.6, standard library only.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "DP-chimera", "mesh.tec")
TARGET = os.path.join(HERE, "mesh.tec")
NVAR = 3


def read_zones(path):
    """[(title, ni, nj, nk, [values of X], [values of Y], [values of Z])] of a BLOCK-packed Tecplot file."""
    with open(path) as f:
        lines = f.read().splitlines()
    zones, n = [], 0
    while n < len(lines):
        line = lines[n]
        if not line.strip().upper().startswith("ZONE"):
            n += 1
            continue
        header = line
        n += 1
        while n < len(lines) and re.match(r"\s*[A-Za-z]", lines[n]):
            header += " " + lines[n]
            n += 1
        if "BLOCK" not in header.upper():
            sys.exit("make_mesh.py: zone without DATAPACKING=BLOCK in " + path)
        title = re.search(r'T\s*=\s*"([^"]*)"', header).group(1)
        ni, nj, nk = (int(re.search(r"\b%s\s*=\s*(\d+)" % c, header).group(1)) for c in "IJK")
        values = []
        while len(values) < NVAR * ni * nj * nk:
            values.extend(lines[n].split())
            n += 1
        size = ni * nj * nk
        zones.append((title, ni, nj, nk) + tuple(values[v * size:(v + 1) * size] for v in range(NVAR)))
    return zones


def main():
    zones = read_zones(SOURCE)
    with open(TARGET, "w") as f:
        f.write(' TITLE     = "the first node plane of DP-chimera/mesh.tec"\n')
        f.write(' VARIABLES = "X", "Y", "Z"\n')
        for title, ni, nj, nk, *coords in zones:
            f.write(' ZONE T="%s"\n I=%3d, J=%3d, K=%3d, ZONETYPE=Ordered\n DATAPACKING=BLOCK\n' % (title, ni, nj, 1))
            for c in coords:
                f.write("\n".join(c[:ni * nj]) + "\n")
    print("make_mesh.py: wrote %s (%d zones, K = 1)" % (TARGET, len(zones)))


if __name__ == "__main__":
    main()
