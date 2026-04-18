import numpy as np
from PiNeR import get

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
