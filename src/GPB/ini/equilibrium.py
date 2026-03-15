from PiNeR import get
from reactants import Reactant, ReactantStore
from ini.common import convert2si

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
  from ast import literal_eval

  def quote_keys(dstr):
    import re
    # Quote unquoted keys including those with parentheses or special characters
    return re.sub(r'([{,]\s*)([^":\s][^:]*?)(\s*:)', r'\1"\2"\3', dstr)

  pressure_string = get(ini_file, section, 'eq-pressure', list)
  if pressure_string is None:
    return
  
  pressure = float(pressure_string[0])
  if len(pressure_string)==1:
    pressure_unit = 'bar'
  else:
    pressure_unit = pressure_string[1]
  si_pressure = convert2si(pressure, pressure_unit)

  fuel_entry = get(ini_file, section, 'eq-fuel', str)
  if '{' not in fuel_entry:
      fuel_entry = '{' + fuel_entry + ':1.0}'
  fuel_entry = quote_keys(fuel_entry)
  fuel_dict = literal_eval(fuel_entry)

  oxi_entry = get(ini_file, section, 'eq-oxidizer', str)
  if '{' not in oxi_entry:
      oxi_entry = '{' + oxi_entry + ':1.0}'
  oxi_entry = quote_keys(oxi_entry)
  oxi_dict = literal_eval(oxi_entry)

  of = get(ini_file, section, 'eq-of', float)

  Tf = get(ini_file, section, 'eq-fuel-T', float)
  if Tf is None: Tf = 100.0

  To = get(ini_file, section, 'eq-oxidizer-T', float)
  if To is None: To = 90.170

  store = ReactantStore()
  store.pressure = si_pressure
  store.mixture_ratio = of

  # Add fuel reactants
  for name, frac in fuel_dict.items():
      r = Reactant()
      r.build(f"{name}:{frac}", "F", Tf)
      store.reactants.append(r)

  # Add oxidizer reactants
  for name, frac in oxi_dict.items():
      r = Reactant()
      r.build(f"{name}:{frac}", "O", To)
      store.reactants.append(r)

  return store
