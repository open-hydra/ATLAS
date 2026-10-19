"""mesh.tec of the IG-chimera-warped test: two overlapping blocks of a twisted sector.

Both blocks fill part of the sector r in [1, 2.6], theta in [0, 7.5] deg, z in [0, 0.1];
theta grows with z (40 deg per unit z, 3% more in block 2), so the faces of constant j
are helicoids and every cell is warped. Block 2 starts at r = 1.65629: the inner ghost
cells of its face 1 reach r = 1.499, 0.6% of their thickness into block 1's cells of
r < 1.5, and the outer ghost cells of block 1's face 2 reach 2.4% into block 2's
cells of r < 2.128.
"""
import math


def block(ni, nj, nk, r0, r1, t0, t1, z0, z1, twist):
    pts = []
    for k in range(nk):
        for j in range(nj):
            for i in range(ni):
                r = r0 + (r1 - r0)*i/(ni - 1)
                z = z0 + (z1 - z0)*k/(nk - 1)
                t = math.radians(t0 + (t1 - t0)*j/(nj - 1) + twist*z)
                pts.append((r*math.cos(t), r*math.sin(t), z))
    return pts


blocks = [((9, 7, 8), block(9, 7, 8, 1.0, 2.0, 0.0, 7.5, 0.0, 0.1, 40.0)),
          ((7, 6, 9), block(7, 6, 9, 1.65629, 2.6, 0.3, 7.2, 0.002, 0.098, 41.2))]
with open("mesh.tec", "w") as f:
    f.write(' VARIABLES ="x" "y" "z"\n')
    for n, ((ni, nj, nk), pts) in enumerate(blocks, 1):
        f.write(f" ZONE  T = Block{n}, I={ni}, J={nj}, K={nk}, DATAPACKING=BLOCK, VARLOCATION=([1-3]=NODAL)\n")
        for c in range(3):
            for p in pts:
                f.write(f"{p[c]:.15e}\n")
