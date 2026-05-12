"""1-D counterflow diffusion flame simulation."""

from __future__ import annotations

import re

import cantera as ct
import numpy as np

from config.models import FlameConfig, SimulationResult
from simulations.base import AbstractSimulation
from utils.units import convert2si


class CounterflowFlame(AbstractSimulation):
    """Solve one or more 1-D counterflow diffusion flames."""

    def run(self) -> SimulationResult:
        cfg: FlameConfig = self.config
        x_dict: dict[str, np.ndarray] = {}
        T_dict: dict[str, np.ndarray] = {}

        for model in self.models:
            print("  -- Processing:", model)
            x_grid, T_profile = self._single_flame(model)
            x_dict[model] = x_grid
            T_dict[model] = T_profile

        labels = {m: ct.Solution(m + ".yaml").name for m in self.models}

        return SimulationResult(
            x=x_dict,
            y=T_dict,
            x_label="x",
            y_label="Temperature, K",
            model_labels=labels,
        )

    def _single_flame(self, model: str) -> tuple[np.ndarray, np.ndarray]:
        cfg: FlameConfig = self.config
        tin_f = convert2si(cfg.fuel.temperature, "K")
        tin_o = convert2si(cfg.oxidizer.temperature, "K")
        p = convert2si(cfg.pressure, "bar")

        fuel_dict = {sp: float(frac) for sp, frac in re.findall(r"{(.*?):(.*?)}", cfg.fuel.composition)}
        oxi_dict = {sp: float(frac) for sp, frac in re.findall(r"{(.*?):(.*?)}", cfg.oxidizer.composition)}

        mdot_o = cfg.mdot * cfg.of / (1 + cfg.of)
        mdot_f = cfg.mdot - mdot_o

        gas = ct.Solution(model + ".yaml")
        gas.TP = 300.0, p

        f = ct.CounterflowDiffusionFlame(gas, width=cfg.width)

        f.fuel_inlet.mdot = mdot_f
        f.fuel_inlet.Y = fuel_dict
        f.fuel_inlet.T = tin_f

        f.oxidizer_inlet.mdot = mdot_o
        f.oxidizer_inlet.Y = oxi_dict
        f.oxidizer_inlet.T = tin_o

        f.boundary_emissivities = 0.0, 0.0
        f.radiation_enabled = True
        f.set_refine_criteria(ratio=2, slope=0.2, curve=0.3, prune=0.04)

        f.solve(loglevel=0, auto=True)

        return f.flame.grid, f.T
