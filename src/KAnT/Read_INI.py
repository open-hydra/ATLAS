from PiNeR import get, check_section
import numpy as np
from KAnT.reference import setup_case

sections = ['KAnT-Equilibrium', 'KAnT-Ignition', 'KAnT-Counterflow']

#
def check_analyses(ini_file):

  types = []
  for section in sections:
    exists = check_section(ini_file, section)
    if exists: types.append(section)

  return types

#
def read_reactions(ini_file, section):
  raw = get(ini_file, section, 'reactions', str)
  if raw is not None:
    mechanisms = raw.split()
    for m in range(len(mechanisms)):
      if 'JLR' in mechanisms[m]: mechanisms[m] += '-ct'

  return mechanisms


#
def read_Xequilibrium(ini_file, section):

  of = get(ini_file, section, 'of', np.ndarray)
  if of is None:
    of_law = get(ini_file, section, 'of-linear', np.ndarray)
    if of_law is None: return
    of = np.linspace(of_law[0], of_law[1], int(of_law[2]))

  pressure = get(ini_file, section, 'pressure', np.ndarray)
  if pressure is None:
    p_law = get(ini_file, section, 'pressure-linear', np.ndarray)
    if p_law is None: return
    pressure = np.linspace(p_law[0], p_law[1], int(p_law[2]))

  fuel_string = []
  fuel_entry = get(ini_file, section, 'fuel', str)
  if '{' not in fuel_entry: fuel_entry = '{'+fuel_entry+':1.0}'
  fuel_string.append(fuel_entry)

  oxi_string = []
  oxi_entry = get(ini_file, section, 'oxidizer', str)
  if '{' not in oxi_entry: oxi_entry = '{'+oxi_entry+':1.0}'
  oxi_string.append(oxi_entry)

  Tf = get(ini_file, section, 'fuel-T', float)
  if Tf is None: Tf = 111.643

  To = get(ini_file, section, 'oxidizer-T', float)
  if To is None: To = 90.170

  fuel_string.insert(0, str(Tf))
  oxi_string.insert(0, str(To))

  return fuel_string, oxi_string, pressure, of

#
def read_Xignition_delay(ini_file, section):

  case = get(ini_file, section, 'case', str)
  if case is not None:
    fuel_entry, oxi_entry, pressure, of, T = setup_case(case)
    return case, fuel_entry, oxi_entry, pressure, of, T

  of = get(ini_file, section, 'of', np.ndarray)
  if of is None:
    of_law = get(ini_file, section, 'of-linear', np.ndarray)
    if of_law is None: return
    of = np.linspace(of_law[0], of_law[1], int(of_law[2]))

  T = get(ini_file, section, 'temperature', np.ndarray)
  if T is None:
    T_law = get(ini_file, section, 'temperature-linear', np.ndarray)
    if T_law is None: return
    T = np.linspace(T_law[0], T_law[1], int(T_law[2]))

  pressure = get(ini_file, section, 'pressure', np.ndarray)
  if pressure is None:
    p_law = get(ini_file, section, 'pressure-linear', np.ndarray)
    if p_law is None: return
    pressure = np.linspace(p_law[0], p_law[1], int(p_law[2]))

  fuel_entry = get(ini_file, section, 'fuel', str)
  if '{' not in fuel_entry: fuel_entry = '{'+fuel_entry+':1.0}'

  oxi_entry = get(ini_file, section, 'oxidizer', str)
  if '{' not in oxi_entry: oxi_entry = '{'+oxi_entry+':1.0}'

  return None, fuel_entry, oxi_entry, pressure, of, T


def read_Xcounterflow(ini_file, section):

  of = get(ini_file, section, 'of', np.ndarray)
  if of is None:
    of_law = get(ini_file, section, 'of-linear', np.ndarray)
    if of_law is None: return
    of = np.linspace(of_law[0], of_law[1], int(of_law[2]))

  pressure = get(ini_file, section, 'pressure', np.ndarray)

  fuel_string = []
  fuel_entry = get(ini_file, section, 'fuel', str)
  if '{' not in fuel_entry: fuel_entry = '{'+fuel_entry+':1.0}'
  fuel_string.append(fuel_entry)

  oxi_string = []
  oxi_entry = get(ini_file, section, 'oxidizer', str)
  if '{' not in oxi_entry: oxi_entry = '{'+oxi_entry+':1.0}'
  oxi_string.append(oxi_entry)

  Tf = get(ini_file, section, 'fuel-T', float)
  if Tf is None: Tf = 1

  To = get(ini_file, section, 'oxidizer-T', float)
  if To is None: To = 1

  fuel_string.insert(0, str(Tf))
  oxi_string.insert(0, str(To))

  mdot = get(ini_file, section, 'mdot', float)
  if mdot is None: mdot = 1.0

  width = get(ini_file, section, 'width', float)
  if width is None: width = 0.2

  return fuel_string, oxi_string, pressure, of, mdot, width
