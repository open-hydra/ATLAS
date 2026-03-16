"""KAnT package entry point.

Invoked as:
    python3 -B <path>/KAnT [--plot] [<ini-file>]
or via ``python3 -m kant``.

All simulation dispatch logic lives here.
"""

from __future__ import annotations

import sys
from pathlib import Path

import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Ensure the KAnT flat-module directory is importable when running directly
# from source (e.g. python3 -B $ATLASDIR/src/KAnT).
# ---------------------------------------------------------------------------
_here = Path(__file__).parent
if str(_here) not in sys.path:
    sys.path.insert(0, str(_here))

from config.models import FlameConfig, ZeroDConfig
from config.parser import list_analyses, parse_0D, parse_1D, parse_reactions
from output.plot import Plotter
from output.tecplot import TecplotWriter
from simulations.counterflow_flame import CounterflowFlame
from simulations.equilibrium import Equilibrium
from simulations.ignition_delay import IgnitionDelay
from simulations.time_evolution import ZeroDTimeEvolution

# Map analysis-type string → simulation class.
_SIM_REGISTRY = {
    "eq": Equilibrium,
    "id": IgnitionDelay,
    "te": ZeroDTimeEvolution,
    "1D": CounterflowFlame,
}


def main(argv: list[str] | None = None) -> None:
    if argv is None:
        argv = sys.argv[1:]

    plot_requested = "--plot" in argv

    # Locate INI file.
    ini_file = Path("kant.ini")
    if not ini_file.is_file():
        ini_file = Path("input.ini")
        if not ini_file.is_file():
            sys.exit("Missing input file (kant.ini / input.ini)")

    print()
    print(" ATLAS - Kinetic Analyzer and Tester")
    print()

    writer = TecplotWriter()
    plotter = Plotter()

    for section in list_analyses(ini_file):

        # ------------------------------------------------------------------ 0D
        if "0D" in section:
            print(" - 0D simulation")
            print()

            cfg: ZeroDConfig = parse_0D(ini_file, section)
            models, thermo_model = parse_reactions(ini_file, section)

            # ---- equilibrium ---------------------------------------------------
            if cfg.reactor.do_equilibrium:
                print(" - Steady-state equilibrium @", cfg.reactor.reactor_type)
                result = Equilibrium(cfg, models, thermo_model).run()

                if len(cfg.mixture_ratios) == 1 and len(cfg.pressures) == 1:
                    print()
                    print(" - Output: Adiabatic Flame Temperature")
                    for m in models:
                        print(" --", m, "->", result.y[m], "K")
                else:
                    writer.write(result)

                if plot_requested:
                    if len(cfg.mixture_ratios) > 1 and len(cfg.pressures) == 1:
                        plotter.plot_1D(result, logy=False)
                    elif len(cfg.pressures) > 1 and len(cfg.mixture_ratios) == 1:
                        plotter.plot_1D(result, logy=False)
                    elif len(cfg.pressures) > 1 and len(cfg.mixture_ratios) > 1:
                        plotter.plot_2D(result, cfg.mixture_ratios, cfg.pressures)

            # ---- ignition delay ------------------------------------------------
            if cfg.reactor.do_ignition_delay:
                print(" - Ignition delay @", cfg.reactor.reactor_type)
                print()
                result = IgnitionDelay(cfg, models).run()
                writer.write(result)

                if plot_requested:
                    if len(cfg.pressures) == 1 and len(cfg.mixture_ratios) > 1 and len(cfg.temperatures) == 1:
                        plotter.plot_1D(result, logy=True)
                    elif len(cfg.pressures) > 1 and len(cfg.mixture_ratios) == 1 and len(cfg.temperatures) == 1:
                        plotter.plot_1D(result, logy=True)
                    elif len(cfg.pressures) == 1 and len(cfg.mixture_ratios) == 1 and len(cfg.temperatures) > 1:
                        plotter.plot_1D(result, logy=True)
                    if cfg.case is not None:
                        plotter.overlay_reference(cfg.case)

            # ---- time evolution ------------------------------------------------
            if cfg.reactor.do_time_evolution:
                print(" - Time-accurate evolution @", cfg.reactor.reactor_type)
                print()
                result = ZeroDTimeEvolution(cfg, models).run()
                writer.write(result)

                if plot_requested:
                    plotter.plot_1D(result, logy=False)

        # ------------------------------------------------------------------ 1D
        elif "1D" in section:
            print(" - 1D simulation")
            print()
            print(" - Counterflow diffusion flame")
            print()

            cfg_1d: FlameConfig = parse_1D(ini_file, section)
            models, _ = parse_reactions(ini_file, section)
            result = CounterflowFlame(cfg_1d, models).run()
            writer.write(result)

            if plot_requested:
                plotter.plot_1D(result, logy=False)

    if plot_requested:
        plt.show()


if __name__ == "__main__":
    main()
