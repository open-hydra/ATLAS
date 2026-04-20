# STB Input Reference

::: warning Work in progress
This page is being populated. See `src/hydra-tools/STB/STB.f90` for the current parameter set.
:::

## File Format

STB reads a standard INI file.

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `geometry-file` | string | — | File containing the area distribution or contour points |
| `output-file` | string | `area.bin` | Output file for Hydra |
| `n-points` | integer | — | Number of axial stations |
| `area-inlet` | real | — | Inlet cross-sectional area (m²) |
| `area-throat` | real | — | Throat cross-sectional area (m²) |
| `area-outlet` | real | — | Outlet cross-sectional area (m²) |

::: details Example

```ini
[geometry]
geometry-file = contour.dat
output-file   = area_schedule.bin
n-points      = 200
```

:::
