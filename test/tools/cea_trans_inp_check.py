#!/usr/bin/env python3
"""Compare database/transport/CEApolynomials.yaml with the transport file of NASA CEA in this tree, lib/cea/data/trans.inp (no Cantera).

trans.inp is read with the formats of NASA CEA (source/database_compile.f90, subroutine utran): a record header (2a16, 2x, a1, i1, a1, i1)
with the names of one species (second name blank) or of a pair, the number of viscosity and of conductivity intervals, then one line
(1x, a1, 2f9.2, 4e15.8) per interval: V or C, the two bounds and the coefficients A, B, C, D (blanks inside a number are ignored, as in
the Fortran read: 0.10348180E 02 is 10.348180). CEApolynomials.yaml is read with yaml.safe_load, as GPB reads it.

Every record of CEApolynomials.yaml must match the record of the same species of trans.inp, with the same name character by character:
same number of viscosity and of conductivity intervals, same bounds and same coefficients (equal numbers). The records that ATLAS defines
itself (ATLAS_RECORDS) have no record in trans.inp. No name or alias may appear twice in CEApolynomials.yaml.
Exit status 1 on any difference; 77 when lib/cea/data/trans.inp is absent (no CEA submodule): CTest then reports the test as not run.
Usage: cea_trans_inp_check.py <ATLAS directory>   (Python >= 3.6, PyYAML)
"""
import os, sys
from collections import Counter
try:
    import yaml
except ImportError as e:
    sys.exit('cea_trans_inp_check: %s (run with ATLAS_PYTHON = the ATLAS conda interpreter)' % e)

ATLAS_RECORDS = {'H2ONassini', 'H2OFrolov', 'RP-1'}   # fits defined in ATLAS, absent from trans.inp

ATLAS = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('ATLASDIR', '')
YAML_FILE = os.path.join(ATLAS, 'database', 'transport', 'CEApolynomials.yaml')
TRANS_INP = os.path.join(ATLAS, 'lib', 'cea', 'data', 'trans.inp')


def fortran_real(field):
    """A real read with an E or D edit descriptor: blanks are ignored (the Fortran default for a formatted read)."""
    return float(field.replace(' ', '').replace('D', 'E').replace('d', 'e'))


def fortran_int(field):
    return int(field) if field.strip() else 0


def read_trans_inp(path):
    """{species name: {'V': [(T1, T2, [A, B, C, D])], 'C': [...], 'line': n}} for the records of one species (pairs skipped)."""
    with open(path, encoding='latin-1') as f:
        lines = f.read().split('\n')
    pure, i = {}, 1   # line 1 is the header of the file
    while i < len(lines):
        head = lines[i]
        if not head.strip():
            i += 1
            continue
        name1, name2 = head[0:16].strip(), head[16:32].strip()
        if name1 in ('end', 'LAST'):
            break
        nv, nc = fortran_int(head[35:36]), fortran_int(head[37:38])
        record = {'V': [], 'C': [], 'line': i + 1}
        for line in lines[i + 1:i + 1 + nv + nc]:
            line = line.ljust(80)
            fits = [fortran_real(line[20 + 15 * k:35 + 15 * k]) for k in range(4)]
            record['C' if line[1:2] == 'C' else 'V'].append((float(line[2:11]), float(line[11:20]), fits))
        if not name2:
            pure[name1] = record
        i += 1 + nv + nc
    return pure


if not os.path.isfile(TRANS_INP):
    print(f"cea_trans_inp_check: {TRANS_INP} not found (CEA submodule absent): the comparison is not run")
    sys.exit(77)

with open(YAML_FILE) as f:
    records = yaml.safe_load(f)
nasa = read_trans_inp(TRANS_INP)
errors, compared, numbers = [], 0, 0

names = [r.get('element') for r in records] + [a for r in records for a in r.get('aliases', [])]
for name, n in sorted(Counter(names).items(), key=lambda x: str(x[0])):
    if n > 1:
        errors.append(f"name or alias {name!r} appears {n} times in CEApolynomials.yaml")

for i, r in enumerate(records, start=1):
    name = r.get('element')
    if name in ATLAS_RECORDS:
        continue
    if name not in nasa:
        same = [n for n in nasa if isinstance(name, str) and n.lower() == name.lower()]
        errors.append(f"record {i} ({name!r}): no record of that name in trans.inp" + (f" (trans.inp writes {same[0]!r})" if same else ""))
        continue
    compared += 1
    for kind, key in (('V', 'viscosity'), ('C', 'conductivity')):
        mine, ref = r.get(key) or [], nasa[name][kind]
        if len(mine) != len(ref):
            errors.append(f"{name} {key}: {len(mine)} intervals, trans.inp:{nasa[name]['line']} {len(ref)}")
            continue
        for interval, (t1, t2, fits) in zip(mine, ref):
            # list equality: the same count (two bounds, four coefficients) and the same numbers
            bounds, coefficients = list(interval.get('temperature_range', [])), list(interval.get('coefficients', []))
            numbers += len(bounds) + len(coefficients)
            if bounds != [t1, t2] or coefficients != fits:
                errors.append(f"{name} {key} {interval.get('temperature_range')}: {interval.get('coefficients')}, "
                              f"trans.inp:{nasa[name]['line']} [{t1}, {t2}] {fits}")

for e in errors:
    print('ERROR ' + e)
print(f"{len(records)} records, {compared} compared with trans.inp ({numbers} numbers), {len(errors)} differences")
sys.exit(1 if errors else 0)
