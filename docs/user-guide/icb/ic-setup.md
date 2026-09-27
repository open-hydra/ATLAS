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
| `IC-format` | `tec` | Output format for the initial field: a family (`tec`, `tecplot`, `vtk`) with an optional mode (`binary`, `ascii`, `raw`) joined by `-`, a blank or `_` (`tec`, `tec-binary`, `vtk-binary`, `tecplot binary`, `vtk binary`, `tecplot-ascii`). Anything else is refused at start; `tec-binary` (a `.szplt` file) is refused at start by a build without TecIO. |

### `[ICB-BlockN]` keys (common)

| Key | Description |
|-----|-------------|
| `phase` | Space-separated phase names active in the block. If omitted, all phases are used. A phase listed by a `<name>-phase.txt` file and named in the `phase` key of no block is not written: ICB prints `[WARNING] key phase of section [ICB-Block*]: the phase of <name>-phase.txt is built by no block: no initial field is written for it (...)` and writes no `<name>-ic` file. |
| `type` | Initialization mode: `homogeneous` (default), `variable`, `interpolation`, `nozzle`; `multizone` for a block (the key `direction` alone also makes it multizone). Any other value stops ICB naming it. |
| `direction` | Direction string for multizone ranges (`x,y,z,r,t,i,j,k`, including combinations). |
| `range` | Limits for the block/zone direction(s). |
| `zoneN` | Name of an auxiliary section used by multizone setup. |
| `rangeN` | Range associated with `zoneN`. |

A block with zones takes its whole state from the zone sections: a state key left in the block
section (`y<species>`, `y<species>-file`, `p`, `T0`, `old-solution`, ...) is not inherited by the
zones and is refused (`[ERROR] key <k> of section [ICB-Block<n>]: a block with zones ([<zone>]) takes
its state from the zone sections, the key is not inherited: move it there (or remove it)`; a
`[WARNING]` under `strict-keys = F`). Values of enumerated keys (`type`, `nozzle-direction`,
`interpolation-law`, `IC-format`) are case-sensitive. A section header written twice (the INI reader
keeps the first and drops the second in silence) is refused when the two copies differ: `[ERROR]
section [<name>] of <deck>: declared twice (lines <n1> and <n2>), the second is ignored: merge them` (a
`[WARNING]` under `strict-keys = F`, and a `[WARNING]` only when no key names that section and it carries
no `ATLAS-`/`ICB-` prefix: a disabled block). Two copies with the same keys and the same values (blank
lines, comments and the order of the keys do not count; values are compared as written) give the
products of the deck with one copy: the same message is then a `[WARNING]` that ends with `(the two
copies hold the same keys and values)`, whatever `strict-keys`.

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

- `old-species` (IG only, for species remapping).

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

!!! note "A zone whose keys cover part of the block"
    The turbulence constants (`mit`, `kappa`, `omega`, `rhoRij`) of a zone are applied to the cells of
    its range only, exactly like `p`, `T` and the velocity: the cells outside it keep the field
    written by the other zones (ICB prints ` - build_IG_field: turbulence constants of this zone
    applied to n of N cells`). A zone that is meant to cover the whole block must have no `range`.
