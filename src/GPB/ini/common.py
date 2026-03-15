import numpy as np
from PiNeR import get, check_section
from pint import UnitRegistry

# -----------------------------------------------------------------------
# Units routines
# -----------------------------------------------------------------------

# Converts a Pint Quantity to magnitude at base SI units.
def to_si(quant):
    return quant.to_base_units().magnitude

def convert2si(value, unit):
    ureg = UnitRegistry()
    Q_ = ureg.Quantity
    quantity = Q_(value, unit)
    return to_si(quantity)

# -----------------------------------------------------------------------
# General tasks routines
# -----------------------------------------------------------------------

# Scan INI file for "GPB-Phase*". Assign types to the found phase.
def check_phases(ini_file):
  i = 0
  types = []
  while True:
    i += 1
    section = 'GPB-Phase'+str(i)
    exists = check_section(ini_file, section)
    
    if not exists:
      break
    else:
      type = get(ini_file, section, 'type', str)
      if type is None: type = 'ideal-gas'
      types.append(type)

  return types
