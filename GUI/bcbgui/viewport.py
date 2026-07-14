"""Interactive PyVista viewport: block toggling, rotate/pan/zoom, face picking.

Every assignable block face is drawn as its own pickable actor so a single left
click selects exactly one face.  The k-planes of 2-D blocks are drawn faintly for
context but are not pickable (BCB assigns them automatically).

Picking uses a depth-correct ``vtkCellPicker`` driven by our own click handler so
the face actually in the foreground under the cursor is selected (rather than an
occluded one), while mouse drags still rotate/pan the camera.
"""

from __future__ import annotations

import numpy as np
import pyvista as pv
import vtk
from pyvistaqt import QtInteractor
from PyQt6.QtWidgets import QWidget, QVBoxLayout
from PyQt6.QtCore import pyqtSignal

from . import faces as facemod

UNASSIGNED_COLOR = "#8a97a5"
HIGHLIGHT_EDGE = "#ffd23f"
CONTEXT_COLOR = "#c9d3dd"

# Opacity used to "ghost" geometry that is not the current selection so a
# covered face can still be seen.
REVEAL_OPACITY = 0.12
CONTEXT_ALPHA = 0.12          # base opacity of the faint k-plane context surfaces
GHOST_OPACITY = 0.16          # per-block manual transparency toggle


class MeshViewport(QWidget):
    """Qt widget wrapping a :class:`pyvistaqt.QtInteractor`."""

    face_picked = pyqtSignal(int, int)  # (block_idx, face)

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.plotter = QtInteractor(self)
        layout.addWidget(self.plotter.interactor)

        self.blocks = []
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

        # Themeable colours (overwritten by apply_theme).
        self.theme = {
            "viewport_bg": "#0e141b", "edge": "#4b5a68",
            "unassigned": UNASSIGNED_COLOR, "context": CONTEXT_COLOR,
            "highlight_edge": HIGHLIGHT_EDGE,
            "label_text": "white", "label_shape": "#1f3550",
        }

        self._picker = vtk.vtkCellPicker()
        self._picker.SetTolerance(0.005)
        self._press_pos = None
        self._observers_set = False

        self.plotter.set_background(self.theme["viewport_bg"])
        self.plotter.add_axes()

    def apply_theme(self, tokens):
        for k in ("viewport_bg", "edge", "unassigned", "context",
                  "highlight_edge", "label_text", "label_shape"):
            if k in tokens:
                self.theme[k] = tokens[k]
        self.plotter.set_background(self.theme["viewport_bg"])
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
        self.plotter.clear()
        self.plotter.add_axes()
        self.face_actors.clear()
        self.face_base_color.clear()
        self.context_actors.clear()
        self.block_actors.clear()
        self.block_visible.clear()
        self.block_opacity.clear()
        self._face_by_addr.clear()
        self.selected = None
        self._labels_actor = None
        self.blocks = blocks

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

    def _face_mesh(self, block, face):
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
        if actor is None:
            return
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
            self._labels_actor = self.plotter.add_point_labels(
                np.array(pts), texts, font_size=12,
                text_color=self.theme["label_text"],
                shape_color=self.theme["label_shape"], shape_opacity=0.65,
                always_visible=True, name="face_labels", reset_camera=False,
            )
        self.plotter.render()

    def set_labels_visible(self, visible, label_map=None):
        self._show_labels = visible
        if label_map is not None:
            self.update_labels(label_map)

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


def _addr(actor):
    """Stable identity string for a VTK actor (same C++ object -> same string)."""
    try:
        return actor.GetAddressAsString("vtkProp")
    except Exception:
        return str(id(actor))
