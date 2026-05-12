import numpy as np
from PiNeR import get, check_section
from pint import UnitRegistry
from dataclasses import dataclass

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


@dataclass(frozen=True)
class PhaseDefinition:
  section: str
  phase_type: str

# Scan INI file for "GPB-Phase*". Assign types to the found phase.
def check_phases(ini_file):
  return [definition.phase_type for definition in load_phase_definitions(ini_file)]


def load_phase_definitions(ini_file):
  phase_definitions = []
  phase_index = 0

  while True:
    phase_index += 1
    section = 'GPB-Phase'+str(phase_index)
    exists = check_section(ini_file, section)

    if not exists:
      break

    phase_type = get(ini_file, section, 'type', str)
    if phase_type is None:
      phase_type = 'ideal-gas'

    phase_definitions.append(PhaseDefinition(section=section, phase_type=phase_type))

  return phase_definitions
