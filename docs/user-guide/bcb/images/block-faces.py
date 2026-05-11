import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from matplotlib import rcParams
import matplotlib as mpl

#Configure mpl for transparent SVG with theme-aware styling
mpl.rcParams.update({
    "figure.facecolor": "none",
    "axes.facecolor": "none",
    "savefig.facecolor": "none",
    "svg.fonttype": "none",
})

# ── Parameters ────────────────────────────────────────────────────────────────
imax, jmax, kmax = 6, 5, 4
Lx, Ly, Lz = 1.0, 0.8, 0.6

x = np.linspace(0, Lx, imax)
y = np.linspace(0, Ly, jmax)
z = np.linspace(0, Lz, kmax)

# ── Geometry ──────────────────────────────────────────────────────────────────
P000=[0,0,0];   P100=[Lx,0,0];  P110=[Lx,Ly,0]; P010=[0,Ly,0]
P001=[0,0,Lz];  P101=[Lx,0,Lz]; P111=[Lx,Ly,Lz];P011=[0,Ly,Lz]

faces = [
    [P000, P010, P011, P001],
    [P100, P110, P111, P101],
    [P010, P110, P111, P011],
    [P000, P100, P101, P001],
    [P000, P100, P110, P010],
    [P001, P101, P111, P011],
]

# ── Colour palette — muted, professional ──────────────────────────────────────
face_colors  = ['#E05C5C', '#4A90D9', '#5CB87A', '#F5A623', '#9B59B6', '#1ABC9C']
face_alphas  = [0.55, 0.55, 0.55, 0.55, 0.55, 0.55]

OFF = 0.58
arrow_tails = [
    (-OFF,    Ly/2,    Lz/2),
    (Lx+OFF,  Ly/2,    Lz/2),
    (Lx/2,    Ly+OFF,  Lz/2),
    (Lx/2,   -OFF,     Lz/2),
    (Lx/2,    Ly/2,   -OFF ),
    (Lx/2,    Ly/2,    Lz+OFF),
]
arrow_dirs = [
    ( OFF*0.80, 0,          0         ),
    (-OFF*0.80, 0,          0         ),
    ( 0,       -OFF*0.80,   0         ),
    ( 0,        OFF*0.80,   0         ),
    ( 0,        0,          OFF*0.80  ),
    ( 0,        0,         -OFF*0.80  ),
]
face_labels = [
    'Face 1\n(i = 1)',
    'Face 2\n(i = imax)',
    'Face 4\n(j = jmax)',
    'Face 3\n(j = 1)',
    'Face 5\n(k = 1)',
    'Face 6\n(k = kmax)',
]

# ── Draw function ─────────────────────────────────────────────────────────────
def draw_block(ax):
    # Grid lines — very fine, light grey
    grid_kw = dict(color='#AABBC8', linewidth=0.55, alpha=0.75)
    for yv in y:
        for zv in z:
            ax.plot(x, np.full_like(x,yv), np.full_like(x,zv), **grid_kw)
    for xv in x:
        for zv in z:
            ax.plot(np.full_like(y,xv), y, np.full_like(y,zv), **grid_kw)
    for xv in x:
        for yv in y:
            ax.plot(np.full_like(z,xv), np.full_like(z,yv), z, **grid_kw)

    # Coloured faces
    for f, fc, fa in zip(faces, face_colors, face_alphas):
        poly = Poly3DCollection([f], alpha=fa, facecolor=fc, edgecolor='#3A3A3A', linewidth=1.0)
        ax.add_collection3d(poly)

    # Block outer edges — bold black outline
    edges = [
        # bottom
        ([0,Lx],[0,0],[0,0]),([0,Lx],[Ly,Ly],[0,0]),
        ([0,Lx],[0,0],[Lz,Lz]),([0,Lx],[Ly,Ly],[Lz,Lz]),
        # sides
        ([0,0],[0,Ly],[0,0]),([Lx,Lx],[0,Ly],[0,0]),
        ([0,0],[0,Ly],[Lz,Lz]),([Lx,Lx],[0,Ly],[Lz,Lz]),
        # verticals
        ([0,0],[0,0],[0,Lz]),([Lx,Lx],[0,0],[0,Lz]),
        ([0,0],[Ly,Ly],[0,Lz]),([Lx,Lx],[Ly,Ly],[0,Lz]),
    ]
    for ex, ey, ez in edges:
        ax.plot(ex, ey, ez, color='#1C2833', linewidth=1.6, zorder=5)

    # Arrows + labels
    for (xt,yt,zt),(dx,dy,dz),label,fc in zip(arrow_tails,arrow_dirs,face_labels,face_colors):
        ax.quiver(xt, yt, zt, dx, dy, dz, color=fc, linewidth=2.2, arrow_length_ratio=0.18, zorder=10)
        tx, ty, tz = xt - 0.48*dx, yt - 0.48*dy, zt - 0.48*dz
        ax.text(tx, ty, tz, label,
                fontsize=8.5, fontweight='bold', color=fc,
                ha='center', va='center', zorder=11)

    # Reference axes (i, j, k) — pushed well clear of the block
    orig   = np.array([-0.62, -0.62, -0.90])
    alen   = 0.28
    colors = ['#C0392B', '#27AE60', '#2980B9']
    dirs   = [np.array([alen,0,0]), np.array([0,alen,0]), np.array([0,0,alen])]
    lbls   = ['i', 'j', 'k']
    for d, c, l in zip(dirs, colors, lbls):
        ax.quiver(*orig, *d, color=c, linewidth=2.8, arrow_length_ratio=0.22)
        end = orig + d * 1.80
        ax.text(*end, l, color=c, fontsize=11, fontweight='bold', ha='center', va='center')

    # Axis limits & appearance
    pad = 0.72
    ax.set_xlim(-pad, Lx+pad)
    ax.set_ylim(-pad, Ly+pad)
    ax.set_zlim(-pad, Lz+pad)
    ax.set_box_aspect([Lx*3.5, Ly*3.5, Lz*3])

    for axis in [ax.xaxis, ax.yaxis, ax.zaxis]:
        axis.pane.fill = False
        axis.pane.set_edgecolor('none')
        axis.line.set_color('none')
        axis.set_ticklabels([])
        axis.set_ticks([])
    ax.set_xlabel(''); ax.set_ylabel(''); ax.set_zlabel('')
    ax.grid(False)

# ── Build figure ──────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(8, 6), facecolor='none')
ax  = fig.add_subplot(111, projection='3d', facecolor='none')

draw_block(ax)
ax.view_init(elev=16, azim=-52)

plt.subplots_adjust(top=1.0, bottom=0.0, left=0.0, right=1.0)
plt.savefig('docs/user-guide/bcb/images/block-faces.svg', dpi=180, bbox_inches='tight', facecolor='none', transparent=True)
print("Saved!")