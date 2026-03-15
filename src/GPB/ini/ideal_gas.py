import numpy as np
from PiNeR import get

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

  T1 = get(ini_file, section, 'Tmin', int)
  T2 = get(ini_file, section, 'Tmax', int)
  if T1 is None:
    T1 = 1
  if T2 is None:
    T2 = 5000

  return name, T1, T2, phase, thermo, transport, reactions

#
def IG_read_options(ini_file,section):

  mix = get(ini_file, section, 'inerts-mixing', bool)
  if mix is None:
    mix = False

  HG = False
  type = get(ini_file, section, 'type', str)
  if type is not None:
    if 'heavy' in type:
      HG = True

  return mix, HG

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

#
def IG_read_fixgas(ini_file,section):

  ecp = ecv = egamma = eR = ew = emil = ekl = ePr = 0

  Runi = 8314.51

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

  if (emil+ekl+ePr==0):
    exit('Too many thermo input data: mil, kl, Pr')
  # elif (emil+ekl+ePr==3):
  #   mil = 0.0; kl = 0.0

  if (emil+ePr==0):
    kl = mil*cp/Pr
  elif (ekl+ePr==0):
    mil = Pr*kl/cp

  if not species:
    species = "ATLAS"

  return species, cp, mw, mil, kl
