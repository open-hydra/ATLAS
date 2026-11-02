"""Index of the records of the CEA transport database (database/transport/CEApolynomials.yaml).

Every record names its species in `element`, as the files of NASA CEA write it (trans.inp, thermo.inp: Ar, SiCL4), and may list in
`aliases` other names of the same species (AR, the name in the Chemkin-style mechanism files and in burcat.yaml). GPB finds the record
of a species by its name, compared character by character with the names and the aliases of the file: names are never compared
without case, because NASA names that differ only in case are different species (CO and Co, CS and Cs, SN and Sn). Every name and
alias identifies one record.

The module imports neither Cantera nor the GPB configuration, so the index and its checks can be run on their own.
"""


class RecordError(ValueError):
    """A record of the CEA transport database that GPB cannot use; the message names the file, the record and what to change."""


def index_records(records, source):
    """Map every name and alias of the records read from the CEA transport database `source` (the path shown in the messages) to
    its record. Records are numbered from 1 in the order of the file.

    Raise RecordError if the file is not a list of records, a record is not a mapping, `element` is not a non-empty string,
    `aliases` (optional) is not a list of non-empty strings, or a name or alias appears twice in the file (two records with the
    same name, an alias repeated, an alias equal to a name).
    """
    if not isinstance(records, list):
        raise RecordError(f"{source}: the file must be a list of records")
    index, owner = {}, {}
    for i, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            raise RecordError(f"{source}: record {i}: the record must be a mapping (a yaml block with the key element)")
        name = record.get('element')
        if not isinstance(name, str) or not name:
            raise RecordError(f"{source}: record {i}: element must be a non-empty string, the species name in quotes "
                              f"(e.g. element: \"Ar\")")
        aliases = record.get('aliases', [])
        if not isinstance(aliases, list) or not all(isinstance(a, str) and a for a in aliases):
            raise RecordError(f"{source}: record {i} ({name}): aliases must be a list of non-empty strings in quotes "
                              f"(e.g. aliases: [\"AR\"])")
        for key in [name] + aliases:
            if key in owner:
                where = f"twice in record {i}" if owner[key] == i else f"in records {owner[key]} and {i}"
                raise RecordError(f"{source}: name or alias '{key}' appears {where}: every name and alias must identify one "
                                  f"record; remove the duplicate")
            owner[key] = i
            index[key] = record
    return index
