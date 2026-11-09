"""The classes of `thermo = custom`: one class per category of phase, and the contract that each one declares.

`thermo = custom` in a GPB section takes its substances from custom.py, instead of from a database file. A class here is
a category; a substance is an instance of it, made with the data of the substance:

    UC = CondensedMaterial("UC", cp=300.0, rho=1000.0, k=lambda T: np.interp(T, T_data, k_data))

Each class declares what its substances receive and what they give, as data: `Quantity` is one variable (name, unit,
meaning, valid values), `Function` one output function (its inputs, its outputs, required or not). The constructor takes
the outputs as keywords, checks them against that declaration (an unknown or a missing one is an error, naming the
substance), and GPB checks every value a substance returns. `python3 custom_classes.py` prints the declarations.

    CondensedMaterial   solid, solid-bulk, *-dispersed   in: T            out: cp, rho (required); k, h, psat (optional)
    IdealGasSpecies     ideal-gas, heavy-gas             in: -            data: composition, nasa7 (required); transport
    RealFluid           real-fluid                       in: (T, p), (h, p)   out: reference -> (h, s); state -> dict

The name of a substance is the name written in input.ini (`material`, `species`, `fluid`): one word, with no blank,
comma, semicolon, '=', '#', '{' or '}'. A substance registers itself when it is made, so custom.py needs no list of its
substances. GPB executes database/thermo/custom.py and then custom.py of the case directory, if there is one: a
substance of the same category and name made in the case directory replaces the one of database/thermo, so that data a
user does not want in the ATLAS tree stays with the case. Within one file, a name can be used once per category.

An output given to the constructor is a number (a constant) or a function of the inputs. For a substance whose relations
need parameters or shared code (a family of materials, an equation of state), derive a class that defines the output
methods itself and make the substances as instances of it; the contract is the same.

Units are SI throughout (K, Pa, J, kg, m, W). A function of `T` receives a numpy array of temperatures [K] (the 1 K
table of the phase) and returns an array of the same size, or a number for a constant. `material.properties(T)` runs
the checks that GPB runs, so a material can be tried without GPB.
"""
import re
from typing import NamedTuple, Optional, Tuple

import numpy as np

# a name is one word of an INI list: no blank, comma, semicolon or sign of the INI syntax
_NAME = re.compile(r"[^\s,;=#{}]+")


class Quantity(NamedTuple):
    """One variable of the contract: what it is called, in which unit, and what values it can take."""
    name: str
    unit: str
    meaning: str
    check: Optional[str] = None     # 'positive', 'nonnegative' or None (any finite value)


class Function(NamedTuple):
    """One output function of a substance: it receives `inputs` (in this order) and gives `outputs`."""
    name: str
    inputs: Tuple[Quantity, ...]
    outputs: Tuple[Quantity, ...]
    required: bool = True
    default: str = ""               # what GPB uses when an optional function is not given

    def signature(self):
        return f"{self.name}({', '.join(q.name for q in self.inputs)})"


def _row(q):
    return f"{q.name} [{q.unit}] {q.meaning}"


class Substance:
    """What every substance shares: the name, the registry, and the check of its outputs against the contract."""

    category = None        # set by the three classes below
    registry = {}          # {category: {name: substance}}, filled by the constructor
    functions = ()         # the Function objects of the category
    data = ()              # the Quantity objects of the category's data (not functions)
    _made_in_file = set()  # (category, name) made by the file being executed (custom_loader resets it)

    def __init__(self, name, **values):
        cls = type(self)
        if self.category is None:
            raise TypeError(f"{cls.__name__}: make an IdealGasSpecies, a CondensedMaterial or a RealFluid")
        if not isinstance(name, str) or not _NAME.fullmatch(name):
            raise TypeError(f"{cls.__name__}: name {name!r} must be one word (no blank, comma, semicolon, "
                            "'=', '#', '{' or '}')")
        self.name = name
        known = [fn.name for fn in self.functions] + [q.name for q in self.data]
        unknown = [key for key in values if key not in known]
        if unknown:
            raise TypeError(f"{self.label}: {', '.join(unknown)} is not in the contract of {cls.__name__} "
                            f"(it takes {', '.join(known)})")
        self._values = values
        for key in [q.name for q in self.data]:
            if key in values:
                setattr(self, key, values[key])
        missing = [fn.signature() for fn in self.functions
                   if fn.required and fn.name not in values and not self._overrides(fn.name)]
        if missing:
            raise TypeError(f"{self.label}: give {', '.join(missing)} (required by {cls.__name__})")
        key = (self.category, name)
        if key in Substance._made_in_file:
            raise ValueError(f"{self.label}: made twice in the same file")
        Substance._made_in_file.add(key)
        Substance.registry.setdefault(self.category, {})[name] = self

    @property
    def label(self):
        return f"{type(self).__name__} {self.name!r}" if hasattr(self, "name") else type(self).__name__

    def _overrides(self, method):
        """True when a class derived from the category class defines `method` itself."""
        base = next(c for c in type(self).__mro__ if c.__dict__.get("category") == self.category)
        return getattr(type(self), method) is not getattr(base, method)

    def _value(self, name, *args):
        """The output `name` given to the constructor, evaluated on args: a function is called, a number returned."""
        value = self._values[name]
        return value(*args) if callable(value) else value

    def __repr__(self):
        return f"{type(self).__name__}({self.name!r})"

    @classmethod
    def contract(cls):
        """The contract of the category, as text."""
        lines = [f"{cls.__name__}  (category {cls.category})"]
        for q in cls.data:
            lines.append(f"  data       {_row(q)}")
        for fn in cls.functions:
            ins = ", ".join(_row(q) for q in fn.inputs) or "nothing"
            outs = ", ".join(_row(q) for q in fn.outputs)
            need = "required" if fn.required else f"optional, if absent: {fn.default}"
            lines.append(f"  {fn.signature():<14} {need}\n      in:  {ins}\n      out: {outs}")
        return "\n".join(lines)

    def _array(self, fn, q, value, T):
        """`value` as an array on T: a number is broadcast; a wrong size, a value that is not finite, and a sign the
        quantity cannot have are refused, naming the substance, the function and the first temperature."""
        v = np.asarray(value, dtype=float)
        if v.ndim == 0:
            v = np.full(T.shape, float(v))
        if v.shape != T.shape:
            raise ValueError(f"{self.name}: {fn.signature()} returned {v.size} value(s) for {T.size} temperatures")
        bad = ~np.isfinite(v)
        if q.check == "positive":
            bad |= v <= 0.0
        elif q.check == "nonnegative":
            bad |= v < 0.0
        if bad.any():
            i = int(np.argmax(bad))
            sign = " (positive)" if q.check == "positive" else " (not negative)" if q.check == "nonnegative" else ""
            raise ValueError(f"{self.name}: {fn.name}({T[i]:g} K) = {v[i]:g} is not a valid value{sign}")
        return v


# ---------------------------------------------------------------------------------------------------------------
# Condensed materials
# ---------------------------------------------------------------------------------------------------------------
_T = Quantity("T", "K", "temperature", "positive")


class CondensedMaterial(Substance):
    """A solid or a liquid of a condensed phase (solid, solid-bulk, condensed/liquid/solid-dispersed).

        CondensedMaterial(name, cp=..., rho=..., k=..., h=..., psat=..., absolute_enthalpy=False)

    Input: the temperature T [K]. Outputs, each a number or a function of T:
        cp     specific heat [J/kg/K]                       required
        rho    density [kg/m3]                              required
        k      thermal conductivity [W/m/K]                 optional, zero when not given
        h      specific enthalpy [J/kg]                     optional, by default the integral of cp from the first
               temperature of the table, which is zero there (a relative enthalpy, as for a constant cp). Give
               `absolute_enthalpy=True` and h on the formation scale of the databases (it is then written as
               Enthalpy_abs) to put the material next to NASA9 or Burcat ones
        psat   saturation pressure [Pa]                     optional, for a dispersed (liquid) material: the Psat
               column
    """

    category = "condensed"
    absolute_enthalpy = False
    data = (Quantity("absolute_enthalpy", "-", "True when h is on the formation scale of the databases; default False"),)
    functions = (
        Function("cp", (_T,), (Quantity("cp", "J/kg/K", "specific heat", "positive"),)),
        Function("rho", (_T,), (Quantity("rho", "kg/m3", "density", "positive"),)),
        Function("k", (_T,), (Quantity("k", "W/m/K", "thermal conductivity", "nonnegative"),),
                 required=False, default="0"),
        Function("h", (_T,), (Quantity("h", "J/kg", "specific enthalpy"),),
                 required=False, default="the integral of cp from the first temperature, zero there"),
        Function("psat", (_T,), (Quantity("psat", "Pa", "saturation pressure", "positive"),),
                 required=False, default="none: no Psat column for this material"),
    )

    def cp(self, T):
        return self._value("cp", T)

    def rho(self, T):
        return self._value("rho", T)

    def k(self, T):
        return self._value("k", T) if "k" in self._values else 0.0

    def h(self, T):
        if "h" in self._values:
            return self._value("h", T)
        cp = self._array(self.functions[0], self.functions[0].outputs[0], self.cp(T.copy()), T)
        h = np.zeros_like(T)
        h[1:] = np.cumsum(0.5 * (cp[1:] + cp[:-1]) * np.diff(T))
        return h

    def psat(self, T):
        return self._value("psat", T) if "psat" in self._values else None

    def properties(self, T):
        """{cp, rho, k, h, psat} on the temperatures T [K], after the checks (psat is None when not given)."""
        T = np.asarray(T, dtype=float)
        out = {}
        for fn in self.functions:
            value = getattr(self, fn.name)(T.copy())
            out[fn.name] = None if value is None else self._array(fn, fn.outputs[0], value, T)
        return out


# ---------------------------------------------------------------------------------------------------------------
# Ideal-gas species
# ---------------------------------------------------------------------------------------------------------------
class IdealGasSpecies(Substance):
    """A gas species, in the thermo (and transport) database of an ideal-gas phase.

        IdealGasSpecies(name, composition=..., nasa7=..., transport=...)

    It receives nothing: the species is data, and Cantera evaluates its thermodynamics at the temperatures of the
    solver. The data, with the NASA 7-coefficient polynomials that Chemkin, Burcat and Cantera files use:

        composition = {"C": 1, "H": 4}                                                      required
        nasa7 = {"Tmin": 200.0, "Tmid": 1000.0, "Tmax": 6000.0,                             required
                 "low": [7 coefficients for Tmin..Tmid], "high": [7 coefficients for Tmid..Tmax]}
        transport = {"geometry": "nonlinear", "diameter": 3.746, "well_depth": 141.4}       optional

    `transport` takes the Lennard-Jones data of Cantera's GasTransportData: geometry ('atom', 'linear' or
    'nonlinear'), diameter [Angstrom], well_depth [K], and optionally dipole [Debye], polarizability [Angstrom^3] and
    rotational_relaxation. `nasa7` takes `reference_pressure` [Pa] (default 1 atm, as the database files).
    For any other form (NASA 9-coefficient polynomials, a constant cp, a formula) give `species`, a function of nothing
    that returns a cantera.Species named like the substance: then composition and nasa7 are not needed.
    """

    category = "ideal-gas"
    composition = None
    nasa7 = None
    transport = None
    data = (
        Quantity("composition", "-", "elements and their number of atoms, as {'C': 1, 'H': 4}"),
        Quantity("nasa7", "-", "dict Tmin, Tmid, Tmax [K], low, high [7 coefficients each], reference_pressure [Pa]"),
        Quantity("transport", "-", "dict of cantera.GasTransportData: geometry, diameter, well_depth, ...; optional"),
    )
    functions = (
        Function("species", (), (Quantity("species", "-", "a cantera.Species named like the substance"),),
                 required=False, default="built from composition, nasa7 and transport"),
    )

    def __init__(self, name, **values):
        super().__init__(name, **values)
        if "species" not in values and not self._overrides("species") and not (self.composition and self.nasa7):
            raise TypeError(f"{self.label}: give composition and nasa7, or species")

    def species(self):
        import cantera as ct
        if "species" in self._values:
            return self._value("species")
        sp = ct.Species(self.name, dict(self.composition))
        n = self.nasa7
        for key in ("Tmin", "Tmid", "Tmax", "low", "high"):
            if key not in n:
                raise ValueError(f"{self.name}: nasa7 lacks '{key}'")
        if len(n["low"]) != 7 or len(n["high"]) != 7:
            raise ValueError(f"{self.name}: nasa7 'low' and 'high' take 7 coefficients each")
        # Cantera's NasaPoly2 wants [Tmid, high..., low...]; the files and this class list low first
        sp.thermo = ct.NasaPoly2(n["Tmin"], n["Tmax"], n.get("reference_pressure", ct.one_atm),
                                 [n["Tmid"]] + list(n["high"]) + list(n["low"]))
        if self.transport:
            sp.transport = ct.GasTransportData(**self.transport)
        return sp


# ---------------------------------------------------------------------------------------------------------------
# Real fluids
# ---------------------------------------------------------------------------------------------------------------
_Tk = Quantity("T", "K", "temperature", "positive")
_p = Quantity("p", "Pa", "pressure", "positive")
_h = Quantity("h", "J/kg", "specific enthalpy")


class RealFluid(Substance):
    """A real fluid, tabulated by GPB on a grid of pressure and mass enthalpy.

        RealFluid(name, reference=..., state=...)

    Two functions, both required:
        reference(T, p)   in: T [K], p [Pa]     out: (h, s), mass enthalpy [J/kg] and entropy [J/kg/K]
                          GPB uses it for the enthalpy bounds of the table and shifts h and s to zero at (Tmin, pmin)
        state(h, p)       in: h [J/kg], p [Pa]  out: a dict with
                              T       temperature [K]
                              rho     density [kg/m3]
                              drho_dT d(rho)/dT at constant p [kg/m3/K]
                              drho_dh d(rho)/dh at constant p [kg/m3/(J/kg)]
                              drho_dp d(rho)/dp at constant h [kg/m3/Pa]
                              cp      specific heat at constant p [J/kg/K]
                              s       entropy [J/kg/K]
                              mu      dynamic viscosity [Pa s]
                              k       thermal conductivity [W/m/K]
                              a       speed of sound [m/s]; optional (GPB writes 500 m/s and says so when absent)
    An equation of state with parameters is a class derived from RealFluid that defines reference and state, whose
    instances are the fluids.
    """

    category = "real-fluid"
    _state_required = (
        Quantity("T", "K", "temperature", "positive"),
        Quantity("rho", "kg/m3", "density", "positive"),
        Quantity("drho_dT", "kg/m3/K", "d(rho)/dT at constant p"),
        Quantity("drho_dh", "kg/m3/(J/kg)", "d(rho)/dh at constant p"),
        Quantity("drho_dp", "kg/m3/Pa", "d(rho)/dp at constant h"),
        Quantity("cp", "J/kg/K", "specific heat at constant p", "positive"),
        Quantity("s", "J/kg/K", "entropy"),
        Quantity("mu", "Pa s", "dynamic viscosity", "nonnegative"),
        Quantity("k", "W/m/K", "thermal conductivity", "nonnegative"),
    )
    _state_optional = Quantity("a", "m/s", "speed of sound", "positive")
    functions = (
        Function("reference", (_Tk, _p), (_h, Quantity("s", "J/kg/K", "entropy"))),
        Function("state", (_h, _p), _state_required + (_state_optional,)),
    )

    def reference(self, T, p):
        return self._value("reference", T, p)

    def state(self, h, p):
        return self._value("state", h, p)

    def checked_state(self, h, p):
        """state(h, p) with the keys checked; the speed of sound is None when the fluid gives none."""
        s = self.state(h, p)
        missing = [q.name for q in self._state_required if q.name not in s]
        if missing:
            raise ValueError(f"{self.name}: state(h, p) lacks {', '.join(missing)}")
        out = {}
        for q in self._state_required + (self._state_optional,):
            value = s.get(q.name)
            if value is None and q is self._state_optional:
                out[q.name] = None
                continue
            value = float(value)
            bad = (not np.isfinite(value) or (q.check == "positive" and value <= 0.0)
                   or (q.check == "nonnegative" and value < 0.0))
            if bad:
                raise ValueError(f"{self.name}: state(h = {h:g}, p = {p:g}) gives {q.name} = {value:g} "
                                 "which is not a valid value")
            out[q.name] = value
        return out


if __name__ == "__main__":
    for base in (CondensedMaterial, IdealGasSpecies, RealFluid):
        print(base.contract(), end="\n\n")
