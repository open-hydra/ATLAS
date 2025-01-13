from PiNeR import get, check_section
import numpy as np

#
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

# -----------------------------------------------------------------------
# Condensed phase routines
# -----------------------------------------------------------------------

def CP_read_models(ini_file,section):

  name = get(ini_file, section, 'name', str)
  if name is None:
    name = ''
  else:
    name = name + '-'
  
  thermo = get(ini_file, section, 'thermo', str)

  T1 = get(ini_file, section, 'Tmin', int)
  T2 = get(ini_file, section, 'Tmax', int)
  if T1 is None:
    T1 = 1
  if T2 is None:
    T2 = 5000

  return name, T1, T2, thermo


def CP_read_material(ini_file,section):

  mat = get(ini_file, section, 'material', list)

  k = get(ini_file, section, 'k', np.ndarray)
  cp = get(ini_file, section, 'cp', np.ndarray)
  rho = get(ini_file, section, 'rho', np.ndarray)

  if mat is None:
    mat = 'ATLAS'

  groups = get(ini_file, section, 'groups', np.ndarray)
  if groups is None:
    groups = np.ones(len(mat))

  return mat, groups, cp, k, rho

# -----------------------------------------------------------------------

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

  ecp = ecv = egamma = eR = ew = emil = ekl = 0

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
    species = "ABCDEF"

  return species, cp, mw, mil, kl

#
def read_eq_CEA(ini_file,section,cea):

  file = get(ini_file, section, 'CEA-file', str)
  if file is None:
    return
  else:
    if ".inp" in file:
      file = file.replace('.inp','')

  cea_section = get(ini_file, section, 'CEA-section', int)
  if cea_section is None:
    cea.indx = 1
  else:
    cea.indx = cea_section

  return file

#
def read_eq_cantera(ini_file, section):

  pressure_string = get(ini_file, section, 'eq-pressure', list)
  if pressure_string is None:
    return

  fuel_string = []
  fuel_entry = get(ini_file, section, 'eq-fuel', str)
  if '{' not in fuel_entry: fuel_entry = '{'+fuel_entry+':1.0}'
  fuel_string.append(fuel_entry)

  oxi_string = []
  oxi_entry = get(ini_file, section, 'eq-oxidizer', str)
  if '{' not in oxi_entry: oxi_entry = '{'+oxi_entry+':1.0}'
  oxi_string.append(oxi_entry)

  of = get(ini_file, section, 'eq-of', float)

  Tf = get(ini_file, section, 'eq-fuel-T', float)
  if Tf is None: Tf = 100.0

  To = get(ini_file, section, 'eq-oxidizer-T', float)
  if To is None: To = 90.170

  fuel_string.insert(0, str(Tf))
  oxi_string.insert(0, str(To))

  return fuel_string, oxi_string, pressure_string, of

# -----------------------------------------------------------------------