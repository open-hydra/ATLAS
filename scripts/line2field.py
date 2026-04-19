from __future__ import annotations

import argparse
import math
import re
import sys
from contextlib import redirect_stdout
from dataclasses import dataclass
from importlib import import_module
from io import StringIO
from pathlib import Path
from typing import Iterable

import numpy as np


TWOPI = 2.0 * math.pi
EPS = 1.0e-12


def _ensure_orion_import() -> None:
    try:
        import_module("ORION.ORION")
        return
    except ModuleNotFoundError:
        pass

    here = Path(__file__).resolve()
    candidates = [
        here.parents[3] / "lib" / "ORION" / "src" / "python",
        here.parents[4] / "ORION" / "src" / "python",
    ]
    for candidate in candidates:
        if candidate.is_dir():
            sys.path.insert(0, str(candidate))
            try:
                import_module("ORION.ORION")
                return
            except ModuleNotFoundError:
                continue

    raise ModuleNotFoundError(
        "Could not import ORION Python package. Checked local ATLAS vendored ORION and sibling ORION repository."
    )


_ensure_orion_import()

read_TEC = import_module("ORION.ORION").read_TEC


@dataclass
class Q2DStrip:
    theta: np.ndarray
    vars: np.ndarray
    varnames: list[str]
    circ_idx: int

    @property
    def npts(self) -> int:
        return int(self.theta.shape[0])

    @property
    def nvar(self) -> int:
        return len(self.varnames)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="line2field",
        description="Maps 1D line probe data onto a 2D cylindrical face.",
    )
    parser.add_argument("--meshfile", default="mesh.tec", help="target mesh Tecplot file.")
    parser.add_argument("--inpfile", required=True, help="Input line probe Tecplot file.")
    parser.add_argument("--outfile", default="2d.tec", help="Output Tecplot file.")
    parser.add_argument(
        "--center",
        required=True,
        nargs=3,
        type=float,
        metavar=("X", "Y", "Z"),
        help="Cylinder center coordinates.",
    )
    parser.add_argument("--face", type=int, default=5, help="ATLAS face index (1-6).")
    parser.add_argument(
        "--strip-j-face",
        dest="strip_j_face",
        type=int,
        default=1,
        help="Q2D strip J face to use (0 or 1).",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose logging.")
    return parser.parse_args()


def read_orion_tec(path: str):
    suffix = Path(path).suffix.lower()
    if suffix != ".tec":
        raise ValueError(f"Unsupported file format: {path}. Tecplot ASCII .tec files only.")

    try:
        with redirect_stdout(StringIO()):
            return read_TEC(path)
    except FileNotFoundError as exc:
        raise FileNotFoundError(f"Failed to read Tecplot file: {path}") from exc
    except Exception as exc:  # pragma: no cover
        raise RuntimeError(f"Failed to read Tecplot file: {path}") from exc


def run_q2d_bc_map(
    meshfile: str,
    q2dfile: str,
    outfile: str,
    face: int,
    strip_j_face: int,
    cyl_center: Iterable[float],
    *,
    verbose: bool = False,
) -> None:
    center = np.asarray(tuple(cyl_center), dtype=float)
    if center.shape != (3,):
        raise ValueError("Cylinder center must contain exactly three coordinates")

    ax_idx = face_to_axis(face)

    if verbose:
        print(f" [LOG] Reading 3D mesh: {meshfile}")
    mesh_x, mesh_y, mesh_z, _, _ = read_orion_tec(meshfile)

    if verbose:
        print(f" [LOG] Cylinder center: {center[0]:10.4f}{center[1]:10.4f}{center[2]:10.4f}")
        print(f" [LOG] Reading input file: {q2dfile}")
    q2d_x, q2d_y, _, q2d_vars, q2d_varnames = read_orion_tec(q2dfile)
    nzones = len(q2d_x)
    if nzones == 0:
        raise ValueError("Input file has no zones")

    times = read_solution_times(q2dfile, nzones)
    varnames = filter_varnames(q2d_varnames)

    if verbose:
        print(f" [LOG] Zones: {nzones}, Variables: {len(varnames)}")
        print(f" [LOG] Face: {face}, Axis: {ax_idx + 1}")

    zones: list[dict[str, object]] = []
    for zone_idx in range(nzones):
        strip = extract_strip(q2d_x[zone_idx], q2d_y[zone_idx], q2d_vars[zone_idx], varnames, strip_j_face)
        if zone_idx == 0:
            if strip.npts < 2:
                raise ValueError("Q2D strip < 2 points")
            if strip.nvar < 1:
                raise ValueError("Q2D strip has no variables")
            if strip.circ_idx not in (0, 1):
                raise ValueError("circ_idx auto-detect failed")

        for block_idx, (xb, yb, zb) in enumerate(zip(mesh_x, mesh_y, mesh_z), start=1):
            nodes, centers = extract_geometry(xb, yb, zb, face)
            vars_on_face = interpolate_vars(centers, strip, ax_idx, center)
            zones.append(
                {
                    "title": f"B{block_idx}_T{zone_idx + 1}",
                    "time": times[zone_idx],
                    "nodes": nodes,
                    "vars": vars_on_face,
                }
            )

    write_tecplot(outfile, varnames, zones)
    if verbose:
        print(f" [LOG] Output: {outfile}")


def extract_strip(
    x_nodes: np.ndarray,
    y_nodes: np.ndarray,
    zone_vars: list[np.ndarray],
    varnames: list[str],
    j_face: int,
) -> Q2DStrip:
    if j_face < 0 or j_face >= x_nodes.shape[1]:
        raise ValueError("strip-j-face is outside the Q2D strip node range")

    npts = zone_vars[0].shape[0] if zone_vars else x_nodes.shape[0] - 1
    if npts < 1:
        raise ValueError("Q2D strip has no cells")

    range_x = float(np.max(x_nodes[:, j_face, 0]) - np.min(x_nodes[:, j_face, 0]))
    range_y = float(np.max(y_nodes[:, j_face, 0]) - np.min(y_nodes[:, j_face, 0]))
    circ_idx = 0 if range_x > range_y else 1
    coord_nodes = x_nodes[:, j_face, 0] if circ_idx == 0 else y_nodes[:, j_face, 0]

    centers = 0.5 * (coord_nodes[:-1] + coord_nodes[1:])
    s_min = float(np.min(centers))
    s_max = float(np.max(centers))
    if s_max - s_min < EPS:
        raise ValueError("Q2D circ range <= 0")
    theta = (centers - s_min) / (s_max - s_min) * TWOPI

    strip_vars = np.zeros((len(varnames), npts), dtype=float)
    nvar_input = len(zone_vars)
    for index in range(min(len(varnames), nvar_input)):
        strip_vars[index, :] = np.asarray(zone_vars[index][:, 0, 0], dtype=float)

    if theta[0] > theta[-1]:
        theta = theta[::-1].copy()
        strip_vars = strip_vars[:, ::-1].copy()

    return Q2DStrip(theta=theta, vars=strip_vars, varnames=list(varnames), circ_idx=circ_idx)


def extract_geometry(
    x_nodes: np.ndarray,
    y_nodes: np.ndarray,
    z_nodes: np.ndarray,
    face: int,
) -> tuple[np.ndarray, np.ndarray]:
    plane_x, plane_y, plane_z = get_face_nodes(x_nodes, y_nodes, z_nodes, face)
    nodes = np.stack((plane_x, plane_y, plane_z), axis=0)
    centers = np.stack(
        (
            cell_centers_from_nodes(plane_x),
            cell_centers_from_nodes(plane_y),
            cell_centers_from_nodes(plane_z),
        ),
        axis=0,
    )
    return nodes, centers


def get_face_nodes(
    x_nodes: np.ndarray,
    y_nodes: np.ndarray,
    z_nodes: np.ndarray,
    face: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if face == 1:
        return x_nodes[0, :, :], y_nodes[0, :, :], z_nodes[0, :, :]
    if face == 2:
        return x_nodes[-1, :, :], y_nodes[-1, :, :], z_nodes[-1, :, :]
    if face == 3:
        return x_nodes[:, 0, :], y_nodes[:, 0, :], z_nodes[:, 0, :]
    if face == 4:
        return x_nodes[:, -1, :], y_nodes[:, -1, :], z_nodes[:, -1, :]
    if face == 5:
        return x_nodes[:, :, 0], y_nodes[:, :, 0], z_nodes[:, :, 0]
    if face == 6:
        return x_nodes[:, :, -1], y_nodes[:, :, -1], z_nodes[:, :, -1]
    raise ValueError("face must be 1-6")


def cell_centers_from_nodes(plane: np.ndarray) -> np.ndarray:
    return 0.25 * (plane[:-1, :-1] + plane[1:, :-1] + plane[:-1, 1:] + plane[1:, 1:])


def interpolate_vars(
    centers: np.ndarray,
    strip: Q2DStrip,
    ax_idx: int,
    center: np.ndarray,
) -> np.ndarray:
    n1, n2 = centers.shape[1], centers.shape[2]
    values = np.zeros((strip.nvar, n1, n2), dtype=float)

    u_idx = find_var(strip.varnames, "u")
    v_idx = find_var(strip.varnames, "v")
    w_idx = find_var(strip.varnames, "w")

    if strip.circ_idx == 0:
        tang_idx, ax_vel_idx = u_idx, v_idx
    else:
        tang_idx, ax_vel_idx = v_idx, u_idx
    has_vel = tang_idx >= 0 or ax_vel_idx >= 0

    if ax_idx == 0:
        p1, p2 = 1, 2
    elif ax_idx == 1:
        p1, p2 = 2, 0
    else:
        p1, p2 = 0, 1

    for i2 in range(n2):
        for i1 in range(n1):
            theta = compute_theta(centers[:, i1, i2], center, ax_idx)
            i0, i1_theta, wt = periodic_search(strip.theta, theta)

            comp = np.zeros(3, dtype=float)
            if has_vel:
                vt = 0.0
                va = 0.0
                if tang_idx >= 0:
                    vt = (1.0 - wt) * strip.vars[tang_idx, i0] + wt * strip.vars[tang_idx, i1_theta]
                if ax_vel_idx >= 0:
                    va = (1.0 - wt) * strip.vars[ax_vel_idx, i0] + wt * strip.vars[ax_vel_idx, i1_theta]
                st = math.sin(theta)
                ct = math.cos(theta)
                comp[ax_idx] = va
                comp[p1] = -vt * st
                comp[p2] = vt * ct

            for var_idx in range(strip.nvar):
                if var_idx in (u_idx, v_idx, w_idx):
                    continue
                values[var_idx, i1, i2] = (1.0 - wt) * strip.vars[var_idx, i0] + wt * strip.vars[var_idx, i1_theta]

            if u_idx >= 0:
                values[u_idx, i1, i2] = comp[0]
            if v_idx >= 0:
                values[v_idx, i1, i2] = comp[1]
            if w_idx >= 0:
                values[w_idx, i1, i2] = comp[2]

    return values


def filter_varnames(input_varnames: Iterable[str]) -> list[str]:
    names = [str(name).strip() for name in input_varnames]
    offset = 0
    lower_names = [name.lower() for name in names]
    if len(names) >= 2 and lower_names[0] == "x" and lower_names[1] == "y":
        offset = 2
        if len(names) >= 3 and lower_names[2] == "z":
            offset = 3

    output = names[offset:]
    if not output:
        raise ValueError("Q2D has no variables")

    has_w = any(name.lower() == "w" for name in output)
    has_vel = any(name.lower() in {"u", "v"} for name in output)
    if has_vel and not has_w:
        output = [*output, "w"]
    return output


def read_solution_times(filename: str, nzones: int) -> np.ndarray:
    times = np.full(nzones, -1.0, dtype=float)
    zone_index = 0
    solutiontime_re = re.compile(r"solutiontime\s*=\s*([-+0-9.eEdD]+)", re.IGNORECASE)

    with open(filename, "r", encoding="utf-8") as handle:
        for line in handle:
            if "zone" not in line.lower():
                continue
            if zone_index >= nzones:
                break
            match = solutiontime_re.search(line)
            if match:
                times[zone_index] = float(match.group(1).replace("D", "E").replace("d", "e"))
            zone_index += 1

    return times


def write_tecplot(outfile: str, varnames: list[str], zones: list[dict[str, object]]) -> None:
    with open(outfile, "w", encoding="utf-8") as handle:
        header = ' VARIABLES ="x" "y" "z"'
        for name in varnames:
            header += f' "{name}"'
        handle.write(header + "\n")

        for zone in zones:
            nodes = zone["nodes"]
            values = zone["vars"]
            title = zone["title"]
            time = float(zone["time"])
            n1 = nodes.shape[1] - 1
            n2 = nodes.shape[2] - 1

            line = f' ZONE T="{title}", I={n1 + 1}, J={n2 + 1}, K=1, DATAPACKING=BLOCK'
            if len(varnames) > 1:
                line += f', VARLOCATION=([1-3]=NODAL,[4-{3 + len(varnames)}]=CELLCENTERED)'
            else:
                line += ', VARLOCATION=([1-3]=NODAL,[4]=CELLCENTERED)'
            if time >= 0.0:
                line += f', SOLUTIONTIME={time:.8E}'
            handle.write(line + "\n")

            for comp in range(3):
                write_block_values(handle, nodes[comp])
            for comp in range(values.shape[0]):
                write_block_values(handle, values[comp])


def write_block_values(handle, array: np.ndarray) -> None:
    flat = np.asarray(array, dtype=float).reshape(-1, order="F")
    for value in flat:
        handle.write(f" {value:.16E}\n")


def compute_theta(xyz: np.ndarray, center: np.ndarray, ax_idx: int) -> float:
    delta = xyz - center
    if ax_idx == 0:
        c1, c2 = delta[1], delta[2]
    elif ax_idx == 1:
        c1, c2 = delta[2], delta[0]
    else:
        c1, c2 = delta[0], delta[1]
    return math.fmod(math.atan2(c2, c1) + TWOPI, TWOPI)


def periodic_search(theta_arr: np.ndarray, theta_tgt: float) -> tuple[int, int, float]:
    npts = theta_arr.shape[0]
    if npts <= 1:
        return 0, 0, 0.0

    idx = int(np.searchsorted(theta_arr, theta_tgt, side="right"))
    if 0 < idx < npts:
        i0 = idx - 1
        i1 = idx
        gap = theta_arr[i1] - theta_arr[i0]
        weight = 0.0 if gap <= EPS else (theta_tgt - theta_arr[i0]) / gap
        return i0, i1, float(weight)

    i0 = npts - 1
    i1 = 0
    gap = (theta_arr[0] + TWOPI) - theta_arr[-1]
    if gap <= EPS:
        return i0, i1, 0.0
    if theta_tgt >= theta_arr[-1]:
        weight = (theta_tgt - theta_arr[-1]) / gap
    else:
        weight = (theta_tgt + TWOPI - theta_arr[-1]) / gap
    return i0, i1, float(min(1.0, max(0.0, weight)))


def face_to_axis(face: int) -> int:
    if face in (1, 2):
        return 0
    if face in (3, 4):
        return 1
    if face in (5, 6):
        return 2
    raise ValueError("face must be 1-6")


def find_var(varnames: Iterable[str], name: str) -> int:
    needle = name.strip().lower()
    for index, candidate in enumerate(varnames):
        if str(candidate).strip().lower() == needle:
            return index
    return -1


def main() -> int:
    args = parse_args()

    if args.face < 1 or args.face > 6:
        raise ValueError("face must be 1-6")
    if args.strip_j_face < 0 or args.strip_j_face > 1:
        raise ValueError("strip-j-face must be 0 or 1")

    print("==============================================")
    print(" ATLAS - Q2D to 3D Boundary Mapper")
    print("==============================================")

    if args.verbose:
        print(f"[CONFIG] meshfile    = {Path(args.meshfile).resolve()}")
        print(f"[CONFIG] q2dfile     = {Path(args.q2dfile).resolve()}")
        print(f"[CONFIG] outfile     = {Path(args.outfile).resolve()}")
        print(f"[CONFIG] center      = {args.center[0]:14.6E}{args.center[1]:14.6E}{args.center[2]:14.6E}")
        print(f"[CONFIG] face        = {args.face}")
        print(f"[CONFIG] strip-j-face= {args.strip_j_face}")
        print()

    run_q2d_bc_map(
        meshfile=str(Path(args.meshfile).resolve()),
        q2dfile=str(Path(args.q2dfile).resolve()),
        outfile=str(Path(args.outfile).resolve()),
        face=args.face,
        strip_j_face=args.strip_j_face,
        cyl_center=args.center,
        verbose=args.verbose,
    )

    print("[DONE] Mapping completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())