# GPB Real-Fluid Module

Source: `src/hydra-tools/GPB/real_fluid/`

::: warning Work in progress
:::

## `real_fluid.builder`

```python
from GPB.real_fluid.builder import build
build(phase_cfg)
```

Generates a 2-D $(p, h)$ lookup table for the specified pure fluid over the range $[p_\text{min}, p_\text{max}] \times [T_\text{min}, T_\text{max}]$ (converted to enthalpy bounds internally).

### EOS Backend Selection

| `model` value | Backend |
|---------------|---------|
| `coolprop` (default) | CoolProp Python interface |
| `redlich-kwong` | Internal analytic EOS |
| `peng-robinson` | Internal analytic EOS |

### Grid Parameters

| Key | Default | Description |
|-----|---------|-------------|
| `NP` | 200 | Number of pressure points |
| `NH` | 200 | Number of enthalpy points |
