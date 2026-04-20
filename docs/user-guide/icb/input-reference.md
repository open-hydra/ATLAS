# ICB Input Reference

::: warning Work in progress
This page is being populated. See the [tutorials](/tutorials/icb/) for working examples.
:::

## File Format

ICB reads a standard INI file. Each section corresponds to one block.

## Global Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mesh-file` | string | — | Path to the mesh file |
| `output-dir` | string | `./` | Directory for output IC files |
| `phase-file` | string | — | Path to the GPB-generated phase property file |

## Block Parameters

| Key | Type | Description |
|-----|------|-------------|
| `strategy` | string | IC strategy (see [IC Strategies](./ic-strategies)) |
| `block` | integer | Block index |
| `pressure` | real | Initial static pressure (Pa) |
| `temperature` | real | Initial static temperature (K) |
| `velocity-x/y/z` | real | Velocity components (m/s) |

::: details Example — uniform ideal-gas IC

```ini
[global]
mesh-file = mesh.cgns
phase-file = fromATLAStoSolver/phase1.bin

[block-1]
strategy = uniform-ig
block = 1
pressure = 101325.0
temperature = 300.0
velocity-x = 0.0
velocity-y = 0.0
velocity-z = 0.0
```

:::
