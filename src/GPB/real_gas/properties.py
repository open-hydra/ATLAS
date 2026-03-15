import math

# -----------------------------------------------------------------------
# Model → Cantera YAML mapping
# -----------------------------------------------------------------------
_CANTERA_MODELS = {
    'redlich-kwong':  ('redlich-kwong.yaml',  'RK'),
    'peng-robinson':  ('peng-robinson.yaml',  'PR'),
}


# -----------------------------------------------------------------------
# Public dispatcher
# -----------------------------------------------------------------------
def compute_properties(model, fluid, p, h):
    """Compute real-fluid properties on a (p, h) grid.

    Returns  (thermo_rows, transport_rows, sound_speed_fallback)
    """
    if model == 'coolprop':
        return _compute_coolprop(fluid, p, h)
    yaml_file, suffix = _CANTERA_MODELS[model]
    phase_name = f"{fluid}-{suffix}"
    return _compute_cantera(phase_name, p, h, yaml_file)


def enthalpy_bounds(model, fluid, Tmin, Tmax, pmin, pmax):
    """Convert (T, p) bounds to mass-specific enthalpy bounds.

    Returns (hmin, hmax, s_ref) where s_ref is the entropy at the
    reference point (Tmin, pmin).  The caller uses h_ref = hmin and
    s_ref to shift the output tables so that h = 0 and s = 0 at the
    reference state, making results independent of the model's
    internal reference convention.
    """
    if model == 'coolprop':
        return _enthalpy_bounds_coolprop(fluid, Tmin, Tmax, pmin, pmax)
    yaml_file, suffix = _CANTERA_MODELS[model]
    phase_name = f"{fluid}-{suffix}"
    return _enthalpy_bounds_cantera(phase_name, Tmin, Tmax, pmin, pmax, yaml_file)


# -----------------------------------------------------------------------
# CoolProp backend
# -----------------------------------------------------------------------
def _enthalpy_bounds_coolprop(fluid, Tmin, Tmax, pmin, pmax):
    import CoolProp.CoolProp as CP
    hmin  = CP.PropsSI('Hmass', 'T', Tmin, 'P', pmin, fluid)
    hmax  = CP.PropsSI('Hmass', 'T', Tmax, 'P', pmax, fluid)
    s_ref = CP.PropsSI('S',     'T', Tmin, 'P', pmin, fluid)
    return hmin, hmax, s_ref


def _compute_coolprop(fluid, p, h):
    import CoolProp.CoolProp as CP

    thermo = []
    transport = []
    sound_speed_fallback = False

    for i in range(len(p)):
        for j in range(len(h)):
            rho  = CP.PropsSI('D',               'Hmass', h[j], 'P', p[i], fluid)
            drdp = CP.PropsSI('d(D)/d(P)|Hmass',  'Hmass', h[j], 'P', p[i], fluid)
            drdT = CP.PropsSI('d(D)/d(T)|P',      'Hmass', h[j], 'P', p[i], fluid)
            drdh = CP.PropsSI('d(D)/d(Hmass)|P',  'Hmass', h[j], 'P', p[i], fluid)
            T    = CP.PropsSI('T',                'Hmass', h[j], 'P', p[i], fluid)
            cp   = CP.PropsSI('d(Hmass)/d(T)|P',  'Hmass', h[j], 'P', p[i], fluid)
            s    = CP.PropsSI('S',                'Hmass', h[j], 'P', p[i], fluid)
            mu   = CP.PropsSI('V',                'Hmass', h[j], 'P', p[i], fluid)
            k    = CP.PropsSI('L',                'Hmass', h[j], 'P', p[i], fluid)
            try:
                ss = CP.PropsSI('A', 'Hmass', h[j], 'P', p[i], fluid)
            except Exception:
                sound_speed_fallback = True
                ss = 500.0

            thermo.append([p[i], h[j], rho, T, drdT, drdh, cp, s, drdp, ss])
            transport.append([p[i], h[j], mu, k])

    return thermo, transport, sound_speed_fallback


# -----------------------------------------------------------------------
# Cantera backend
# -----------------------------------------------------------------------
def _make_cantera_phase(phase_name, yaml_file):
    """Create a Cantera Solution for *phase_name* inside *yaml_file*."""
    import cantera as ct
    return ct.Solution(yaml_file, phase_name)


def _enthalpy_bounds_cantera(phase_name, Tmin, Tmax, pmin, pmax, yaml_file):
    phase = _make_cantera_phase(phase_name, yaml_file)
    phase.TP = Tmin, pmin
    hmin  = phase.h
    s_ref = phase.entropy_mass
    phase.TP = Tmax, pmax
    hmax = phase.h
    return hmin, hmax, s_ref


def _compute_cantera(phase_name, p, h, yaml_file):
    phase = _make_cantera_phase(phase_name, yaml_file)

    thermo = []
    transport = []
    sound_speed_fallback = False

    for i in range(len(p)):
        for j in range(len(h)):
            phase.HP = h[j], p[i]

            rho   = phase.density
            T     = phase.T
            cp    = phase.cp_mass
            cv    = phase.cv_mass
            s     = phase.entropy_mass
            alpha = phase.thermal_expansion_coeff
            kappa = phase.isothermal_compressibility

            # Derivatives from thermodynamic identities
            drdT = -rho * alpha
            drdh = -rho * alpha / cp
            drdp = rho * kappa + alpha * (1.0 - T * alpha) / cp

            # Speed of sound: a = sqrt( cp / (cv * rho * kappa_T) )
            try:
                ss = math.sqrt(cp / (cv * rho * kappa))
            except (ValueError, ZeroDivisionError):
                sound_speed_fallback = True
                ss = 500.0

            # Transport
            mu = phase.viscosity
            k  = phase.thermal_conductivity

            thermo.append([p[i], h[j], rho, T, drdT, drdh, cp, s, drdp, ss])
            transport.append([p[i], h[j], mu, k])

    return thermo, transport, sound_speed_fallback
