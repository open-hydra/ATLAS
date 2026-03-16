"""Utilities for loading predefined validation cases and their reference data."""

from __future__ import annotations

import csv
import importlib.resources as pkg_resources
from pathlib import Path
from typing import Any

import numpy as np
import yaml


def _data_dir() -> Path:
    """Return the path to kant/data/reference/."""
    # Works both from an editable source install and from a regular install.
    try:
        ref = pkg_resources.files("data.reference")  # type: ignore[attr-defined]
        return Path(str(ref))
    except Exception:
        return Path(__file__).parent.parent / "data" / "reference"


def load_case_params(name: str) -> dict[str, Any]:
    """Return the simulation parameters for a predefined validation case.

    Parameters
    ----------
    name : str
        Case identifier, e.g. ``'pierro'`` or ``'huang-40-stoich'``.

    Returns
    -------
    dict with keys: ``fuel``, ``oxidizer``, ``pressure``, ``of``,
    ``temperature`` (numpy array), ``label``.

    Raises
    ------
    KeyError
        If *name* is not found in ``cases.yaml``.
    """
    cases_file = _data_dir() / "cases.yaml"
    with open(cases_file, "r") as fh:
        all_cases: dict = yaml.safe_load(fh)

    if name not in all_cases:
        raise KeyError(
            f"Unknown reference case '{name}'. "
            f"Available: {sorted(all_cases.keys())}"
        )

    entry = all_cases[name]

    # Resolve temperature array from linear spec or explicit list.
    if "temperature_linear" in entry:
        lo, hi, n = entry["temperature_linear"]
        T = np.linspace(lo, hi, int(n))
    else:
        T = np.array(entry["temperature"])

    return {
        "fuel": entry["fuel"],
        "oxidizer": entry["oxidizer"],
        "pressure": list(entry["pressure"]),
        "of": list(entry["of"]),
        "temperature": T,
        "label": entry.get("label", name),
    }


def load_case_data(name: str) -> dict[str, np.ndarray]:
    """Return the experimental reference data for a predefined validation case.

    Parameters
    ----------
    name : str
        Case identifier, e.g. ``'pierro'``.

    Returns
    -------
    dict with keys: ``x``, ``y``, ``y_lower``, ``y_upper`` (all numpy arrays).
    """
    csv_path = _data_dir() / f"{name}.csv"
    if not csv_path.is_file():
        raise FileNotFoundError(f"No reference data file found for case '{name}'.")

    x_vals, y_vals, y_lower, y_upper = [], [], [], []
    with open(csv_path, newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            x_vals.append(float(row["x"]))
            y_vals.append(float(row["y"]))
            y_lower.append(float(row["y_lower"]))
            y_upper.append(float(row["y_upper"]))

    y = np.array(y_vals)
    return {
        "x": np.array(x_vals),
        "y": y,
        "y_lower": np.array(y_lower),
        "y_upper": np.array(y_upper),
    }
