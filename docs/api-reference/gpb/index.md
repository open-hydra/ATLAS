# GPB API Reference

Python package `GPB` — `src/hydra-tools/GPB/`

## Modules

| Module | Description |
|--------|-------------|
| [INI Parsers](./ini) | `ini.common`, `ini.ideal_gas`, `ini.condensed`, `ini.real_fluid`, `ini.equilibrium` |
| [Ideal Gas](./ideal-gas) | `ideal_gas.builder`, `ideal_gas.thermo`, `ideal_gas.transport`, `ideal_gas.chemistry`, `ideal_gas.io` |
| [Condensed](./condensed) | `condensed.builder` |
| [Real Fluid](./real-fluid) | `real_fluid.builder` |
| [Config](./config) | `config` — global constants |

## Entry Point

```python
# python -m GPB [--input-file input.ini] [--write-config-doc]
```

See `GPB/__main__.py`.
