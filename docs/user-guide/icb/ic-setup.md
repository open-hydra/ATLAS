# ICB Initial Condition Setup

This page describes how to build ICB input files:

- global tool parameters (`[ATLAS-Parameters]`);
- block-level setup (`[ICB-BlockN]`);
- phase-aware initialization fields;
- multizone setup with `zoneN` / `rangeN`;
- interpolation from previous solutions.

---

## File Structure

An ICB input file is a standard INI file with these sections:

1. **`[ATLAS-Parameters]`** - optional global options for ICB.
2. **`[ICB-BlockN]`** - one section per mesh block.
3. **Optional zone sections** - referenced from multizone blocks (`zone1 = ...`, `zone2 = ...`).

```ini
[ATLAS-Parameters]
IC-format = tec

[ICB-Block1]
type = homogeneous
p = 101325.0
T = 300.0
u = 0.0
v = 0.0
w = 0.0
```

### `[ATLAS-Parameters]` keys

| Key | Default | Description |
|-----|---------|-------------|
| `ICB-file` | `input.ini` | INI file used by ICB (when ICB is launched through ATLAS). |
| `IC-format` | `tec` | Output format for the initial field. Supports Tecplot and VTK variants (for example `tec`, `tec-binary`, `vtk`, `vtk-binary`). |

### `[ICB-BlockN]` keys (common)

| Key | Description |
|-----|-------------|
| `phase` | Space-separated phase names active in the block. If omitted, all phases are used. |
| `type` | Initialization mode. Common values are `homogeneous`, `variable`, `interpolation`, `nozzle`. |
| `direction` | Direction string for multizone ranges (`x,y,z,r,t,i,j,k`, including combinations). |
| `range` | Limits for the block/zone direction(s). |
| `zoneN` | Name of an auxiliary section used by multizone setup. |
| `rangeN` | Range associated with `zoneN`. |

---

## Homogeneous Initialization

Use constant scalar values for the whole block.

```ini
[ICB-Block1]
type = homogeneous
p = 101325.0
T = 300.0
u = 0.0
v = 0.0
w = 0.0
```

For ideal-gas blocks, `p0`/`T0` and `mach` are also supported.

## Variable Initialization (file-driven)

Use `<key>-file` with optional `<key>-direction` for 1-D mapped fields.

```ini
[ICB-Block1]
type = variable
T-file = T_profile.dat
T-direction = x
p = 101325.0
```

This is available for IG/RF/SP fields and is useful for profile-based starts.

## Nozzle Initialization (IG)

```ini
[ICB-Block1]
type = nozzle
p0 = 10.342
T0 = 555.56
nozzle-direction = dx
nozzle-threshold = 0.0
```

`nozzle-direction` accepts `dx` or `sx`.

## Interpolation Initialization

Interpolate from an existing solution on another mesh.

```ini
[ICB-Block1]
type = interpolation
old-solution = field.tec
old-block-id = 0
interpolation-law = outlaw
```

Optional interpolation extras:

- `old-species` (IG only, for species remapping);
- `theta` and `nz` when `interpolation-law = extrude`.

---

## Multizone Setup

A block can be partitioned into ranges, each pointing to a zone section.

```ini
[ICB-Block1]
direction = x
zone1 = state1
range1 = 0.0 0.005
zone2 = state2
range2 = 0.005 1.0

[state1]
type = homogeneous
p = 200000.0
T = 500.0

[state2]
type = homogeneous
p = 101325.0
T = 300.0
```

For angular ranges, `t` is read in degrees and converted internally.

## Notes

- If `type` is omitted, ICB defaults to `homogeneous`.
- If `old-solution` is present, ICB forces `type = interpolation`.
- Turbulence keys (`mit`, `kappa`, `omega`, `rhoRij`, `nrans`) are available for IG/RF.

## Next

- [IC Strategies](./ic-strategies.md)
