"""Matplotlib-based plotting for KAnT simulation results."""

from __future__ import annotations

import random

import matplotlib.pyplot as plt
import numpy as np

from config.models import SimulationResult
from utils.reference import load_case_data

_LINE_STYLES = ["-", "--", "-.", ":"]
_MARKERS = ["o", "s", "d", "^", "v", ">", "<", "p", "*"]


def _random_style() -> dict:
    return {
        "linestyle": random.choice(_LINE_STYLES),
        "marker": random.choice(_MARKERS),
        "markersize": 6,
    }


class Plotter:
    """Produce 1-D line plots and 3-D surface plots from simulation results."""

    def plot_1D(self, result: SimulationResult, logy: bool = False) -> None:
        """Plot *result* as a 2-D line chart (one line per model).

        Parameters
        ----------
        result : SimulationResult
        logy : bool
            If ``True`` the y axis uses a logarithmic scale.
        """
        for model, y_vals in result.y.items():
            style = _random_style()
            xx = result.x if isinstance(result.x, np.ndarray) else result.x[model]
            label = result.model_labels.get(model, model)
            plt.plot(
                xx,
                y_vals,
                label=label,
                linestyle=style["linestyle"],
                marker=style["marker"],
                markersize=style["markersize"],
            )
        plt.xlabel(result.x_label)
        plt.ylabel(result.y_label)
        plt.legend(loc="upper left", bbox_to_anchor=(1, 1))
        plt.tight_layout()
        if logy:
            plt.yscale("log")

    def plot_2D(self, result: SimulationResult, mixture_ratio, pressure) -> None:
        """Plot *result* as a 3-D surface (adiabatic temperature over OF × P).

        Parameters
        ----------
        result : SimulationResult
        mixture_ratio : array-like
            Mixture ratios (x axis of the surface).
        pressure : array-like
            Pressures (y axis of the surface).
        """
        from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 (side-effect import)

        mr_arr = np.asarray(mixture_ratio)
        p_arr = np.asarray(pressure)
        X, Y = np.meshgrid(mr_arr, p_arr)

        fig = plt.figure()
        ax = fig.add_subplot(111, projection="3d")

        for model, temps in result.y.items():
            Tad = np.array(temps).reshape(len(mixture_ratio), len(pressure))
            ax.plot_surface(X, Y, Tad.T, alpha=0.6)

        ax.set_xlabel("Mixture Ratio")
        ax.set_ylabel("Pressure (Pa)")
        ax.set_zlabel(result.y_label)

        handles = [
            plt.Line2D([0], [0], color=plt.cm.viridis(i / max(len(result.y), 1)), lw=4)
            for i in range(len(result.y))
        ]
        ax.legend(handles, [result.model_labels.get(m, m) for m in result.y], loc="upper left")

    def overlay_reference(self, case_name: str) -> None:
        """Overlay experimental reference data as an error-bar series.

        Parameters
        ----------
        case_name : str
            A case name recognised by :func:`~kant.utils.reference.load_case_data`
            (e.g. ``'pierro'``, ``'huang-40-stoich'``).
        """
        data = load_case_data(case_name)
        y = data["y"]
        lower_err = y - data["y_lower"]
        upper_err = data["y_upper"] - y
        # Load label from cases.yaml via load_case_params.
        try:
            from utils.reference import load_case_params
            label = load_case_params(case_name)["label"]
        except Exception:
            label = case_name
        plt.errorbar(
            data["x"], y,
            yerr=[lower_err, upper_err],
            fmt="o", capsize=5, color="k",
            label=label,
        )
