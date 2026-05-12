"""0-D time-accurate reactor evolution simulation."""

from __future__ import annotations

import cantera as ct
import numpy as np

from config.models import SimulationResult, ZeroDConfig
from simulations.zeroD_base import ZeroDReactorBase
from utils.phase_tools import setup_mixture


class ZeroDTimeEvolution(ZeroDReactorBase):
    """Integrate the 0-D reactor in time and record T vs. t."""

    def run(self) -> SimulationResult:
        cfg: ZeroDConfig = self.config
        Tout: dict[str, list[float]] = {}
        # All models share the same time grid (single condition assumed).
        time_array: np.ndarray | None = None

        for model in self.models:
            print("  -- Processing:", model)
            t_arr, T_arr = self._run_model(model)
            Tout[model] = T_arr
            if time_array is None:
                time_array = t_arr

        labels = {m: ct.Solution(m + ".yaml").name for m in self.models}

        return SimulationResult(
            x=time_array if time_array is not None else np.array([]),
            y=Tout,
            x_label="Time, s",
            y_label="Temperature, K",
            model_labels=labels,
        )

    def _run_model(self, model: str) -> tuple[np.ndarray, list[float]]:
        cfg: ZeroDConfig = self.config
        gas = self._build_gas(model)
        T_vals: list[float] = []
        tout: list[float] = []

        for T, p_Pa, mr in self._iter_conditions():
            setup_mixture(gas, self._fuel_dict, self._oxi_dict, mr)
            gas.TP = T, p_Pa

            r, net = self._create_reactor(gas)

            time = 0.0
            tout.append(time)
            T_vals.append(r.thermo.T)

            for _ in range(cfg.nstep):
                time += cfg.tend / cfg.nstep
                net.advance(time)
                tout.append(time)
                T_vals.append(r.thermo.T)

        return np.array(tout), T_vals
