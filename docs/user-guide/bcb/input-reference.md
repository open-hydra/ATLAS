# BCB Input Reference

::: warning Work in progress
This page is being populated. See the [tutorials](/tutorials/bcb/) for working examples in the meantime.
:::

## File Format

BCB reads a standard INI file. Each section corresponds to one boundary group.

## Global Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mesh-file` | string | — | Path to the mesh file |
| `output-dir` | string | `./` | Directory for output block files |

## Boundary Group Parameters

| Key | Type | Description |
|-----|------|-------------|
| `type` | string | BC type identifier (see [BC Types](./bc-types)) |
| `face` | string | Face tag from the mesh |
| `patch` | string | Connected patch tag (for connection BCs) |

::: details Example

```ini
[global]
mesh-file = mesh.cgns

[inlet]
type = inlet-supersonic
face = INLET

[outlet]
type = outlet-supersonic
face = OUTLET

[wall]
type = adiabatic-wall
face = WALL
```

:::
