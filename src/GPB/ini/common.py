import numpy as np
from PiNeR import get, check_section
from pint import UnitRegistry
from dataclasses import dataclass
from typing import Optional

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
  phase_modeling: Optional[str] = None   # 'lagrangian' | 'eulerian' | None (dispersed phases only)

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

    # PiNeR/configparser keeps an inline ';' comment inside the value
    # (hydra cases write `modeling = lagrangian ; ...`): strip it here.
    phase_type = phase_type.split(';')[0].strip()

    # Optional solver treatment of a dispersed phase, written on line 1 of
    # <name>phase.txt as 'modeling=<value>'. It must never alter phase_type.
    phase_modeling = get(ini_file, section, 'modeling', str)
    if phase_modeling is not None:
      phase_modeling = phase_modeling.split(';')[0].strip().lower()
      if phase_modeling not in ('lagrangian', 'eulerian'):
        raise SystemExit(f"[ERROR] [{section}] modeling = '{phase_modeling}': expected lagrangian or eulerian")
      if 'dispersed' not in phase_type.lower():
        print(f" [WARNING] [{section}] modeling is only meaningful for a dispersed phase; ignored")
        phase_modeling = None

    phase_definitions.append(PhaseDefinition(section=section, phase_type=phase_type, phase_modeling=phase_modeling))

  return phase_definitions
