import numpy as np
from config import setup_cantera_dirs
from ini import RG_read_params
from . import properties as RG_properties
from . import io as RG_IO

setup_cantera_dirs()


def _build(inifile, section):
    """Build real-gas lookup tables for a single phase section."""

    # ----------------------------------------------------------
    # Read INI parameters
    # ----------------------------------------------------------
    (name, fluid, pmin, pmax, Tmin, Tmax, NP, NH,
     model) = RG_read_params(inifile, section)

    print(f" - Real-gas phase: {fluid}  (model: {model})")

    # ----------------------------------------------------------
    # Convert T,p bounds to enthalpy bounds
    # ----------------------------------------------------------
    hmin, hmax, s_ref = RG_properties.enthalpy_bounds(
        model, fluid, Tmin, Tmax, pmin, pmax)
    h_ref = hmin

    # ----------------------------------------------------------
    # Build grids
    # ----------------------------------------------------------
    p = np.linspace(pmin, pmax, NP)
    h = np.linspace(hmin, hmax, NH)
    dp = p[1] - p[0]
    dh = h[1] - h[0]

    # ----------------------------------------------------------
    # Compute properties
    # ----------------------------------------------------------
    thermo_rows, transport_rows, fallback = \
        RG_properties.compute_properties(model, fluid, p, h)

    if fallback:
        print("  WARNING: speed of sound fallback (500 m/s) used for some points")

    # ----------------------------------------------------------
    # Shift enthalpy and entropy to zero at (Tmin, pmin)
    # ----------------------------------------------------------
    # This removes the model-specific reference state so that
    # tables produced by different EoS are directly comparable.
    for row in thermo_rows:
        row[1] -= h_ref   # enthalpy column
        row[7] -= s_ref   # entropy column
    for row in transport_rows:
        row[1] -= h_ref   # enthalpy column

    hmin_out = 0.0
    hmax_out = hmax - h_ref

    # ----------------------------------------------------------
    # Write output
    # ----------------------------------------------------------
    RG_IO.write_phase(name, fluid)
    RG_IO.write_thermo(name, pmin, pmax, dp, hmin_out, hmax_out, dh, NP, NH,
                       thermo_rows)
    RG_IO.write_transport(name, pmin, pmax, dp, hmin_out, hmax_out, dh, NP, NH,
                          transport_rows)

    #print(f"   Wrote {name}phase.txt, {name}thermo.dat and {name}transport.dat")
