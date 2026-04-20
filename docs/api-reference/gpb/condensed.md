# GPB Condensed Module

Source: `src/hydra-tools/GPB/condensed/`

::: warning Work in progress
:::

## `condensed.builder`

```python
from GPB.condensed.builder import build
build(phase_cfg)
```

Handles `type = condensed`, `condensed-dispersed`, and `solid` phases. Reads material properties from the ATLAS database or from the INI file directly and writes the binary property file.

### Supported `thermo` values

| Value | Description |
|-------|-------------|
| `Burcat` | Temperature-dependent $c_p$ from Burcat database |
| `SP-database` | Solid-phase database internal to ATLAS |
| `fixed` | Constant $c_p$, $\rho$ from INI keys |
