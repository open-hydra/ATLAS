"""GPB's side of `thermo = custom`: finds the substances of custom.py (database/thermo/custom_loader.py) and says what
is wrong with them in the words of an INI error. The substances are instances of the classes of
database/thermo/custom_classes.py."""
import sys

from config import THERMO_DIR

if THERMO_DIR not in sys.path:
    sys.path.insert(0, THERMO_DIR)
import custom_loader

_announced = False


def _library(section):
    global _announced
    try:
        lib = custom_loader.load()
    except custom_loader.CustomError as e:
        raise SystemExit(f"[ERROR] [{section}] thermo = custom: {e}")
    if not _announced:
        _announced = True
        for category, name, path in lib.replaced:
            print(f"[INFO] GPB: custom: the {custom_loader.LABEL[category]} {name} of {path} replaces the one "
                  "of database/thermo/custom.py")
    return lib


def substance(section, key, category, name):
    """The substance named `name` (the value of INI key `key`) in custom.py, or an [ERROR] and exit."""
    try:
        return _library(section).get(category, name)
    except custom_loader.CustomError as e:
        raise SystemExit(f"[ERROR] [{section}] {key} = {name} (thermo = custom): {e}")


def properties(material, temperatures):
    """The checked cp, rho, k, h, psat of a CondensedMaterial on the table temperatures [K]."""
    return guarded(material, 'properties', temperatures)


def guarded(obj, method, *args):
    """obj.method(*args) of a substance of custom.py, with its errors worded as GPB errors."""
    try:
        return getattr(obj, method)(*args)
    except (ValueError, NotImplementedError) as e:
        raise SystemExit(f"[ERROR] GPB: custom {custom_loader.LABEL[obj.category]} {e}")
    except Exception as e:    # user code
        raise SystemExit(f"[ERROR] GPB: custom {custom_loader.LABEL[obj.category]} {obj.name}: {method}: "
                         f"{type(e).__name__}: {e}")


def ideal_gas_species(section):
    """The cantera.Species of every IdealGasSpecies of custom.py, in the order in which they are made."""
    import cantera as ct
    lib = _library(section)
    substances = lib.registry.get('ideal-gas', {})
    if not substances:
        raise SystemExit(f"[ERROR] [{section}] thermo = custom: custom.py defines no ideal-gas species "
                         "(an instance of IdealGasSpecies, see database/thermo/custom_classes.py)")
    species = []
    for name, substance in substances.items():
        try:
            sp = substance.species()
        except Exception as e:
            raise SystemExit(f"[ERROR] [{section}] thermo = custom: species {name} ({lib.source['ideal-gas'][name]}): "
                             f"{type(e).__name__}: {e}")
        if not isinstance(sp, ct.Species) or sp.name != name:
            raise SystemExit(f"[ERROR] [{section}] thermo = custom: species() of {name} must return a "
                             f"cantera.Species named {name}")
        species.append(sp)
    return species


def real_fluid(section, fluid):
    """The RealFluid named `fluid` in custom.py."""
    return substance(section, 'fluid', 'real-fluid', fluid)
