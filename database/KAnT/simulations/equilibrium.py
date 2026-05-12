"""Steady-state adiabatic-flame-temperature equilibrium simulation."""

from __future__ import annotations

import re

import cantera as ct
import numpy as np

from config.models import SimulationResult, ZeroDConfig
from simulations.base import AbstractSimulation
from utils.phase_tools import extract, update_thermo_model
from utils.units import convert2si


class Equilibrium(AbstractSimulation):
    """Compute adiabatic flame temperatures at chemical equilibrium.

    Wraps the original ``equilibrium.run_all`` / ``equilibrium.single_case``
    logic in an :class:`~kant.simulations.base.AbstractSimulation` subclass.
    """

    def __init__(self, config: ZeroDConfig, models: list[str], thermo_model: str | None = None) -> None:
        super().__init__(config, models)
        self._thermo_model = thermo_model

    # ------------------------------------------------------------------
    # AbstractSimulation.run
    # ------------------------------------------------------------------

    def run(self) -> SimulationResult:
        cfg: ZeroDConfig = self.config
        solutions: dict[str, list[ct.Solution]] = {}

        for model in self.models:
            print("  -- Processing:", model)
            solutions[model] = []
            for of in cfg.mixture_ratios:
                for p in cfg.pressures:
                    sol = self._single_case(model + ".yaml", cfg.reactor.reactor_type,
                                            cfg.fuel, cfg.oxidizer, float(p), float(of))
                    solutions[model].append(sol)

        Ta = extract(self.models, solutions)

        # Build model labels from mechanism names.
        labels = {m: ct.Solution(m + ".yaml").name for m in self.models}

        # Choose the independent axis: OF sweep or pressure sweep.
        if len(cfg.mixture_ratios) > 1 and len(cfg.pressures) == 1:
            x = cfg.mixture_ratios
            x_label = "Mixture Ratio"
        elif len(cfg.pressures) > 1 and len(cfg.mixture_ratios) == 1:
            x = cfg.pressures
            x_label = "Chamber Pressure, bar"
        else:
            x = cfg.mixture_ratios
            x_label = "Mixture Ratio"

        return SimulationResult(
            x=x,
            y=Ta,
            x_label=x_label,
            y_label="Adiabatic Flame Temperature, K",
            model_labels=labels,
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _single_case(
        self,
        model_yaml: str,
        reactor_type: str,
        fuel_spec,
        oxi_spec,
        pressure: float,
        of: float,
    ) -> ct.Solution:
        temperature_f = convert2si(fuel_spec.temperature, "K")
        temperature_o = convert2si(oxi_spec.temperature, "K")
        pressure_chamber = convert2si(pressure, "bar")

        # Fuel phase --- handle liquid reactants.
        liquid_fuel_names = ["H2(L)", "CH4(L)"]
        liquid_fuel_found = False
        for name in liquid_fuel_names:
            if name in fuel_spec.composition:
                liquid_fuel_found = True
                species_list = ct.Species.list_from_file("nasa9.yaml")
                species = next(s for s in species_list if s.name == name)
                fuel = ct.Solution(thermo="ideal-gas", species=[species])
                fuel.TP = temperature_f, pressure_chamber
        if not liquid_fuel_found:
            fuel_comp = {sp: float(frac) for sp, frac in re.findall(r"{(.*?):(.*?)}", fuel_spec.composition)}
            fuel = update_thermo_model(model_yaml, self._thermo_model)
            fuel.TPY = temperature_f, pressure_chamber, fuel_comp

        # Oxidiser phase --- handle liquid reactants.
        liquid_oxi_names = ["O2(L)"]
        liquid_oxi_found = False
        for name in liquid_oxi_names:
            if name in oxi_spec.composition:
                liquid_oxi_found = True
                species_list = ct.Species.list_from_file("nasa9.yaml")
                species = next(s for s in species_list if s.name == name)
                oxi = ct.Solution(thermo="ideal-gas", species=[species])
                oxi.TP = temperature_o, pressure_chamber
        if not liquid_oxi_found:
            oxi_comp = {sp: float(frac) for sp, frac in re.findall(r"{(.*?):(.*?)}", oxi_spec.composition)}
            oxi = update_thermo_model(model_yaml, self._thermo_model)
            oxi.TPY = temperature_o, pressure_chamber, oxi_comp

        molar_ratio = of / (oxi.mean_molecular_weight / fuel.mean_molecular_weight)
        moles_oxi = molar_ratio / (1 + molar_ratio)
        moles_fuel = 1 - moles_oxi

        products = update_thermo_model(model_yaml, self._thermo_model)
        mix = ct.Mixture([(fuel, moles_fuel), (oxi, moles_oxi), (products, 0)])
        mix.equilibrate(reactor_type, solver="vcs")

        return products
