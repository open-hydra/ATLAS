"""Parse INI configuration files and return typed config objects.

The INI format and all section/key names are identical to the original
KAnT configuration so existing input files continue to work unchanged.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PiNeR import check_section, get

from config.models import (
    FlameConfig,
    ReactorConfig,
    SimulationResult,
    SpeciesSpec,
    ZeroDConfig,
)
from utils.reference import load_case_params

_SECTIONS = ["KAnT-Simulation0D", "KAnT-Simulation1D"]


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------


def list_analyses(ini_file: Path) -> list[str]:
    """Return the ordered list of simulation section names found in *ini_file*."""
    return [s for s in _SECTIONS if check_section(ini_file, s)]


def parse_reactions(ini_file: Path, section: str) -> tuple[list[str], str | None]:
    """Return ``(mechanism_names, thermo_model)`` for *section*.

    The returned thermo_model string is ``None`` when the key is absent from
    the INI file, meaning no thermo override is applied.
    """
    raw = get(ini_file, section, "reactions", str)
    if raw is not None:
        mechanisms = raw.split()
        mechanisms = [
            m + "-ct" if "JLR" in m else m for m in mechanisms
        ]
    else:
        mechanisms = ["FFCM2"]

    thermo_model: str | None = get(ini_file, section, "thermo", str)
    return mechanisms, thermo_model


def parse_0D(ini_file: Path, section: str) -> ZeroDConfig:
    """Parse a ``[KAnT-Simulation0D]`` section and return a :class:`ZeroDConfig`."""
    reactor_type: str = get(ini_file, section, "type", str) or "HP"
    reactor = ReactorConfig(
        reactor_type=reactor_type,
        do_equilibrium=bool(get(ini_file, section, "equilibrium", bool)),
        do_ignition_delay=bool(get(ini_file, section, "ignition-delay", bool)),
        do_time_evolution=bool(get(ini_file, section, "time-evolution", bool)),
    )

    # ---------- shortcut case mode ----------
    case_name: str | None = get(ini_file, section, "case", str)
    if case_name is not None:
        params = load_case_params(case_name)
        fuel = SpeciesSpec(
            temperature=float(params["temperature"][0]),
            composition=params["fuel"],
        )
        oxi = SpeciesSpec(
            temperature=float(params["temperature"][0]),
            composition=params["oxidizer"],
        )
        pressures = np.array(params["pressure"], dtype=float)
        mixture_ratios = np.array(params["of"], dtype=float)
        temperatures = np.array(params["temperature"], dtype=float)
        tend, nstep = _parse_time(ini_file, section)
        return ZeroDConfig(
            reactor=reactor,
            fuel=fuel,
            oxidizer=oxi,
            pressures=pressures,
            mixture_ratios=mixture_ratios,
            temperatures=temperatures,
            tend=tend,
            nstep=nstep,
            case=case_name,
        )

    # ---------- explicit parameters ----------
    of = _parse_sweep(ini_file, section, "of", "of-linear", "of-exp")
    pressures = _parse_sweep(ini_file, section, "pressure", "pressure-linear", "pressure-exp")
    temperatures = _parse_sweep(ini_file, section, "temperature", "temperature-linear", "temperature-exp")

    fuel_entry = get(ini_file, section, "fuel", str)
    if "{" not in fuel_entry:
        fuel_entry = "{" + fuel_entry + ":1.0}"

    oxi_entry = get(ini_file, section, "oxidizer", str)
    if "{" not in oxi_entry:
        oxi_entry = "{" + oxi_entry + ":1.0}"

    Tf: float = get(ini_file, section, "fuel-T", float) or 100.0
    To: float = get(ini_file, section, "oxidizer-T", float) or 90.170

    tend, nstep = _parse_time(ini_file, section)

    return ZeroDConfig(
        reactor=reactor,
        fuel=SpeciesSpec(temperature=Tf, composition=fuel_entry),
        oxidizer=SpeciesSpec(temperature=To, composition=oxi_entry),
        pressures=pressures,
        mixture_ratios=of,
        temperatures=temperatures,
        tend=tend,
        nstep=nstep,
        case=None,
    )


def parse_1D(ini_file: Path, section: str) -> FlameConfig:
    """Parse a ``[KAnT-Simulation1D]`` section and return a :class:`FlameConfig`."""
    of_arr = _parse_sweep(ini_file, section, "of", "of-linear", None)
    of = float(of_arr[0]) if of_arr is not None else 1.0

    pressure_arr = get(ini_file, section, "pressure", np.ndarray)
    pressure = float(pressure_arr[0]) if pressure_arr is not None else 1.0

    fuel_entry = get(ini_file, section, "fuel", str)
    if "{" not in fuel_entry:
        fuel_entry = "{" + fuel_entry + ":1.0}"

    oxi_entry = get(ini_file, section, "oxidizer", str)
    if "{" not in oxi_entry:
        oxi_entry = "{" + oxi_entry + ":1.0}"

    Tf: float = get(ini_file, section, "fuel-T", float) or 1.0
    To: float = get(ini_file, section, "oxidizer-T", float) or 1.0

    mdot: float = get(ini_file, section, "mdot", float) or 1.0
    width: float = get(ini_file, section, "width", float) or 0.2

    return FlameConfig(
        fuel=SpeciesSpec(temperature=Tf, composition=fuel_entry),
        oxidizer=SpeciesSpec(temperature=To, composition=oxi_entry),
        pressure=pressure,
        of=of,
        mdot=mdot,
        width=width,
    )


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _parse_sweep(
    ini_file: Path,
    section: str,
    key: str,
    key_linear: str,
    key_exp: str | None,
) -> np.ndarray:
    """Read a scalar list, linear, or exponential sweep from the INI file."""
    values = get(ini_file, section, key, np.ndarray)
    if values is not None:
        return np.atleast_1d(values).astype(float)

    law = get(ini_file, section, key_linear, np.ndarray)
    if law is not None:
        return np.linspace(law[0], law[1], int(law[2]))

    if key_exp is not None:
        law = get(ini_file, section, key_exp, np.ndarray)
        if law is not None:
            return np.logspace(np.log10(law[0]), np.log10(law[1]), int(law[2]))

    return np.array([])


def _parse_time(ini_file: Path, section: str) -> tuple[float, int]:
    nstep: int = get(ini_file, section, "nstep", int) or 1000
    tend: float = get(ini_file, section, "tend", float) or 1.0
    return tend, nstep
