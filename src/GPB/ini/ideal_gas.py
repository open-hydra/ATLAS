import numpy as np
import sys
from PiNeR import get
from ini.common import get_bool, get_integer_kelvin, check_kelvin_range

# -----------------------------------------------------------------------
# Ideal-gas phase routines
# -----------------------------------------------------------------------

#
def IG_read_models(ini_file,section):

  name = get(ini_file, section, 'name', str)
  if name is None:
    name = ''
  else:
    name = name + '-'
  
  phase = get(ini_file, section, 'phase', str)
  thermo = get(ini_file, section, 'thermo', str)
  transport = get(ini_file, section, 'transport', str)
  reactions = get(ini_file, section, 'reactions', str)

  T1 = get_integer_kelvin(ini_file, section, 'Tmin', 1)
  T2 = get_integer_kelvin(ini_file, section, 'Tmax', 5000)
  check_kelvin_range(section, T1, T2)

  return name, T1, T2, phase, thermo, transport, reactions

#
def IG_read_options(ini_file,section):

  mix = get_bool(ini_file, section, 'inerts-mixing', False)   # a misspelt value is refused, not read as false

  HG = False
  type = get(ini_file, section, 'type', str)
  if type is not None:
    if 'heavy' in type:
      HG = True

  # strict-thermo: refuse (instead of warning) a database thermo record that differs from the mechanism record by more than 1 kJ/mol
  strict = get_bool(ini_file, section, 'strict-thermo', False)

  return mix, HG, strict

#
def IG_read_inert_species(ini_file,section):

  species = get(ini_file, section, 'species', list)
  if species is None:
    species = get(ini_file, section, 'add-species', list)

  return species

#
def IG_read_mixture(ini_file,section):

  mix_string = []
  mix_entry = get(ini_file, section, 'mixture', str)
  if mix_entry is None:
   return None
  if '{' not in mix_entry: mix_entry = '{'+mix_entry+':1.0}'
  mix_string.append(mix_entry)

  mix_name = get(ini_file, section, 'mixture-name', str)
  if mix_name is None:
   mix_name = 'mix'

  return mix_string, mix_name

# Keys of the viscosity law of the fixed species
LAW_KEYS = ('mil-law', 'mil-ref', 'T-ref', 'S-mil')

#
def IG_read_per_species(ini_file, section, key, unit, n):
  """One positive number per fixed species for key [unit], or None when the key is absent; anything else is refused
  (PiNeR returns None for a value it cannot read, which would pass for an absent key)."""
  raw = get(ini_file, section, key, str)
  if raw is None:
    return None
  try:
    values = np.array([float(x) for x in raw.split()])
  except ValueError:
    values = None
  if values is None or values.size != n or np.any(values <= 0.0):
    print(f"[ERROR] key {key} of section [{section}]: {key} = {raw} is not {n} positive number(s) [{unit}], one per fixed species")
    sys.exit(1)
  return values

#
def IG_read_viscosity_law(ini_file, section, n):
  """mil-law of the n fixed species: None for constant (mil, kl and Pr as they are), else the Sutherland law
  mu = mil-ref (T/T-ref)^1.5 (T-ref + S-mil)/(T + S-mil), with k = mu cp/Pr or the constant kl, as a dict."""
  raw = get(ini_file, section, 'mil-law', str)
  law = 'constant' if raw is None else raw.strip().lower()
  if law not in ('constant', 'sutherland'):
    print(f"[ERROR] key mil-law of section [{section}]: mil-law = {raw} is not a viscosity law (constant or sutherland)")
    sys.exit(1)
  coefficients = (('mil-ref', 'Pa s'), ('T-ref', 'K'), ('S-mil', 'K'))
  given = [key for key, unit in coefficients if get(ini_file, section, key, str) is not None]
  if law == 'constant':
    if given:
      print(f"[ERROR] key {given[0]} of section [{section}]: {', '.join(given)} given without mil-law = sutherland")
      sys.exit(1)
    return None
  if get(ini_file, section, 'mil', str) is not None:
    print(f"[ERROR] key mil of section [{section}]: mil and mil-law = sutherland both give the viscosity: give one of them")
    sys.exit(1)
  missing = [key for key, unit in coefficients if key not in given]
  if missing:
    print(f"[ERROR] key {missing[0]} of section [{section}]: mil-law = sutherland needs mil-ref, T-ref and S-mil ({', '.join(missing)} not given)")
    sys.exit(1)
  law = {key: IG_read_per_species(ini_file, section, key, unit, n) for key, unit in coefficients}
  law['Pr'] = IG_read_per_species(ini_file, section, 'Pr', '-', n)
  law['kl'] = IG_read_per_species(ini_file, section, 'kl', 'W/m/K', n)
  if (law['Pr'] is None) == (law['kl'] is None):
    print(f"[ERROR] section [{section}]: mil-law = sutherland takes the conductivity from one of Pr (k = mu cp/Pr) and kl (a constant k): {'both' if law['Pr'] is not None else 'neither'} given")
    sys.exit(1)
  transport = get(ini_file, section, 'transport', str)
  if transport is not None:
    print(f"[WARNING] key transport of section [{section}]: transport = {transport} is ignored: mil-law = sutherland gives the transport of the fixed species")
  return law

#
def IG_read_fixgas(ini_file,section):

  ecp = ecv = egamma = eR = ew = emil = ekl = ePr = 0

  Runi = 8314.46261815324  # J/(kmol K): exact SI value (N_A k_B), the constant Cantera uses (ct.gas_constant)

  species = get(ini_file, section, 'species', list)

  cp = get(ini_file, section, 'cp', np.ndarray)
  if cp is None:
    ecp = 1
  cv = get(ini_file, section, 'cv', np.ndarray)
  if cv is None:
    ecv = 1
  gamma = get(ini_file, section, 'gamma', np.ndarray)
  if gamma is None:
    egamma = 1
  R = get(ini_file, section, 'R', np.ndarray)
  if R is None:
    eR = 1
  mw = get(ini_file, section, 'mw', np.ndarray)
  if mw is None:
    ew = 1

  if (ecp+ecv+egamma+eR+ew==5):
    given = [key for key in LAW_KEYS if get(ini_file, section, key, str) is not None]
    if given:
      print(f"[ERROR] key {given[0]} of section [{section}]: a viscosity law is a property of fixed species, given by two of cp, cv, gamma, R, mw")
      sys.exit(1)
    species = None
    return

  if (ecp+eR==0):
    mw = Runi/R
  elif (ecp+egamma==0):
    mw = gamma/(gamma-1)*Runi/cp
  elif (ecp+ecv==0):
    mw = Runi/(cp-cv)
  elif (ecv+egamma==0):
    cp = gamma*cv; mw = gamma/(gamma-1)*Runi/cp
  elif (ecv+eR==0):
    cp = cv+R; mw = Runi/R
  elif (ecv+ew==0):
    cp = cv+Runi/mw
  elif (egamma+eR==0):
    cp = gamma/(gamma-1)*R; mw = Runi/R
  elif (egamma+ew==0):
    cp = gamma/(gamma-1)*Runi/mw

  mil = get(ini_file, section, 'mil', np.ndarray)
  if mil is None:
    emil = 1
  kl = get(ini_file, section, 'kl', np.ndarray)
  if kl is None:
    ekl = 1
  Pr = get(ini_file, section, 'Pr', np.ndarray)
  if Pr is None:
    ePr = 1

  law = IG_read_viscosity_law(ini_file, section, np.size(cp))
  if law is not None:
    law['cp'] = cp
    if not species:
      species = "ATLAS"
    return species, cp, mw, None, None, law

  if (emil+ekl+ePr==0):
    exit('Too many thermo input data: mil, kl, Pr')
  if (emil==0 and ekl+ePr==2):
    print(f"[ERROR] key mil of section [{section}]: mil gives the viscosity of the fixed species; their conductivity needs kl or Pr as well")
    sys.exit(1)
  # elif (emil+ekl+ePr==3):
  #   mil = 0.0; kl = 0.0

  if (emil+ePr==0):
    kl = mil*cp/Pr
  elif (ekl+ePr==0):
    mil = Pr*kl/cp

  if not species:
    species = "ATLAS"

  return species, cp, mw, mil, kl, None
