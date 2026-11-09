"""Finds the substances of `thermo = custom` (used by GPB and by the GUI; not meant to be edited).

It executes custom.py of database/thermo (the implementations that ship with ATLAS) and then custom.py of the case
directory, if there is one. Both make their substances as instances of the classes of custom_classes.py (this folder).
A substance made in the case directory with the name and category of one of database/thermo replaces it.
"""
import importlib.util
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))

LABEL = {"ideal-gas": "ideal-gas species", "condensed": "condensed material", "real-fluid": "real fluid"}

_cache = {}


class CustomError(Exception):
    """A custom.py that cannot be executed, or a substance that is not in it."""


class Library:
    """The substances found: registry {category: {name: substance}}, source {category: {name: file}}, and the
    substances of the case directory that replaced one of database/thermo."""

    def __init__(self):
        self.registry = {}
        self.source = {}
        self.replaced = []     # [(category, name, file)]
        self.files = []

    def names(self, category):
        return list(self.registry.get(category, {}))

    def get(self, category, name):
        substances = self.registry.get(category, {})
        if name not in substances:
            listed = ", ".join(substances) if substances else "none"
            raise CustomError(f"no {LABEL[category]} '{name}' in custom.py (database/thermo/custom.py or the case "
                              f"directory). Defined: {listed}")
        return substances[name]


def _execute(path, module_name, custom_classes):
    custom_classes.Substance._made_in_file = set()     # a name can be used once per category in one file
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as e:     # user code: report the line of the file, not a traceback of ours
        frames = [f for f in traceback.extract_tb(e.__traceback__) if os.path.abspath(f.filename) == path]
        line = f", line {frames[-1].lineno}" if frames else ""
        raise CustomError(f"{path}{line}: {type(e).__name__}: {e}") from None
    return module


def load(case_dir=None, refresh=False):
    """The Library for a case directory (the working directory by default); cached unless `refresh`."""
    case_dir = os.path.abspath(case_dir or os.getcwd())
    if not refresh and case_dir in _cache:
        return _cache[case_dir]
    if HERE not in sys.path[:1]:
        sys.path.insert(0, HERE)      # first, so that `from custom_classes import ...` is this folder's file
    import custom_classes
    registry = custom_classes.Substance.registry
    registry.clear()

    lib = Library()
    shipped = os.path.join(HERE, "custom.py")
    if os.path.isfile(shipped):
        _execute(shipped, "atlas_custom_database", custom_classes)
        lib.files.append(shipped)
    before = {c: dict(names) for c, names in registry.items()}
    for category, names in before.items():
        lib.source[category] = {n: shipped for n in names}

    local = os.path.join(case_dir, "custom.py")
    if os.path.isfile(local) and os.path.abspath(local) != shipped:
        _execute(local, "atlas_custom_case", custom_classes)
        lib.files.append(local)
        for category, names in registry.items():
            for name, substance in names.items():
                if before.get(category, {}).get(name) is not substance:
                    if name in before.get(category, {}):
                        lib.replaced.append((category, name, local))
                    lib.source.setdefault(category, {})[name] = local

    lib.registry = {c: dict(names) for c, names in registry.items()}
    _cache[case_dir] = lib
    return lib
