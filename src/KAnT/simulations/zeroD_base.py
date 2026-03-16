"""Shared infrastructure for 0-D batch reactor simulations.

:class:`ZeroDReactorBase` factors out the common loop structure and reactor
setup that is shared between :class:`~kant.simulations.ignition_delay.IgnitionDelay`
and :class:`~kant.simulations.time_evolution.ZeroDTimeEvolution`.
"""

from __future__ import annotations

import re
from abc import abstractmethod

import cantera as ct
import numpy as np

from config.models import ZeroDConfig
from simulations.base import AbstractSimulation
from utils.phase_tools import add_species, setup_mixture
from utils.units import convert2si

_ODE_RTOL = 1.0e-7
_ODE_ATOL = 1.0e-7


class ZeroDReactorBase(AbstractSimulation):
    """Abstract base for 0-D reactor batch simulations.

    Subclasses need only implement :meth:`_collect`, which receives the
    fully-advanced reactor state information and returns whatever scalar/array
    should be stored for a single (temperature, pressure, mixture-ratio) point.
    """

    def __init__(self, config: ZeroDConfig, models: list[str]) -> None:
        super().__init__(config, models)
        self._fuel_dict = self._parse_comp(config.fuel.composition)
        self._oxi_dict = self._parse_comp(config.oxidizer.composition)

    # ------------------------------------------------------------------
    # AbstractSimulation interface
    # ------------------------------------------------------------------

    def run(self):  # returns SimulationResult, typed in subclasses
        raise NotImplementedError(
            "Call run() on a concrete subclass (IgnitionDelay or ZeroDTimeEvolution)."
        )

    # ------------------------------------------------------------------
    # Helpers shared by subclasses
    # ------------------------------------------------------------------

    def _build_gas(self, model: str) -> ct.Solution:
        """Load *model*, add N2 and Ar from nasa9 if absent."""
        gas = ct.Solution(model + ".yaml")
        gas = add_species("N2", gas, "nasa9")
        gas = add_species("Ar", gas, "nasa9")
        return gas

    def _create_reactor(self, gas: ct.Solution) -> tuple[ct.Reactor, ct.ReactorNet]:
        """Instantiate the right reactor + network for the configured type."""
        cfg: ZeroDConfig = self.config
        if cfg.reactor.reactor_type == "HP":
            r = ct.IdealGasConstPressureReactor(contents=gas, name="Batch Reactor")
        else:
            r = ct.IdealGasReactor(contents=gas, name="Batch Reactor")
        net = ct.ReactorNet([r])
        net.rtol = _ODE_RTOL
        net.atol = _ODE_ATOL
        return r, net

    def _iter_conditions(self):
        """Yield ``(temperature, pressure_Pa, mixture_ratio)`` triples."""
        cfg: ZeroDConfig = self.config
        for T in cfg.temperatures:
            for p_bar in cfg.pressures:
                p_Pa = convert2si(p_bar, "bar")
                for mr in cfg.mixture_ratios:
                    yield float(T), float(p_Pa), float(mr)

    @staticmethod
    def _parse_comp(spec: str) -> dict[str, float]:
        """Parse ``'{Species:frac} ...'`` into a dict."""
        return {sp: float(frac) for sp, frac in re.findall(r"{(.*?):(.*?)}", spec)}

    @abstractmethod
    def _run_model(self, model: str) -> list:
        """Run the simulation for one model; return a list of collected values."""
