"""Interactive PyVista viewports: rotate/pan/zoom, and a click picks what is
under the cursor.

:class:`MeshViewport` is the Boundaries stage's: every assignable block face is
drawn as its own pickable actor so a single left click selects exactly one face.
The k-planes of 2-D blocks are drawn faintly for context but are not pickable
(BCB assigns them automatically).

:class:`StateViewport` is the Initial stage's: the outer surfaces of the blocks,
every cell in a colour the stage gives it (the state ICB writes into the cell
beneath), and a click names the cell.

Picking uses a depth-correct ``vtkCellPicker`` driven by our own click handler so
the face actually in the foreground under the cursor is selected (rather than an
occluded one), while mouse drags still rotate/pan the camera.
"""

from __future__ import annotations

import numpy as np
import pyvista as pv
# Not ``import vtk``: that loads every VTK module, including vtkGUISupportQt,
# which on conda links its own Qt6 next to PyQt6's and aborts the QApplication.
from vtkmodules.vtkRenderingCore import vtkCellPicker
from pyvistaqt import QtInteractor
from PyQt6.QtWidgets import QWidget, QVBoxLayout
from PyQt6.QtCore import pyqtSignal

from . import faces as facemod

UNASSIGNED_COLOR = "#8a97a5"
HIGHLIGHT_EDGE = "#ffd23f"
CONTEXT_COLOR = "#c9d3dd"

# Surface material: a little ambient light keeps unlit faces readable, a weak
# specular adds just enough shading to tell neighbouring faces apart.
MATERIAL = dict(ambient=0.42, diffuse=0.78, specular=0.10, specular_power=20)

# Opacity used to "ghost" geometry that is not the current selection so a
# covered face can still be seen.
REVEAL_OPACITY = 0.12
CONTEXT_ALPHA = 0.12          # base opacity of the faint k-plane context surfaces
GHOST_OPACITY = 0.16          # per-block manual transparency toggle


class _View(QWidget):
    """Qt widget wrapping a :class:`pyvistaqt.QtInteractor`: the themed
    background and axes, a caption until a mesh is loaded, the camera presets,
    and a left click told from a drag and handed to :meth:`_picked`."""

    PLACEHOLDER = "No mesh loaded\nUse  Load Mesh  to open a Tecplot or Plot3D grid"
    THEME_KEYS = ("viewport_bg", "viewport_bg2", "edge", "unassigned", "context",
                  "highlight_edge", "label_text", "label_shape")

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.plotter = QtInteractor(self)
        layout.addWidget(self.plotter.interactor)

        self.blocks = []
        self._placeholder = None

        # Themeable colours (overwritten by apply_theme).
        self.theme = {
            "viewport_bg": "#0e141b", "viewport_bg2": "#1b2733",
            "edge": "#4b5a68",
            "unassigned": UNASSIGNED_COLOR, "context": CONTEXT_COLOR,
            "highlight_edge": HIGHLIGHT_EDGE,
            "label_text": "white", "label_shape": "#1f3550",
        }

        self._picker = vtkCellPicker()
        self._picker.SetTolerance(0.005)
        self._press_pos = None
        self._observers_set = False

        self._apply_background()
        self._add_axes()
        self._show_placeholder()
        # Smooth the jagged edges of the face outlines; harmless if the driver
        # refuses the request.
        try:
            self.plotter.enable_anti_aliasing("fxaa")
        except Exception:
            pass

    # -- theming ---------------------------------------------------------
    def _apply_background(self):
        """Vertical gradient background (flat if the renderer refuses it)."""
        try:
            self.plotter.set_background(self.theme["viewport_bg"],
                                        top=self.theme["viewport_bg2"])
        except Exception:
            self.plotter.set_background(self.theme["viewport_bg"])

    def _show_placeholder(self):
        """Empty-state caption, shown until a mesh is loaded."""
        if self.blocks:
            return
        try:
            self._placeholder = self.plotter.add_text(
                self.PLACEHOLDER, position=(0.5, 0.5), viewport=True, font_size=11,
                color=self.theme["unassigned"], name="placeholder")
            prop = self._placeholder.GetTextProperty()
            prop.SetJustificationToCentered()
            prop.SetVerticalJustificationToCentered()
            prop.SetLineSpacing(1.6)
        except Exception:
            self._placeholder = None

    def _clear_placeholder(self):
        if self._placeholder is not None:
            try:
                self.plotter.remove_actor(self._placeholder)
            except Exception:
                pass
            self._placeholder = None

    def _add_axes(self):
        """Orientation marker, tinted for the active theme."""
        try:
            self.plotter.add_axes(line_width=3, labels_off=False,
                                  color=self.theme["label_text"],
                                  x_color="#e05c5c", y_color="#5cb87a",
                                  z_color="#4a90d9")
        except Exception:
            self.plotter.add_axes()

    def apply_theme(self, tokens):
        for k in self.THEME_KEYS:
            if k in tokens:
                self.theme[k] = tokens[k]
        self._apply_background()
        self._add_axes()

    def _clear_scene(self, blocks):
        """Drop every actor and take *blocks* as the mesh."""
        self.plotter.clear()
        self._placeholder = None     # dropped by clear()
        self._add_axes()
        self.blocks = blocks
        self._show_placeholder()

    # -- picking ---------------------------------------------------------
    def _install_click_observers(self):
        if self._observers_set:
            return
        iren = self.plotter.iren
        iren.add_observer("LeftButtonPressEvent", self._on_left_press)
        iren.add_observer("LeftButtonReleaseEvent", self._on_left_release)
        self._observers_set = True

    def _on_left_press(self, obj, event):
        self._press_pos = obj.GetEventPosition()

    def _on_left_release(self, obj, event):
        if self._press_pos is None:
            return
        x0, y0 = self._press_pos
        x, y = obj.GetEventPosition()
        self._press_pos = None
        if abs(x - x0) > 4 or abs(y - y0) > 4:
            return  # a drag (rotate/pan/zoom), not a click
        self._pick_at(x, y)

    def _pick_at(self, x, y):
        ren = self.plotter.renderer
        self._picker.Pick(x, y, 0, ren)
        actor = self._picker.GetActor()
        if actor is not None:
            self._picked(actor, self._picker.GetCellId())

    def _picked(self, actor, cell):
        """A click on cell *cell* of *actor*."""

    # -- camera ----------------------------------------------------------
    def view_isometric(self):
        self.plotter.view_isometric(); self.plotter.render()

    def view_xy(self):
        self.plotter.view_xy(); self.plotter.render()

    def view_xz(self):
        self.plotter.view_xz(); self.plotter.render()

    def view_yz(self):
        self.plotter.view_yz(); self.plotter.render()

    def reset_camera(self):
        self.plotter.reset_camera(); self.plotter.render()

    def close(self):  # ensure the render window is torn down cleanly
        try:
            self.plotter.close()
        except Exception:
            pass
        super().close()


class MeshViewport(_View):
    """The Boundaries stage's view: a face is picked with the mouse."""

    face_picked = pyqtSignal(int, int)  # (block_idx, face)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.face_actors = {}         # (b, f) -> pyvista actor
        self.face_base_color = {}     # (b, f) -> current fill colour
        self.context_actors = {}      # (b, f) -> actor
        self.block_actors = {}        # b -> [actors...]
        self.block_visible = {}       # b -> bool
        self.block_opacity = {}       # b -> base opacity (1.0 or GHOST_OPACITY)
        self.selected = None          # (b, f)
        self.auto_reveal = True
        self._labels_actor = None
        self._show_labels = True
        self._face_by_addr = {}       # vtk actor address -> (b, f)

    def apply_theme(self, tokens):
        super().apply_theme(tokens)
        # Restyle existing actors: edges of non-selected faces and context planes.
        for key, actor in self.face_actors.items():
            if key != self.selected:
                actor.prop.edge_color = self.theme["edge"]
        if self.selected in self.face_actors:
            self.face_actors[self.selected].prop.edge_color = self.theme["highlight_edge"]
        for actor in self.context_actors.values():
            actor.prop.color = self.theme["context"]
        # Assigned face fills are re-applied by the owner via set_face_color;
        # unassigned faces are refreshed there too.
        self.plotter.render()

    # -- mesh setup ------------------------------------------------------
    def set_mesh(self, blocks):
        self._clear_scene(blocks)
        self.face_actors.clear()
        self.face_base_color.clear()
        self.context_actors.clear()
        self.block_actors.clear()
        self.block_visible.clear()
        self.block_opacity.clear()
        self._face_by_addr.clear()
        self.selected = None
        self._labels_actor = None

        for b, block in enumerate(blocks):
            self.block_actors[b] = []
            self.block_visible[b] = True
            self.block_opacity[b] = 1.0
            for f in facemod.assignable_faces(block):
                mesh = self._face_mesh(block, f)
                actor = self.plotter.add_mesh(
                    mesh, color=self.theme["unassigned"], show_edges=True,
                    edge_color=self.theme["edge"], line_width=1, opacity=1.0,
                    pickable=True, name=f"face_{b}_{f}", reset_camera=False,
                    **MATERIAL,
                )
                self.face_actors[(b, f)] = actor
                self.face_base_color[(b, f)] = self.theme["unassigned"]
                self.block_actors[b].append(actor)
                self._face_by_addr[_addr(actor)] = (b, f)
            for f in facemod.context_faces(block):
                mesh = self._face_mesh(block, f)
                actor = self.plotter.add_mesh(
                    mesh, color=self.theme["context"], opacity=CONTEXT_ALPHA,
                    show_edges=False, pickable=False, name=f"ctx_{b}_{f}",
                    reset_camera=False,
                )
                self.context_actors[(b, f)] = actor
                self.block_actors[b].append(actor)

        self._install_click_observers()
        self.plotter.reset_camera()
        self.view_isometric()

    @staticmethod
    def _face_mesh(block, face):
        xf, yf, zf = facemod.extract_face(block, face)
        if 1 in xf.shape:
            # Degenerate face (2-D block edge): render as a poly-line tube.
            xf = np.squeeze(xf); yf = np.squeeze(yf); zf = np.squeeze(zf)
            pts = np.column_stack([xf.ravel(), yf.ravel(), zf.ravel()])
            n = len(pts)
            lines = np.hstack([[n], np.arange(n)])
            poly = pv.PolyData(pts, lines=lines)
            diag = np.linalg.norm(pts.max(0) - pts.min(0)) or 1.0
            try:
                return poly.tube(radius=diag * 0.004)
            except Exception:
                return poly
        # Regular quad surface -> StructuredGrid with a singleton third dim.
        return pv.StructuredGrid(
            xf[:, :, None].astype(float),
            yf[:, :, None].astype(float),
            zf[:, :, None].astype(float),
        )

    # -- picking ---------------------------------------------------------
    def _picked(self, actor, cell):
        key = self._face_by_addr.get(_addr(actor))
        if key is not None:
            self.select_face(key[0], key[1], emit=True)

    def select_face(self, block_idx, face, emit=False):
        if self.selected is not None:
            self._apply_edge(self.selected, highlighted=False)
        self.selected = (block_idx, face)
        self._apply_edge(self.selected, highlighted=True)
        self._refresh_opacity()
        self.plotter.render()
        if emit:
            self.face_picked.emit(block_idx, face)

    def clear_selection(self):
        if self.selected is not None:
            self._apply_edge(self.selected, highlighted=False)
        self.selected = None
        self._refresh_opacity()
        self.plotter.render()

    def _apply_edge(self, key, highlighted):
        actor = self.face_actors.get(key)
        if actor is None:
            return
        prop = actor.prop
        if highlighted:
            prop.edge_color = self.theme["highlight_edge"]
            prop.line_width = 4
            prop.show_edges = True
        else:
            prop.edge_color = self.theme["edge"]
            prop.line_width = 1
        # Rounded outline for the selection; not every pyvista version has it.
        if hasattr(prop, "render_lines_as_tubes"):
            prop.render_lines_as_tubes = bool(highlighted)

    # -- appearance ------------------------------------------------------
    def set_face_color(self, block_idx, face, color):
        actor = self.face_actors.get((block_idx, face))
        if actor is None:
            return
        actor.prop.color = color
        self.face_base_color[(block_idx, face)] = color
        self.plotter.render()

    def set_block_visible(self, block_idx, visible):
        self.block_visible[block_idx] = visible
        for actor in self.block_actors.get(block_idx, []):
            actor.SetVisibility(bool(visible))
        self.plotter.render()

    def set_block_opacity(self, block_idx, opacity):
        """Set the base (manual) opacity of a whole block."""
        self.block_opacity[block_idx] = float(opacity)
        self._refresh_opacity()
        self.plotter.render()

    def set_block_ghost(self, block_idx, ghost):
        self.set_block_opacity(block_idx, GHOST_OPACITY if ghost else 1.0)

    def set_auto_reveal(self, enabled):
        self.auto_reveal = bool(enabled)
        self._refresh_opacity()
        self.plotter.render()

    def _refresh_opacity(self):
        """Apply per-block base opacity, plus auto-reveal ghosting of the
        geometry occluding the currently selected face."""
        sel = self.selected
        revealing = self.auto_reveal and sel is not None
        for (b, f), actor in self.face_actors.items():
            base = self.block_opacity.get(b, 1.0)
            if (b, f) == sel:
                op = 1.0
            elif revealing:
                op = min(base, REVEAL_OPACITY)
            else:
                op = base
            actor.prop.opacity = op
        for (b, f), actor in self.context_actors.items():
            base = self.block_opacity.get(b, 1.0) * CONTEXT_ALPHA
            actor.prop.opacity = min(base, REVEAL_OPACITY * CONTEXT_ALPHA) if revealing else base

    def update_labels(self, label_map):
        """Draw a text label at the centroid of each assigned face.

        *label_map* maps ``(block_idx, face) -> text``.
        """
        if self._labels_actor is not None:
            try:
                self.plotter.remove_actor(self._labels_actor)
            except Exception:
                pass
            self._labels_actor = None
        if not self._show_labels or not label_map:
            self.plotter.render()
            return
        pts, texts = [], []
        for (b, f), text in label_map.items():
            if not text or not self.block_visible.get(b, True):
                continue
            pts.append(facemod.face_centroid(self.blocks[b], f))
            texts.append(text)
        if pts:
            kwargs = dict(
                font_size=12, text_color=self.theme["label_text"],
                shape="rounded_rect", shape_color=self.theme["label_shape"],
                shape_opacity=0.82, margin=5, bold=False,
                always_visible=True, name="face_labels", reset_camera=False,
            )
            try:
                self._labels_actor = self.plotter.add_point_labels(
                    np.array(pts), texts, **kwargs)
            except TypeError:        # older pyvista without shape/margin kwargs
                for k in ("shape", "margin", "bold"):
                    kwargs.pop(k, None)
                self._labels_actor = self.plotter.add_point_labels(
                    np.array(pts), texts, **kwargs)
        self.plotter.render()

    def set_labels_visible(self, visible, label_map=None):
        self._show_labels = visible
        if label_map is not None:
            self.update_labels(label_map)



class StateViewport(_View):
    """The Initial stage's view: the outer surfaces of every block, each cell
    of a surface in the colour of the cell of the block beneath it.

    The owner gives the colours per block cell (:meth:`set_colors`, the cells
    i fastest, as :class:`icgeom.BlockCells` holds them) and the cells to
    outline (:meth:`set_outline`); a click on a surface emits the block and
    the cell beneath.  A pure 2-D block (one node plane) is drawn as its plane,
    which shows every cell; a 3-D block shows the cells along its six faces.
    """

    cell_picked = pyqtSignal(int, int)   # (block from 0, cell from 0, i fastest)

    PLACEHOLDER = "No mesh loaded\nLoad the mesh to see which state every cell takes"

    def __init__(self, parent=None):
        super().__init__(parent)
        self.surfaces = {}            # b -> [(grid, block cells under it, actor)]
        self.outlines = {}            # b -> actor of the outlined cells
        self.block_opacity = {}       # b -> opacity
        self.edges = False            # the cell edges hide the colours of a fine mesh
        self._surface_by_addr = {}    # vtk actor address -> (b, n)

    @staticmethod
    def _surfaces(block):
        """``[(x, y, z, cells)]``: the node planes drawn for *block*, with the
        cells (flat, i fastest) beneath each of their quads."""
        ni, nj, nk = block.dims
        shape = (ni - 1, nj - 1, max(nk - 1, 1))
        flat = np.arange(shape[0] * shape[1] * shape[2]).reshape(shape, order="F")
        if nk == 1:
            planes = [((slice(None), slice(None), 0), flat[:, :, 0])]
        else:
            planes = [((0, slice(None), slice(None)), flat[0]),
                      ((-1, slice(None), slice(None)), flat[-1]),
                      ((slice(None), 0, slice(None)), flat[:, 0]),
                      ((slice(None), -1, slice(None)), flat[:, -1]),
                      ((slice(None), slice(None), 0), flat[:, :, 0]),
                      ((slice(None), slice(None), -1), flat[:, :, -1])]
        return [(block.xn[nodes], block.yn[nodes], block.zn[nodes], cells.ravel(order="F"))
                for nodes, cells in planes]

    def set_mesh(self, blocks):
        self._clear_scene(blocks)
        self.surfaces.clear()
        self.outlines.clear()
        self.block_opacity.clear()
        self._surface_by_addr.clear()
        for b, block in enumerate(blocks):
            self.surfaces[b] = []
            self.block_opacity[b] = 1.0
            for n, (x, y, z, cells) in enumerate(self._surfaces(block)):
                grid = pv.StructuredGrid(x[:, :, None].astype(float),
                                         y[:, :, None].astype(float),
                                         z[:, :, None].astype(float))
                grid.cell_data["rgb"] = np.full((grid.n_cells, 3), 160, dtype=np.uint8)
                actor = self.plotter.add_mesh(
                    grid, scalars="rgb", rgb=True, show_edges=self.edges,
                    edge_color=self.theme["edge"], line_width=1, pickable=True,
                    name=f"state_{b}_{n}", reset_camera=False, **MATERIAL)
                self.surfaces[b].append((grid, cells, actor))
                self._surface_by_addr[_addr(actor)] = (b, n)
        self._install_click_observers()
        self.plotter.reset_camera()
        # a mesh of 2-D blocks is seen face on
        if blocks and all(block.nk <= 2 for block in blocks):
            self.view_xy()
        else:
            self.view_isometric()

    def apply_theme(self, tokens):
        super().apply_theme(tokens)
        for surfaces in self.surfaces.values():
            for _grid, _cells, actor in surfaces:
                actor.prop.edge_color = self.theme["edge"]
        self.plotter.render()

    def set_colors(self, b, rgb):
        """Paint block *b* (from 0): *rgb* is ``(cells, 3)`` uint8, a row per
        block cell, i fastest."""
        for grid, cells, _actor in self.surfaces.get(b, []):
            grid.cell_data["rgb"] = rgb[cells]
        # the render is left to the caller, once every block is painted

    def set_outline(self, b, cells, color):
        """Outline the block cells *cells* (flat, i fastest) of block *b* in
        *color* where they meet the surface; none when *cells* is empty."""
        actor = self.outlines.pop(b, None)
        if actor is not None:
            self.plotter.remove_actor(actor, render=False)
        if len(cells) == 0:
            return
        ni, nj, nk = self.blocks[b].dims
        marked = np.zeros((ni - 1) * (nj - 1) * max(nk - 1, 1), dtype=bool)
        marked[cells] = True
        pieces = []
        for grid, under, _actor in self.surfaces.get(b, []):
            ids = np.flatnonzero(marked[under])
            if ids.size:
                pieces.append(grid.extract_cells(ids))
        if not pieces:
            return
        merged = pieces[0].merge(pieces[1:]) if len(pieces) > 1 else pieces[0]
        self.outlines[b] = self.plotter.add_mesh(
            merged, style="wireframe", color=color, line_width=2.5, pickable=False,
            name=f"outline_{b}", reset_camera=False, lighting=False,
            opacity=self.block_opacity.get(b, 1.0))

    def set_block_opacity(self, b, opacity):
        """See-through below 1, without its cell edges."""
        self.block_opacity[b] = float(opacity)
        for _grid, _cells, actor in self.surfaces.get(b, []):
            actor.prop.opacity = opacity
            actor.prop.show_edges = self.edges and opacity >= 1.0
        if b in self.outlines:
            self.outlines[b].prop.opacity = opacity

    def set_edges(self, on):
        """Show the cell edges (the mesh lines) of the opaque blocks or not."""
        self.edges = bool(on)
        for b, surfaces in self.surfaces.items():
            for _grid, _cells, actor in surfaces:
                actor.prop.show_edges = self.edges and self.block_opacity.get(b, 1.0) >= 1.0
        self.plotter.render()

    def redraw(self):
        self.plotter.render()

    def _picked(self, actor, cell):
        key = self._surface_by_addr.get(_addr(actor))
        if key is None or cell < 0:
            return
        b, n = key
        _grid, cells, _actor = self.surfaces[b][n]
        if cell < len(cells):
            self.cell_picked.emit(b, int(cells[cell]))


def _addr(actor):
    """Stable identity string for a VTK actor (same C++ object -> same string)."""
    try:
        return actor.GetAddressAsString("vtkProp")
    except Exception:
        return str(id(actor))
