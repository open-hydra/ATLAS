from PiNeR import get

# -----------------------------------------------------------------------
# Real-fluid phase routines
# -----------------------------------------------------------------------

_VALID_THERMO = ('coolprop', 'redlich-kwong', 'peng-robinson', 'custom')

def RF_read_params(ini_file, section):
    """Read real-fluid lookup-table parameters from the INI file."""

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

    # thermo selects the source of the fluid, as in the other phase types; model is its former name
    thermo = get(ini_file, section, 'thermo', str)
    legacy = get(ini_file, section, 'model', str)
    thermo = None if thermo is None else thermo.split(';')[0].strip()
    legacy = None if legacy is None else legacy.split(';')[0].strip()
    if legacy is not None:
        if thermo is None:
            print(f"[WARNING] [{section}] model is deprecated: write thermo = {legacy}")
            thermo = legacy
        elif thermo.lower() != legacy.lower():
            raise RuntimeError(
                f"thermo = {thermo} and model = {legacy} in section {section}: "
                "model is the former name of thermo, give thermo only")
        else:
            print(f"[WARNING] [{section}] model is deprecated and ignored: thermo = {thermo} is used")
    if thermo is None:
        thermo = 'coolprop'
    thermo = thermo.lower()
    if thermo not in _VALID_THERMO:
        raise RuntimeError(
            f"Unknown thermo '{thermo}' in section {section}. "
            f"Valid options: {', '.join(_VALID_THERMO)}")

    return name, fluid, pmin, pmax, Tmin, Tmax, NP, NH, thermo
