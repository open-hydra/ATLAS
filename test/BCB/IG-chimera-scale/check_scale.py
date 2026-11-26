"""IG-chimera-scale: the boundary conditions of BCB do not depend on the size of the mesh.

Three blocks of cells of side H, on the same rows: block 1 (8 cells in x, from 0), block 2 (8 cells, from 4.3 H, so that
it overlaps block 1 by 3.7 cells) and block 3 (3 cells, from -3 H). Face 2 of block 1 and face 1 of block 2 are
chimera faces, whose ghost cells take donors of fractions 0.3 and 0.7; face 1 of block 1 and face 2 of block 3 are a
connection; the other faces extrapolate. Four meshes: plane (2-D, one cell of H in z), 3d (4 cells of H in z),
3d-thick (4 cells of 1 m in z whatever H: facelets of H x 1 m) and wedge (2-D axisymmetric, 1 degree, first node row
at r = 20 H). Each is written at H = 1 m, 1 mm, 10 um, 1 um and 0.1 um and run through BCB in _run-<mesh>-<H>. Every
size must give the bc.txt of 1 m: the same records, the same donors and the same volume fractions (to 1e-12); the
same receivers in chimera.log with the same verdicts and the same volumes over the cell volume at 1 m scaled (H^3,
H^2 for 3d-thick; to 1e-10); the same WARNING and LOG lines. The 1 m run itself must be complete: every chimera
facelet with donors in its two ghost layers, every connection facelet a 101 record.
A fifth mesh, flat, is plane with the first two node columns of block 2 at the same x: the ghost cells behind its
face 1 have no volume. At 1 m and at 0.1 um those six facelets take no donor (one WARNING line), BCB ends normally,
and block 1's receivers close as in plane.

Usage: python3 check_scale.py <ATLAS.sh>
"""
import math
import os
import re
import shutil
import subprocess
import sys

SIZES = [("1m", 1.0), ("1mm", 1.0e-3), ("10um", 1.0e-5), ("1um", 1.0e-6), ("100nm", 1.0e-7)]
NJ, NK3D = 6, 4
BLOCKS = [(8, 0.0), (8, 4.3), (3, -3.0)]   # cells in x, first node in x (in H)
WEDGE = math.radians(1.0)


def nodes(mesh, ni, x0, h, b):
    nk = NK3D if mesh.startswith("3d") else 1
    out = []
    for k in range(nk + 1):
        for j in range(NJ + 1):
            for i in range(ni + 1):
                x = (x0 + i) * h
                if mesh == "flat" and b == 2 and i == 1:
                    x = x0 * h        # cells i = 1 of block 2 flat, and its ghost cells behind face 1
                if mesh == "wedge":
                    r, t = (20 + j) * h, (k - 0.5) * WEDGE
                    out.append((x, r * math.cos(t), r * math.sin(t)))
                else:
                    out.append((x, j * h, k * (1.0 if mesh == "3d-thick" else h)))
    return out, nk


def write_case(mesh, h, d):
    os.makedirs(d)
    with open(os.path.join(d, "mesh.tec"), "w") as f:
        f.write(' VARIABLES ="x" "y" "z"\n')
        for b, (ni, x0) in enumerate(BLOCKS, 1):
            pts, nk = nodes(mesh, ni, x0, h, b)
            f.write(" ZONE  T = Block%d, I=%d, J=%d, K=%d, DATAPACKING=BLOCK, VARLOCATION=([1-3]=NODAL)\n"
                    % (b, ni + 1, NJ + 1, nk + 1))
            for c in range(3):
                f.write("".join("%.17e\n" % p[c] for p in pts))
    nf = 6 if mesh.startswith("3d") else 4
    kinds = {1: {1: "connection", 2: "chimera"}, 2: {1: "chimera"}, 3: {2: "connection"}}
    with open(os.path.join(d, "input.ini"), "w") as f:
        f.write("[ATLAS-Parameters]\nBC-chimera = true\n")
        for b in (1, 2, 3):
            f.write("\n[BCB-Block%d]\n" % b)
            for face in range(1, nf + 1):
                f.write("face%d = %s\n" % (face, kinds[b].get(face, "extrapolation")))
    shutil.copy("phase.txt", d)


def run(atlas, d):
    p = subprocess.run([atlas, "BCB"], cwd=d, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       universal_newlines=True)
    with open(os.path.join(d, "bcb.log"), "w") as f:
        f.write(p.stdout)
    if p.returncode != 0:
        print("  BCB exit %d in %s" % (p.returncode, d))
        return None
    msgs = [l.strip() for l in p.stdout.splitlines() if l.strip().startswith(("[WARNING] chimera", "[LOG]"))]
    with open(os.path.join(d, "fromATLAStoSolver", "bc.txt")) as f:
        bc = f.read().split()
    log = []   # (verdict, receiver, [volumes])
    with open(os.path.join(d, "chimera.log")) as f:
        for line in f:
            s = line.strip()
            if s.startswith(("Volume division", "Chimera volume")):
                log.append([s, None, []])
            elif s.startswith("- Receiver ID"):
                log[-1][1] = s.split("=")[1].split()
            elif s.startswith("- Receiver") or s.startswith("- Volume per donor block"):
                log[-1][2] += [float(v) for v in re.findall(r"[-+]?\d+\.\d*E[-+]\d+", s)]
    return bc, log, msgs


def compare(ref, got, h, vs):
    """Differences of got (size h, cell volumes scaled by vs) from ref (1 m), as a list of strings."""
    bc0, log0, msg0 = ref
    bc1, log1, msg1 = got
    out = []
    if len(bc0) != len(bc1):
        out.append("bc.txt: %d tokens, %d at 1 m" % (len(bc1), len(bc0)))
    else:
        nint = nfl = 0
        dmax = 0.0
        for a, b in zip(bc0, bc1):
            if "E" in a or "E" in b:
                d = abs(float(a) - float(b))
                dmax = max(dmax, d)
                nfl += d > 1e-12
            else:
                nint += a != b
        if nint:
            out.append("bc.txt: %d integer fields differ" % nint)
        if nfl:
            out.append("bc.txt: %d volume fractions differ by more than 1e-12 (max %.3e)" % (nfl, dmax))
    if [(v, r) for v, r, _ in log0] != [(v, r) for v, r, _ in log1]:
        nd = sum(1 for x, y in zip(log0, log1) if x[:2] != y[:2]) + abs(len(log0) - len(log1))
        out.append("chimera.log: %d receivers or verdicts differ (%d logged, %d at 1 m)" % (nd, len(log1), len(log0)))
    else:
        r = 0.0
        for x, y in zip(log0, log1):
            for a, b in zip(x[2], y[2]):
                r = max(r, abs(b / vs - a) / max(abs(a), 1e-300))
        if r > 1e-10:
            out.append("chimera.log: scaled volumes differ by %.3e relative" % r)
    if msg0 != msg1:
        out.append("WARNING/LOG lines differ: %s" % [m for m in msg1 if m not in msg0][:3])
    return out


def main():
    atlas = sys.argv[1]
    failed = False
    for mesh in ("plane", "3d", "3d-thick", "wedge", "flat"):
        res = {}
        sizes = [SIZES[0], SIZES[-1]] if mesh == "flat" else SIZES
        for tag, h in sizes:
            d = "_run-%s-%s" % (mesh, tag)
            if os.path.exists(d):
                shutil.rmtree(d)
            write_case(mesh, h, d)
            res[tag] = run(atlas, d)
            if res[tag] is None:
                failed = True
        ref = res["1m"]
        if ref is None:
            continue
        bad = [m for m in ref[2] if m.startswith("[WARNING] chimera")]
        n101 = ref[0].count("101")
        nk = NK3D if mesh.startswith("3d") else 1
        want = []
        if mesh == "flat":
            want = ["[WARNING] chimera: block 2 face 1: %d facelet(s) found no donor and keep ID 100, on which MOSE "
                    "applies no boundary flux" % NJ]
        nok = sum(1 for v, r, _ in ref[1] if v == "Volume division succesful")
        if bad != want or n101 < 2 * NJ * nk or nok < (2 if mesh == "flat" else 4) * NJ * nk:
            print("FAIL %-8s 1m: not the expected set-up (chimera warnings %s, %d connection records, %d receivers "
                  "closed)" % (mesh, bad, n101, nok))
            failed = True
        for tag, h in sizes[1:]:
            if res[tag] is None:
                continue
            diff = compare(ref, res[tag], h, h**2 if mesh == "3d-thick" else h**3)
            print("%s %-8s %-5s %s" % ("FAIL" if diff else "PASS", mesh, tag, "; ".join(diff) or "as at 1 m"))
            failed = failed or bool(diff)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
