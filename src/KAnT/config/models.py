"""Typed dataclasses that represent KAnT configuration and simulation results."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np


@dataclass
class ReactorConfig:
    """Top-level options shared by all simulation types in one INI section."""

    reactor_type: str           # e.g. 'HP', 'LP', 'UV'
    do_equilibrium: bool
    do_ignition_delay: bool
    do_time_evolution: bool


@dataclass
class SpeciesSpec:
    """A stream (fuel or oxidizer) with temperature and composition.

    *composition* uses the ``{Species:fraction}`` format understood by the
    Cantera helpers (e.g. ``'{CH4:1.0}'`` or ``'{O2:0.21} {N2:0.79}'``).
    """

    temperature: float          # Kelvin
    composition: str            # '{Species:fraction} ...' string


@dataclass
class ZeroDConfig:
    """Parameters for a 0-D kinetics run (equilibrium / ignition / time-evo)."""

    reactor: ReactorConfig
    fuel: SpeciesSpec
    oxidizer: SpeciesSpec
    pressures: np.ndarray       # bar
    mixture_ratios: np.ndarray  # O/F
    temperatures: np.ndarray    # K
    # For ignition-delay and time-evolution only:
    tend: float = 1.0           # end time, s
    nstep: int = 1000           # number of output steps
    # Shortcut case name (or None if not used)
    case: str | None = None


@dataclass
class FlameConfig:
    """Parameters for a 1-D counterflow diffusion flame."""

    fuel: SpeciesSpec
    oxidizer: SpeciesSpec
    pressure: float             # bar
    of: float                   # O/F ratio
    mdot: float = 1.0           # total mass-flux, kg/m²/s
    width: float = 0.2          # domain width, m


@dataclass
class SimulationResult:
    """Unified result container returned by every simulation class.

    *x* is either a common numpy array (same for all models) or a dict
    mapping model name → numpy array (per-model, e.g. flame grids).

    *y* maps model name → list/array of output values.
    """

    x: np.ndarray | dict[str, Any]
    y: dict[str, Any]
    x_label: str
    y_label: str
    # Human-readable label per model   (model_name → label string)
    model_labels: dict[str, str] = field(default_factory=dict)
