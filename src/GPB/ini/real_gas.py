import numpy as np
from PiNeR import get

# -----------------------------------------------------------------------
# Real-gas phase routines
# -----------------------------------------------------------------------

_VALID_MODELS = ('coolprop', 'redlich-kwong', 'peng-robinson')

def RG_read_params(ini_file, section):
    """Read real-gas lookup-table parameters from the INI file."""

    name = get(ini_file, section, 'name', str)
    if name is None:
        name = ''
    else:
        name = name + '-'

    fluid = get(ini_file, section, 'fluid', str)
    if fluid is None:
        raise RuntimeError("Fluid not defined in section " + section)

    pmin = get(ini_file, section, 'pmin', float)
    pmax = get(ini_file, section, 'pmax', float)
    Tmin = get(ini_file, section, 'Tmin', float)
    Tmax = get(ini_file, section, 'Tmax', float)

    if Tmin is None:
        raise RuntimeError("Tmin not defined in section " + section)
    if Tmax is None:
        raise RuntimeError("Tmax not defined in section " + section)
    if pmin is None:
        raise RuntimeError("pmin not defined in section " + section)
    if pmax is None:
        raise RuntimeError("pmax not defined in section " + section)

    NP = get(ini_file, section, 'NP', int)
    if NP is None:
        print("  NP not specified, defaulting to 200")
        NP = 200

    NH = get(ini_file, section, 'NH', int)
    if NH is None:
        print("  NH not specified, defaulting to 200")
        NH = 200

    model = get(ini_file, section, 'model', str)
    if model is None:
        model = 'coolprop'
    model = model.lower()
    if model not in _VALID_MODELS:
        raise RuntimeError(
            f"Unknown model '{model}' in section {section}. "
            f"Valid options: {', '.join(_VALID_MODELS)}")

    return name, fluid, pmin, pmax, Tmin, Tmax, NP, NH, model
