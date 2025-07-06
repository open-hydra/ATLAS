from PiNeR import get, check_section
import numpy as np
from dataclasses import dataclass
from reference import setup_case

sections = ['KAnT-Simulation0D', 'KAnT-Simulation1D']

@dataclass
class Out:
    eq: bool  # Do equilibrium
    id: bool  # Do ignition delay
    te: bool  # Do time evolution
    type: str # Type of reactor (HP, LP, etc.)


#
def check_analyses(ini_file):

  types = []
  for section in sections:
    exists = check_section(ini_file, section)
    if exists: types.append(section)

  return types

#
def read_reactions(ini_file, section):

  import phase_tools

  raw = get(ini_file, section, 'reactions', str)
  if raw is not None:
    mechanisms = raw.split()
    for m in range(len(mechanisms)):
      if 'JLR' in mechanisms[m]: mechanisms[m] += '-ct'
  else:
    mechanisms = ['FFCM2']

  phase_tools.thermo_model = get(ini_file, section, 'thermo', str)

  return mechanisms


#
def read_0D(ini_file, section) -> tuple[Out, tuple[list[str], list[str], np.ndarray, np.ndarray]]:
    # Opt
    EQ = get(ini_file, section, 'equilibrium', bool)
    ID = get(ini_file, section, 'ignition-delay', bool)
    TE = get(ini_file, section, 'time-evolution', bool)
    type = get(ini_file, section, 'type', str)
    if type is None: type='HP'

    Opt = Out(EQ, ID, TE, type)

    # Case setup (shortcut mode)
    case = get(ini_file, section, 'case', str)
    if case is not None:
        fuel_entry, oxi_entry, pressure, of, T = setup_case(case)
        fuel_specs = [fuel_entry]
        oxi_specs = [oxi_entry]
        fuel_specs.insert(0, str(T))
        oxi_specs.insert(0, str(T))
        return Opt, (case, fuel_specs, oxi_specs, pressure, of, T)

    # OF
    of = get(ini_file, section, 'of', np.ndarray)
    if of is None:
        of_law = get(ini_file, section, 'of-linear', np.ndarray)
        if of_law is None:
            of = np.array([0.0])
        else:
            of = np.linspace(of_law[0], of_law[1], int(of_law[2]))

    # Pressure
    pressure = get(ini_file, section, 'pressure', np.ndarray)
    if pressure is None:
        p_law = get(ini_file, section, 'pressure-linear', np.ndarray)
        if p_law is None:
            raise ValueError("Missing pressure or pressure-linear entry")
        pressure = np.linspace(p_law[0], p_law[1], int(p_law[2]))

    # Temperature
    T = get(ini_file, section, 'temperature', np.ndarray)
    if T is None:
        T_law = get(ini_file, section, 'temperature-linear', np.ndarray)
        if T_law is not None:
          T = np.linspace(T_law[0], T_law[1], int(T_law[2]))

    # Fuel
    fuel_entry = get(ini_file, section, 'fuel', str)
    if '{' not in fuel_entry:
        fuel_entry = '{' + fuel_entry + ':1.0}'

    # Oxidizer
    oxi_entry = get(ini_file, section, 'oxidizer', str)
    if '{' not in oxi_entry:
        oxi_entry = '{' + oxi_entry + ':1.0}'

    # Temperatures
    Tf = get(ini_file, section, 'fuel-T', float)
    if Tf is None:
        Tf = 100.0

    To = get(ini_file, section, 'oxidizer-T', float)
    if To is None:
        To = 90.170

    fuel_specs = [str(Tf), fuel_entry]
    oxi_specs = [str(To), oxi_entry]

    return Opt, (case, fuel_specs, oxi_specs, pressure, of, T)

def read_0D_te(ini_file, section):
  """
  Read the 0D time evolution parameters from the ini file.
  """
  # Number of steps
  nstep = get(ini_file, section, 'nstep', int)
  if nstep is None: nstep = 1000

  # Width
  tend = get(ini_file, section, 'tend', float)
  if tend is None: tend = 1.0

  return tend, nstep


def read_1D(ini_file, section):

  of = get(ini_file, section, 'of', np.ndarray)
  if of is None:
    of_law = get(ini_file, section, 'of-linear', np.ndarray)
    if of_law is None: return
    of = np.linspace(of_law[0], of_law[1], int(of_law[2]))

  pressure = get(ini_file, section, 'pressure', np.ndarray)

  fuel_specs = []
  fuel_entry = get(ini_file, section, 'fuel', str)
  if '{' not in fuel_entry: fuel_entry = '{'+fuel_entry+':1.0}'
  fuel_specs.append(fuel_entry)

  oxi_specs = []
  oxi_entry = get(ini_file, section, 'oxidizer', str)
  if '{' not in oxi_entry: oxi_entry = '{'+oxi_entry+':1.0}'
  oxi_specs.append(oxi_entry)

  Tf = get(ini_file, section, 'fuel-T', float)
  if Tf is None: Tf = 1

  To = get(ini_file, section, 'oxidizer-T', float)
  if To is None: To = 1

  fuel_specs.insert(0, str(Tf))
  oxi_specs.insert(0, str(To))

  mdot = get(ini_file, section, 'mdot', float)
  if mdot is None: mdot = 1.0

  width = get(ini_file, section, 'width', float)
  if width is None: width = 0.2

  return fuel_specs, oxi_specs, pressure, of, mdot, width
