"""One 60-degree sector of a helical annulus about x, the mesh.tec of IG-periodic-rotated (python3 make-mesh.py mesh.tec):
i azimuth, j radius, k axis, theta = theta_i + tau*x. The two i faces (1, 2) are helicoids, images of each other by a
60-degree turn about x; the cells are 3 times longer along x than along r.
With --not-images (not-images/mesh.tec) the radial nodes are graded more and more towards r1 as i grows: face 2 lies on
the image of face 1, but its nodes do not."""
import math, sys
ni, nj, nk = 4, 3, 4                      # cells
th = math.radians(60.0)
r1, r2 = 1.0, 1.3                          # dr = 0.1
L = 1.2                                    # dx = 0.3 (dx/dr = 3)
tau = 1.0 / 1.15                           # tau*r ~ 1 at mid radius
grade = 0.3 if '--not-images' in sys.argv[2:] else 0.0
X, Y, Z = [], [], []
for k in range(nk + 1):
    for j in range(nj + 1):
        for i in range(ni + 1):
            x = L * k / nk
            r = r1 + (r2 - r1) * (j / nj) ** (1.0 + grade * i / ni)
            t = th * i / ni + tau * x
            X.append(x); Y.append(r * math.cos(t)); Z.append(r * math.sin(t))
with open(sys.argv[1], 'w') as f:
    f.write(' TITLE     = "helical sector" \n VARIABLES = "X", "Y", "Z" \n ZONE T="BLOCCO 1" \n')
    f.write(f' I= {ni+1}, J= {nj+1}, K= {nk+1}, ZONETYPE=Ordered \n DATAPACKING=BLOCK \n')
    for v in (X, Y, Z):
        for a in v:
            f.write(f'{a!r}\n')
