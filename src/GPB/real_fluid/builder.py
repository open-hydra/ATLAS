import numpy as np
from config import setup_cantera_dirs
from ini import RF_read_params
import custom_support
from . import properties as RF_properties
from . import io as RF_IO

setup_cantera_dirs()


def _build(inifile, section):
    """Build real-gas lookup tables for a single phase section."""

    # ----------------------------------------------------------
    # Read INI parameters
    # ----------------------------------------------------------
    (name, fluid, pmin, pmax, Tmin, Tmax, NP, NH,
     model) = RF_read_params(inifile, section)

    print(f" - Real-gas phase: {fluid}  (thermo: {model})")
    source = custom_support.real_fluid(section, fluid) if model == 'custom' else fluid   # a name, or the RealFluid of custom.py

    # ----------------------------------------------------------
    # Convert T,p bounds to enthalpy bounds
    # ----------------------------------------------------------
    hmin, hmax, s_ref = RF_properties.enthalpy_bounds(model, source, Tmin, Tmax, pmin, pmax)
    h_ref = hmin

    # ----------------------------------------------------------
    # Build grids
    # ----------------------------------------------------------
    p = np.linspace(pmin, pmax, NP)
    h = np.linspace(hmin, hmax, NH)

    # ----------------------------------------------------------
    # Compute properties
    # ----------------------------------------------------------
    thermo_rows, transport_rows, fallback = RF_properties.compute_properties(model, source, p, h)

    if fallback: print("  [WARNING] speed of sound fallback (500 m/s) used for some points")

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

    # ----------------------------------------------------------
    # Write output
    # ----------------------------------------------------------
    RF_IO.write_phase(name, fluid)
    RF_IO.write_thermo(name, NP, NH, thermo_rows)
    RF_IO.write_transport(name, NP, NH, transport_rows)

    #print(f"   Wrote {name}phase.txt, {name}thermo.dat and {name}transport.dat")
