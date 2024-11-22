from pint import UnitRegistry

def to_si(quant):
    '''Converts a Pint Quantity to magnitude at base SI units.
    '''
    return quant.to_base_units().magnitude

def convert2si(value, unit):

    ureg = UnitRegistry()
    Q_ = ureg.Quantity

    quantity = Q_(value, unit)

    return to_si(quantity)