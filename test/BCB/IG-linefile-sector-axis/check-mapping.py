#!/usr/bin/env python3
"""IG-linefile-sector-axis: the line-file mapping with n-repeat = 4 and axis = x, checked against a closed form.

strip.tec is one sector (a quarter of the lap) of an unwrapped 2D record: s runs over the node span L from S0,
the sector phase is phi = 2 pi (s - S0) / L. Every variable is a closed-form law of phi, piecewise linear with
its two kinks on strip cell centres, so the periodic linear interpolation of the mapping reproduces the law
exactly. input.ini maps it onto face 6 of an annulus about x (mesh.tec), with axis = x and n-repeat = 4. For
every face cell, theta = its angle about +x through `center` (right-handed), the mapped series must hold
  rho(1), p = law(4 theta mod 2 pi);  (u, v, w) = sgn * u_law e_x + v_law e_theta  (no radial component),
sgn being the direction of the inward normal along x, taken from mesh.tec (the node layer next to the face):
a positive axial velocity of the record enters the domain. The zone times and the face nodes must be those of
strip.tec and mesh.tec. Nothing is compared with a stored output of ATLAS.
  python3 check-mapping.py           checks mapped.tec (written by ATLAS.sh BCB in this folder)
  python3 check-mapping.py --write   writes mesh.tec and strip.tec
Python >= 3.6, standard library only.
"""
import math
import re
import sys

TWOPI = 2.0 * math.pi
NREP, CENTER = 4, (0.5, 0.01, -0.02)          # n-repeat and center of input.ini
R0, R1, NR, M = 0.040, 0.050, 2, 44           # radial nodes; M cells around the lap (11 per sector)
X0, X1, NA = 0.49, 0.51, 2                    # axial nodes; face 6 (last k layer) lies at x = X1
N, S0, L = 10, 0.25, TWOPI * 0.045 / NREP     # strip cells, first node, node span (a sector at r = 0.045 m)
TIMES = (1.0e-4, 2.0e-4, 3.0e-4)
NAMES = ("rho(1)", "u", "v", "p")             # u: along the strip x (axial), v: along s (circumferential)
LAW = {"rho(1)": (1.2, 0.4, 0), "u": (150.0, 50.0, 2), "v": (40.0, 20.0, 5), "p": (1.0e5, 2.0e4, 7)}


def law(name, phi, zone):
    """base + amp * tent: 1 at the strip cell centre (shift + zone), 0 half a lap away, linear in between."""
    base, amp, shift = LAW[name]
    psi = (phi - (0.5 + shift + zone) * TWOPI / N) % TWOPI
    return base + amp * abs(psi / math.pi - 1.0)


def mesh_nodes():
    """node (i, j, k) of the annulus: i radial, j around +x from +y, k along x (a right-handed block)."""
    nodes = {}
    for k in range(NA + 1):
        for j in range(M + 1):
            for i in range(NR + 1):
                r, t = R0 + (R1 - R0) * i / NR, TWOPI * j / M
                nodes[i, j, k] = (X0 + (X1 - X0) * k / NA, CENTER[1] + r * math.cos(t), CENTER[2] + r * math.sin(t))
    return nodes


def write():
    nodes = mesh_nodes()
    with open("mesh.tec", "w") as f:
        f.write(' TITLE     = "annulus about x"\n VARIABLES = "X", "Y", "Z"\n ZONE T="BLOCCO 1"\n')
        f.write(" I=%3d, J=%3d, K=%3d, ZONETYPE=Ordered\n DATAPACKING=BLOCK\n" % (NR + 1, M + 1, NA + 1))
        for c in range(3):
            for k in range(NA + 1):
                for j in range(M + 1):
                    for i in range(NR + 1):
                        f.write("%.15e\n" % nodes[i, j, k][c])
    s = [S0 + L * i / N for i in range(N + 1)]
    with open("strip.tec", "w") as f:
        f.write(' VARIABLES ="x" "y" ' + " ".join('"%s"' % n for n in NAMES) + "\n")
        for z, t in enumerate(TIMES):
            f.write(" ZONE  T = strip, I=%d, J=2, K=1, DATAPACKING=BLOCK, VARLOCATION=([1-2]=NODAL,[3-%d]=CELLCENTERED),"
                    " SOLUTIONTIME=%.15e\n" % (N + 1, 2 + len(NAMES), t))
            values = [0.0986] * (N + 1) + [0.1] * (N + 1) + s + s
            for n in NAMES:
                values += [law(n, TWOPI * (i + 0.5) / N, z) for i in range(N)]
            f.write("".join("%.15e\n" % v for v in values))


def read_tecplot(path, header_end):
    """(variable names, [(zone header, numbers after it)]); header_end = regex of the last header line of a zone."""
    names, zones = [], []
    for line in open(path):
        if not names and "VARIABLES" in line:
            names = re.findall(r'"([^"]+)"', line)
        elif re.search(r"\bZONE\b", line):
            zones.append([line, []])
        elif zones and not re.search(header_end, line):
            zones[-1][1] += [float(x) for x in line.split()]
    return names, zones


def check():
    fails = []
    def close(a, b, scale, what):
        if abs(a - b) > 1e-12 * max(abs(b), scale):
            fails.append("%s: %.17g, the closed form gives %.17g" % (what, a, b))
    nodes = mesh_nodes()
    _, mz = read_tecplot("mesh.tec", r"^\s*(I=|DATAPACKING)")
    mv = mz[0][1]
    npts = (NR + 1) * (M + 1) * (NA + 1)
    mesh = lambda i, j, k, c: mv[c * npts + i + (NR + 1) * (j + (M + 1) * k)]
    for key, xyz in nodes.items():
        for c in range(3):
            close(mesh(key[0], key[1], key[2], c), xyz[c], 1.0, "mesh.tec node %s" % (key,))
    sgn = math.copysign(1.0, sum(mesh(i, j, NA - 1, 0) - mesh(i, j, NA, 0) for i in range(NR + 1) for j in range(M + 1)))
    _, sz = read_tecplot("strip.tec", r"^$")
    for z, (head, v) in enumerate(sz):
        for q, n in enumerate(NAMES):
            for i in range(N):
                close(v[4 * (N + 1) + q * N + i], law(n, TWOPI * (i + 0.5) / N, z), LAW[n][1], "strip.tec zone %d %s" % (z + 1, n))
    names, zones = read_tecplot("mapped.tec", r"^$")
    if names != ["x", "y", "z", "rho(1)", "u", "v", "p", "w"] or len(zones) != len(TIMES):
        sys.exit("FAIL: mapped.tec has variables %s and %d zones (expected x y z rho(1) u v p w, %d zones)" % (names, len(zones), len(TIMES)))
    n1, n2 = NR, M
    nn, nc = (n1 + 1) * (n2 + 1), n1 * n2
    for z, (head, v) in enumerate(zones):
        dims = re.search(r"I=(\d+), J=(\d+), K=1", head)
        time = re.search(r"SOLUTIONTIME=\s*([-+.0-9Ee]+)", head)
        if not dims or (int(dims.group(1)), int(dims.group(2))) != (n1 + 1, n2 + 1) or len(v) != 3 * nn + 5 * nc:
            sys.exit("FAIL: zone %d of mapped.tec: %s" % (z + 1, head.strip()))
        if not time or abs(float(time.group(1)) - TIMES[z]) > 1e-8 * TIMES[z]:
            fails.append("zone %d: SOLUTIONTIME %s, strip.tec has %g" % (z + 1, time and time.group(1), TIMES[z]))
        for i2 in range(n2 + 1):
            for i1 in range(n1 + 1):
                for c in range(3):
                    close(v[c * nn + i1 + (n1 + 1) * i2], mesh(i1, i2, NA, c), 1.0, "zone %d node (%d,%d)" % (z + 1, i1, i2))
        cell = lambda q, i1, i2: v[3 * nn + q * nc + (i1 - 1) + n1 * (i2 - 1)]
        for i2 in range(1, n2 + 1):
            for i1 in range(1, n1 + 1):
                cy, cz = [0.25 * sum(mesh(a, b, NA, c) for a in (i1 - 1, i1) for b in (i2 - 1, i2)) for c in (1, 2)]
                theta = math.atan2(cz - CENTER[2], cy - CENTER[1]) % TWOPI
                phi = (NREP * theta) % TWOPI
                ua, vt = law("u", phi, z), law("v", phi, z)
                where = "zone %d cell (%d,%d) theta %.6f" % (z + 1, i1, i2, theta)
                for q, name, ref, scale in ((0, "rho(1)", law("rho(1)", phi, z), 0.4), (3, "p", law("p", phi, z), 2e4),
                                            (1, "u", sgn * ua, 50.0), (2, "v", -vt * math.sin(theta), 20.0),
                                            (4, "w", vt * math.cos(theta), 20.0)):
                    close(cell(q, i1, i2), ref, scale, "%s %s" % (where, name))
    if fails:
        print("\n".join("FAIL: " + f for f in fails[:10]))
        sys.exit("IG-linefile-sector-axis: %d values differ from the closed form" % len(fails))
    print("IG-linefile-sector-axis: %d face cells x %d zones: rho(1) and p = law(%d theta), axial velocity along "
          "the inward normal (%sx), tangential velocity right-handed about +x, no radial component: OK"
          % (n1 * n2, len(zones), NREP, "+" if sgn > 0 else "-"))


if __name__ == "__main__":
    write() if sys.argv[1:] == ["--write"] else check()
