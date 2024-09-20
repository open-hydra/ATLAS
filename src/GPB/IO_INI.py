from PiNeR import get
import numpy as np

#def count_phases(ini_file):

#
def read_CEA(ini_file,section,cea):

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
def read_canteraXequilibrium(ini_file, section):

  pressure_string = get(ini_file, section, 'CT-eq-pressure', list)
  if pressure_string is None:
    return
  fuel_string = get(ini_file, section, 'CT-eq-fuel', list)
  oxy_string = get(ini_file, section, 'CT-eq-oxydizer', list)
  of = get(ini_file, section, 'CT-eq-of', float)

  return fuel_string, oxy_string, pressure_string, of

#
def read_models(ini_file,section):

  name = get(ini_file, section, 'name', str)
  if name is None:
    name = 'gas'
  thermo = get(ini_file, section, 'thermo', str)
  transport = get(ini_file, section, 'transport', str)
  reactions = get(ini_file, section, 'reactions', str)

  T1 = get(ini_file, section, 'Tmin', str)
  T2 = get(ini_file, section, 'Tmax', str)
  if T1 is None:
    T1 = 100
  if T2 is None:
    T2 = 6000

  return name, T1, T2, thermo, transport, reactions

#
def read_inert_species(ini_file,section):

  species = get(ini_file, section, 'species', list)

  return species

#
def read_options(ini_file,section):

  mix = get(ini_file, section, 'inerts-mixing', bool)
  if mix is None:
    mix = False

  HG = False
  type = get(ini_file, section, 'type', str)
  if 'heavy' in type:
    HG = True

  return mix, HG

#
def read_fixgas(ini_file,section):

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

  return species, cp, mw, mil, kl