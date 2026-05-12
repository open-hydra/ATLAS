"""0-D ignition delay simulation."""

from __future__ import annotations

import cantera as ct
import numpy as np

from config.models import SimulationResult, ZeroDConfig
from simulations.zeroD_base import ZeroDReactorBase
from utils.phase_tools import setup_mixture

_IGNITION_DELTA_T = 300.0          # K — temperature rise that defines ignition
_MAX_TIME_STEP = 1.0e-5            # s
_ESTIMATED_IGNITION_TIME = 0.1     # s — integration window


def _ignition_delay(states: ct.SolutionArray, initial_temp: float, delta_temp: float = _IGNITION_DELTA_T) -> float:
    """Return the first time *states.T* exceeds *initial_temp* + *delta_temp*.

    Returns ``np.nan`` if ignition was not observed within the stored states.
    """
    target = initial_temp + delta_temp
    for i, T in enumerate(states.T):
        if T >= target:
            return states.t[i]
    return np.nan


class IgnitionDelay(ZeroDReactorBase):
    """Compute ignition delay times for a batch of initial conditions."""

    def run(self) -> SimulationResult:
        cfg: ZeroDConfig = self.config
        ignition_times: dict[str, list[float]] = {}

        for model in self.models:
            print("  -- Processing:", model)
            ignition_times[model] = self._run_model(model)

        labels = {m: ct.Solution(m + ".yaml").name for m in self.models}

        # Choose independent axis.
        if len(cfg.temperatures) > 1:
            x = cfg.temperatures
            x_label = "Initial Temperature, K"
        elif len(cfg.pressures) > 1:
            x = cfg.pressures
            x_label = "Chamber Pressure, bar"
        else:
            x = cfg.mixture_ratios
            x_label = "Mixture Ratio"

        return SimulationResult(
            x=x,
            y=ignition_times,
            x_label=x_label,
            y_label="Ignition Delay, s",
            model_labels=labels,
        )

    def _run_model(self, model: str) -> list[float]:
        gas = self._build_gas(model)
        results: list[float] = []

        for T, p_Pa, mr in self._iter_conditions():
            setup_mixture(gas, self._fuel_dict, self._oxi_dict, mr)
            gas.TP = T, p_Pa

            r, net = self._create_reactor(gas)
            net.max_time_step = _MAX_TIME_STEP

            time_history = ct.SolutionArray(gas, extra="t")
            initial_temp = gas.T
            t = 0.0
            counter = 1
            while t < _ESTIMATED_IGNITION_TIME:
                t = net.step()
                if not counter % 10:
                    time_history.append(r.thermo.state, t=t)
                counter += 1

            try:
                tau = _ignition_delay(time_history, initial_temp)
                results.append(tau)
            except Exception:
                results.append(np.nan)

        return results
