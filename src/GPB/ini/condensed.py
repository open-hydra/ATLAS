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


def phase_header_word(type):
  """First word of <name>phase.txt: the vocabulary of src/common/read_phase.f90
  ('condensed-dispersed' | 'liquid-dispersed' | 'solid-dispersed' -> DP, 'solid-bulk' -> SP).
  'solid' is accepted as a synonym of 'solid-bulk'."""
  t = type.lower().strip()
  if t in ('solid', 'solid-bulk'):
    return 'solid-bulk'
  if t in ('condensed-dispersed', 'liquid-dispersed', 'solid-dispersed'):
    return t
  raise SystemExit(f"[ERROR] unknown condensed/solid phase type '{type}'")


# -----------------------------------------------------------------------
# Per-material solver models (P3). Validated here; written on the material
# line of <name>-phase.txt as key=value tokens once the readers accept them
# (P3.5). IGLOO owns the semantics; ATLAS validates only the six word keys.
# -----------------------------------------------------------------------

MATERIAL_WORD_KEYS = {'evaporation': ('d2-law', 'CEM', 'CEM-B', 'ASM', 'TC'),
                      'liquid-conduction': ('ITC', 'P2T'),
                      'interface': ('VLE', 'LK'),
                      'boiling': ('clamp', 'ZGR'),
                      'combustion': ('Beckstead',),
                      'solidification': ('on', 'off')}
MATERIAL_REAL_KEYS = ('alpha-e', 'k-liq', 'mu-liq', 'K-burn', 'n-burn', 'X-eff', 'beta-part',
                      'xi-cap', 'T-ign', 'q-comb', 'T-melt', 'h-fus', 'T-nuc', 'cp-solid')


def CP_read_material_models(ini_file, section, nmat):
  """Per-material solver keys: each key holds one value per `material` entry (a
  single value is broadcast to all materials). Returns tokens[i] = ['key=value',
  ...] for material i, only for the keys present in the section. Exits on a bad
  word, a non-numeric real, or a value count that is neither 1 nor nmat."""
  tokens = [[] for _ in range(nmat)]
  for key, allowed in MATERIAL_WORD_KEYS.items():
    vals = get(ini_file, section, key, list)
    if vals is None:
      continue
    vals = [str(v) for v in vals]
    if len(vals) == 1:
      vals = vals * nmat
    if len(vals) != nmat:
      raise SystemExit(f"[ERROR] [{section}] {key}: {len(vals)} value(s) for {nmat} material(s)")
    for i, v in enumerate(vals):
      if v not in allowed:
        raise SystemExit(f"[ERROR] [{section}] {key} = '{v}': expected one of {allowed}")
      tokens[i].append(f"{key}={v}")
  for key in MATERIAL_REAL_KEYS:
    # read as strings: PiNeR's np.ndarray path returns None on a non-numeric
    # value, which would silently drop a mistyped key
    vals = get(ini_file, section, key, list)
    if vals is None:
      continue
    try:
      vals = [float(v) for v in vals]
    except ValueError:
      raise SystemExit(f"[ERROR] [{section}] {key} = '{' '.join(vals)}': expected real number(s)")
    if len(vals) == 1:
      vals = vals * nmat
    if len(vals) != nmat:
      raise SystemExit(f"[ERROR] [{section}] {key}: {len(vals)} value(s) for {nmat} material(s)")
    for i, v in enumerate(vals):
      tokens[i].append(f"{key}={v:.10g}")
  return tokens
