#!/usr/bin/env python3
"""Check the index of the CEA transport records (src/GPB/cea_transport_records.py) without Cantera.

1. Lookup on the database of this tree (database/transport/CEApolynomials.yaml, read with yaml.safe_load as GPB reads it): a name
   finds the record of its species by the name or an alias, character by character, and nothing else: Ar and AR -> Ar, He and HE -> He,
   Ne and NE -> Ne, SiCL4 and SICL4 -> SiCL4, CO -> CO, N2 -> N2; ar, Co (cobalt, not carbon monoxide) and SiCl4 -> no record.
2. Refusals: lists of records built here that GPB must refuse, each with its message (records numbered from 1): a file that is not a
   list, a record that is not a mapping, element missing, empty or not a string (NO written without quotes reads as false), aliases
   given as a bare string or with an empty name, two records with the same name, an alias in two records, an alias equal to the name
   of another record, an alias equal to the name of its own record. A valid list is accepted, every name and alias once.
Exit status 1 on any failure.   Usage: cea_transport_records_check.py <ATLAS directory>   (Python >= 3.6, PyYAML)
"""
import os, sys
try:
    import yaml
except ImportError as e:
    sys.exit('cea_transport_records_check: %s (run with ATLAS_PYTHON = the ATLAS conda interpreter)' % e)

ATLAS = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('ATLASDIR', '')
sys.path.insert(0, os.path.join(ATLAS, 'src', 'GPB'))
from cea_transport_records import index_records, RecordError  # noqa: E402

SOURCE = 'database/transport/CEApolynomials.yaml'
failures = []


def check(ok, text):
    print(('PASS ' if ok else 'FAIL ') + text)
    if not ok:
        failures.append(text)


# 1. lookup on the database of the tree
with open(os.path.join(ATLAS, SOURCE)) as f:
    index = index_records(yaml.safe_load(f), SOURCE)
LOOKUP = {'Ar': 'Ar', 'AR': 'Ar', 'ar': None, 'He': 'He', 'HE': 'He', 'Ne': 'Ne', 'NE': 'Ne', 'SiCL4': 'SiCL4', 'SICL4': 'SiCL4',
          'SiCl4': None, 'CO': 'CO', 'Co': None, 'N2': 'N2'}
for name, expected in LOOKUP.items():
    record = index.get(name)
    found = None if record is None else record['element']
    check(found == expected, f"lookup {name!r}: record {found!r} (expected {expected!r})")


# 2. refusals
def rec(name, aliases=None):
    r = {'element': name, 'viscosity': [], 'conductivity': []}
    if aliases is not None:
        r['aliases'] = aliases
    return r


DUPLICATE = "every name and alias must identify one record; remove the duplicate"
REFUSED = [
    ('file not a list', {'element': 'Ar'}, f"{SOURCE}: the file must be a list of records"),
    ('record not a mapping', [rec('He'), 'Ar'], f"{SOURCE}: record 2: the record must be a mapping (a yaml block with the key element)"),
    ('element missing', [{'viscosity': [], 'conductivity': []}], f"{SOURCE}: record 1: element must be a non-empty string"),
    ('element empty', [rec('He'), rec('')], f"{SOURCE}: record 2: element must be a non-empty string"),
    ('element not a string (NO without quotes)', [rec(False)], f"{SOURCE}: record 1: element must be a non-empty string"),
    ('aliases as a bare string', [rec('Ar', 'AR')], f"{SOURCE}: record 1 (Ar): aliases must be a list of non-empty strings"),
    ('aliases with an empty name', [rec('Ar', [''])], f"{SOURCE}: record 1 (Ar): aliases must be a list of non-empty strings"),
    ('two records with the same name', [rec('Ar'), rec('He'), rec('Ar')],
     f"{SOURCE}: name or alias 'Ar' appears in records 1 and 3: {DUPLICATE}"),
    ('an alias in two records', [rec('Ar', ['AR']), rec('Kr', ['AR'])],
     f"{SOURCE}: name or alias 'AR' appears in records 1 and 2: {DUPLICATE}"),
    ('an alias equal to the name of another record', [rec('Ar'), rec('Kr', ['Ar'])],
     f"{SOURCE}: name or alias 'Ar' appears in records 1 and 2: {DUPLICATE}"),
    ('an alias equal to the name of its own record', [rec('Ar', ['Ar'])],
     f"{SOURCE}: name or alias 'Ar' appears twice in record 1: {DUPLICATE}"),
]
for label, records, message in REFUSED:
    try:
        index_records(records, SOURCE)
        check(False, f"{label}: accepted (expected the message {message!r})")
    except RecordError as e:
        check(str(e).startswith(message), f"{label}: {e}")

valid = index_records([rec('Ar', ['AR']), rec('He', ['HE']), rec('N2')], SOURCE)
check(sorted(valid) == ['AR', 'Ar', 'HE', 'He', 'N2'] and valid['AR'] is valid['Ar'],
      f"valid records accepted: names and aliases {sorted(valid)}")

print(f"{len(failures)} failures")
sys.exit(1 if failures else 0)
