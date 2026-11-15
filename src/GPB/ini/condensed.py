import numpy as np
from PiNeR import get
from ini.common import get_integer_kelvin, check_kelvin_range

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
  if thermo is not None:
    thermo = thermo.split(';')[0].strip()   # an inline comment stays in the value, as for type and modeling
  if thermo == 'SP-database':   # the former name of the materials of sp_custom.py, now those of custom.py
    print(f"[WARNING] [{section}] thermo = SP-database is deprecated: write thermo = custom")
    thermo = 'custom'
  if thermo is not None and thermo not in ('NASA7', 'NASA9', 'Burcat', 'custom'):
    raise SystemExit(f"[ERROR] [{section}] thermo = {thermo}: expected NASA7, NASA9, Burcat or custom")

  T1 = get_integer_kelvin(ini_file, section, 'Tmin', 1)
  T2 = get_integer_kelvin(ini_file, section, 'Tmax', 5000)
  check_kelvin_range(section, T1, T2)

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
# Per-material solver models. The material line of <name>phase.txt carries
# the WORD of each model (evaporation=CEM, combustion=Beckstead, cap=constant)
# and, as key=value tokens, the constants of the models that have no kind in
# MODEL_KINDS yet. The constants of a kind go to <name>models.txt, one row
# per material and kind: '<material> <kind> <model> key=value ...'.
# The solvers own the semantics; ATLAS validates the words and which model
# reads which constant.
# -----------------------------------------------------------------------

MATERIAL_WORD_KEYS = {'evaporation': ('d2-law', 'CEM', 'CEM-B', 'ASM', 'TC'),
                      'liquid-conduction': ('ITC', 'P2T'),
                      'interface': ('VLE', 'LK'),
                      'boiling': ('clamp', 'ZGR'),
                      'combustion': ('Beckstead', 'direct', 'none'),
                      'solidification': ('on', 'off')}
MATERIAL_REAL_KEYS = ('alpha-e', 'k-liq', 'mu-liq', 'T-melt', 'h-fus', 'T-nuc', 'cp-solid')

# kind -> (the section key that names its model, the model when that key is absent, {model: the constants it reads}).
# A later kind is one more entry here: the file and its readers dispatch on the kind.
MODEL_KINDS = {
  'combustion': ('combustion', None,
                 {'Beckstead': ('K-burn', 'n-burn', 'X-eff', 'beta-part', 'T-ign', 'q-comb', 'd-stop', 'd-burnout',
                                'd-smoke'),
                  'direct': ('T-burn', 'q-comb', 'd-stop', 'd-burnout', 'd-smoke')}),
  'cap': ('xi-law', 'constant',
          {'constant': ('xi-cap', 'xi-ox0', 'product', 'residue', 'd-residue'),
           'Gallier21': ('xi-ox0', 'product', 'residue', 'd-residue')}),
}
# The constants that are words, with the value that stands for "not given" (the reals: 0).
MODEL_WORD_CONSTANTS = {'product': 'none', 'residue': 'off'}
MODEL_WORD_VALUES = {'residue': ('on', 'off')}


def _per_material(ini_file, section, key, nmat):
  """A per-material key as strings: (None, False) when absent, else (one value per material, explicit), explicit
  being False when a single value was broadcast to several materials."""
  vals = get(ini_file, section, key, list)
  if vals is None:
    return None, False
  vals = [str(v) for v in vals]
  explicit = len(vals) == nmat
  if len(vals) == 1:
    vals = vals * nmat
  if len(vals) != nmat:
    raise SystemExit(f"[ERROR] [{section}] {key}: {len(vals)} value(s) for {nmat} material(s)")
  return vals, explicit


def CP_read_material_models(ini_file, section, nmat):
  """Per-material solver keys: each key holds one value per `material` entry (a
  single value is broadcast to all materials). Returns tokens[i] = ['key=value',
  ...] for material i, only for the keys present in the section. Exits on a bad
  word, a non-numeric real, or a value count that is neither 1 nor nmat. The
  constants of the kinds of MODEL_KINDS are not tokens: CP_read_model_rows."""
  tokens = [[] for _ in range(nmat)]
  for key, allowed in MATERIAL_WORD_KEYS.items():
    vals, _ = _per_material(ini_file, section, key, nmat)
    if vals is None:
      continue
    for i, v in enumerate(vals):
      if v not in allowed:
        raise SystemExit(f"[ERROR] [{section}] {key} = '{v}': expected one of {allowed}")
      tokens[i].append(f"{key}={v}")
  for key in MATERIAL_REAL_KEYS:
    # read as strings: PiNeR's np.ndarray path returns None on a non-numeric
    # value, which would silently drop a mistyped key
    vals, _ = _per_material(ini_file, section, key, nmat)
    if vals is None:
      continue
    try:
      vals = [float(v) for v in vals]
    except ValueError:
      raise SystemExit(f"[ERROR] [{section}] {key} = '{' '.join(vals)}': expected real number(s)")
    for i, v in enumerate(vals):
      tokens[i].append(f"{key}={v:.10g}")
  return tokens


def CP_read_model_rows(ini_file, section, names, groups, tokens):
  """The rows of <name>models.txt, (material, kind, model, ['key=value', ...]), and the tokens with the word of each
  kind that has no word key of its own on the line (cap=<law>; combustion=<model> is a token already).
  A constant goes in the row of each material whose model reads it. Where the model does not read it, a single value
  given for all the materials is not written for that one, and an entry of a per-material list must be the "not
  given" value (0, none, off), else GPB stops; a constant that no material's model reads stops GPB too. A material
  that names no model of a kind whose key is absent (combustion: the solver's section decides) gets its constants
  under the model '-'. A material with combustion = none gets no row, and neither does a combustion product (the
  material `product` names): it is a material of the phase with 0 groups, never injected."""
  nmat = len(names)
  given = {}                                             # constant -> (one value per material, explicit)
  for kind, (word_key, default, models) in MODEL_KINDS.items():
    for key in (k for keys in models.values() for k in keys):
      if key in given:
        continue
      vals, explicit = _per_material(ini_file, section, key, nmat)
      if vals is None:
        continue
      if key in MODEL_WORD_VALUES:
        for v in vals:
          if v not in MODEL_WORD_VALUES[key]:
            raise SystemExit(f"[ERROR] [{section}] {key} = '{v}': expected one of {MODEL_WORD_VALUES[key]}")
      elif key not in MODEL_WORD_CONSTANTS:
        try:
          vals = [f"{float(v):.10g}" for v in vals]
        except ValueError:
          raise SystemExit(f"[ERROR] [{section}] {key} = '{' '.join(vals)}': expected real number(s)")
      given[key] = (vals, explicit)

  def null(key, v):
    return v == MODEL_WORD_CONSTANTS[key] if key in MODEL_WORD_CONSTANTS else float(v) == 0.0

  products = sorted(set(v for v in given.get('product', ([], False))[0] if v != 'none'))
  for p in products:
    if p not in names:
      raise SystemExit(f"[ERROR] [{section}] product = {p}: not a material of this phase ({' '.join(names)})")
    i = names.index(p)
    if int(groups[i]) != 0:
      raise SystemExit(f"[ERROR] [{section}] product = {p}: a combustion product is never injected: give it 0 groups "
                       f"(groups holds {int(groups[i])} for it)")
    tokens[i] = [t for t in tokens[i] if not t.startswith('combustion=')]
  burn, _ = _per_material(ini_file, section, 'combustion', nmat)
  inert = [m in products or (burn is not None and burn[i] == 'none') for i, m in enumerate(names)]

  rows = []
  for kind, (word_key, default, models) in MODEL_KINDS.items():
    words, _ = _per_material(ini_file, section, word_key, nmat)
    union = [k for keys in models.values() for k in keys]
    union = [k for n, k in enumerate(union) if k not in union[:n]]
    model = []                    # per material: a model, '-' (none named: the solver's section decides), None (no row)
    for i, m in enumerate(names):
      w = words[i] if words is not None else default
      if inert[i]:
        w = None
      elif w is not None and w not in models:
        raise SystemExit(f"[ERROR] [{section}] {word_key} = '{w}': expected one of {tuple(models)}")
      elif kind == 'cap' and w != 'Gallier21' and not any(k in given and not null(k, given[k][0][i]) for k in union):
        w = None                                         # no cap is asked for this material
      elif w is None:
        w = '-'
      model.append(w)
    for k in union:
      if k not in given:
        continue
      vals, explicit = given[k]
      readers = [i for i in range(nmat) if model[i] == '-' or (model[i] is not None and k in models[model[i]])]
      for i, m in enumerate(names):
        if i in readers or not explicit or null(k, vals[i]):
          continue
        who = (f"{word_key} = {model[i]} reads {', '.join(models[model[i]])}" if model[i] is not None else
               'a combustion product reads no constant' if m in products else 'combustion = none reads no constant')
        raise SystemExit(f"[ERROR] [{section}] {k} = {vals[i]} for material {m}: {who}; in a list, give "
                         f"{MODEL_WORD_CONSTANTS.get(k, '0')} for this material")
      if not readers and any(not null(k, v) for v in vals):
        raise SystemExit(f"[ERROR] [{section}] {k} = {' '.join(vals) if explicit else vals[0]}: no material of this "
                         f"phase names a model that reads it ({'; '.join(f'{word_key} = {mo}: {chr(32).join(ks)}' for mo, ks in models.items())})")
    for i, m in enumerate(names):
      if model[i] is None:
        continue
      items = [f"{k}={given[k][0][i]}" for k in (union if model[i] == '-' else models[model[i]]) if k in given]
      if kind != word_key:
        tokens[i].append(f"{kind}={model[i]}")
      if items:
        rows.append((i, m, kind, model[i], items))
  rows.sort(key=lambda r: r[0])                          # the materials in the phase's order, the kinds in MODEL_KINDS'
  return tokens, [r[1:] for r in rows]


def CP_read_psat_pairs(ini_file, section, material_names):
  """Optional saturation-pressure pairs: `psat-vapour` names the vapour species of the loaded thermo database
  (`none` skips a material), `psat-liquid` the liquid species (default: the material name); one value per
  material, a single value is broadcast. None when psat-vapour is absent, else [(liquid, vapour) or None]
  aligned with material_names."""
  vapour = get(ini_file, section, 'psat-vapour', list)
  liquid = get(ini_file, section, 'psat-liquid', list)
  if vapour is None:
    if liquid is not None:
      raise SystemExit(f"[ERROR] [{section}] psat-liquid is set without psat-vapour")
    return None
  nmat = len(material_names)
  if liquid is None:
    liquid = list(material_names)
  if len(liquid) == 1:
    liquid = liquid * nmat
  if len(vapour) == 1:
    vapour = vapour * nmat
  for key, vals in (('psat-vapour', vapour), ('psat-liquid', liquid)):
    if len(vals) != nmat:
      raise SystemExit(f"[ERROR] [{section}] {key}: {len(vals)} value(s) for {nmat} material(s)")
  return [None if v.lower() == 'none' else (l, v) for l, v in zip(liquid, vapour)]


def CP_read_particle_mechanism(ini_file, section):
  """Optional stem of the reaction file of a dispersed phase: <stem>.yaml of the case directory, else of
  database/particle-combustion/."""
  stem = get(ini_file, section, 'particle-mechanism', str)
  if stem is None:
    return None
  stem = stem.split(';')[0].strip()      # an inline comment stays in the value, as for thermo
  return stem or None


def CP_read_enthalpy_datum(ini_file, section, nmat):
  """Optional `h0` [J/kg]: enthalpy of each fixed-cp material at 298.15 K (one value per material; a single
  value is broadcast). None when absent -> the Enthalpy column stays the relative cp*T."""

  # read as strings: PiNeR's np.ndarray path returns None on a non-numeric value, which
  # would turn a mistyped h0 into "no h0" and silently write the relative cp*T column
  vals = get(ini_file, section, 'h0', list)
  if vals is None:
    return None
  try:
    h0 = np.asarray([float(v) for v in vals])
  except ValueError:
    raise SystemExit(f"[ERROR] [{section}] h0 = '{' '.join(vals)}': expected real number(s)")
  if h0.size == 1:
    h0 = np.repeat(h0, nmat)
  if h0.size != nmat:
    raise SystemExit(f"[ERROR] [{section}] h0: {h0.size} value(s) for {nmat} material(s)")
  return h0


def CP_read_per_material(ini_file, section, key, nmat):
  """Optional real key with one value per `material` entry (a single value is broadcast). None when absent;
  exits on a non-numeric value or on a count that is neither 1 nor nmat."""
  vals = get(ini_file, section, key, list)
  if vals is None:
    return None
  try:
    vals = [float(v) for v in vals]
  except ValueError:
    raise SystemExit(f"[ERROR] [{section}] {key} = '{' '.join(vals)}': expected real number(s)")
  if len(vals) == 1:
    vals = vals * nmat
  if len(vals) != nmat:
    raise SystemExit(f"[ERROR] [{section}] {key}: {len(vals)} value(s) for {nmat} material(s)")
  return vals
