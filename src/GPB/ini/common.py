import numpy as np
import sys
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

# PiNeR's bool conversion maps every unknown spelling (e.g. 'tru') to False silently
def get_bool(ini_file, section, option, default):
    """Boolean key: true/yes/on/1/t or false/no/off/0/f (case-insensitive); absent -> default; anything else is refused."""
    raw = get(ini_file, section, option, str)
    if raw is None:
        return default
    if raw.strip().lower() in ('true', 'yes', 'on', '1', 't'):
        return True
    if raw.strip().lower() in ('false', 'no', 'off', '0', 'f'):
        return False
    print(f"[ERROR] key {option} of section [{section}]: {option} = {raw} is not a boolean (write true or false)")
    sys.exit(1)

# PiNeR's int conversion returns None for a non-integer value (e.g. '300.5'), which silently applied the default
def get_integer_kelvin(ini_file, section, option, default):
    """Temperature bound of the tables [K], which have a 1 K step: absent -> default; an integral value
    (300 or 300.0; an inline '; comment' is ignored) -> int; anything else is refused."""
    raw = get(ini_file, section, option, str)
    if raw is None:
        return default
    try:
        value = float(raw.split(';')[0].strip())
    except ValueError:
        value = None
    if value is None or not value.is_integer():
        print(f"[ERROR] key {option} of section [{section}]: {option} = {raw} is not an integer number of kelvin (the tables run from Tmin to Tmax with a 1 K step)")
        sys.exit(1)
    if value <= 0:
        print(f"[ERROR] key {option} of section [{section}]: {option} = {raw} is not a temperature above 0 K")
        sys.exit(1)
    return int(value)

def check_kelvin_range(section, T1, T2):
    """The tables run from Tmin up to Tmax: Tmin above Tmax is refused."""
    if T1 > T2:
        print(f"[ERROR] section [{section}]: Tmin = {T1} is above Tmax = {T2} (the tables run from Tmin up to Tmax)")
        sys.exit(1)

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
