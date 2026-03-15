def build(inifile, section):
    """Lazy-import builder to avoid requiring CoolProp when not used."""
    from .builder import _build
    _build(inifile, section)
