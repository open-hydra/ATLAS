"""Tecplot ASCII output writer."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from config.models import SimulationResult

_DEFAULT_OUTPUT = Path("KAnT-out.dat")


class TecplotWriter:
    """Write a :class:`~kant.config.models.SimulationResult` to a Tecplot ASCII file.

    One ZONE block is written per model.
    """

    def write(self, result: SimulationResult, path: Path = _DEFAULT_OUTPUT) -> None:
        """Write *result* to *path* (default ``KAnT-out.dat``).

        Parameters
        ----------
        result : SimulationResult
        path : Path, optional
            Output file path.
        """
        with open(path, "w") as fh:
            fh.write('TITLE = "KAnT Output"\n')
            fh.write(f'VARIABLES = "{result.x_label}""{result.y_label}"\n')

            for model, y_vals in result.y.items():
                # Per-model or shared x axis.
                if isinstance(result.x, np.ndarray):
                    xx = result.x
                else:
                    xx = result.x[model]

                label = result.model_labels.get(model, model)
                fh.write(f"ZONE T={label}\n")
                fh.write(f"I={len(xx)}, F=POINT\n")
                for xi, yi in zip(xx, y_vals):
                    fh.write(f"{xi:<12}  {yi:.20E}\n")
