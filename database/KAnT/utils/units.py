from pint import UnitRegistry

# Module-level singleton — avoids creating a new registry on every call.
_ureg = UnitRegistry()
_Q = _ureg.Quantity


def to_si(quant):
    """Convert a Pint Quantity to its magnitude in base SI units."""
    return quant.to_base_units().magnitude


def convert2si(value, unit):
    """Convert *value* expressed in *unit* to its SI magnitude."""
    return to_si(_Q(value, unit))
