# IC Strategies

Full reference for initialization strategies recognised by ICB.

---

## Supported `type` Values

| `type` | Meaning | Typical phases |
|---|---|---|
| `homogeneous` | Uniform initialization in the selected block/range. | IG, RF, SP, DP |
| `variable` | File-backed/profile-based assignment using `<key>-file`. | IG, RF, SP |
| `interpolation` | Solution transfer from `old-solution` file. | IG, RF, SP, DP |
| `nozzle` | Nozzle-based initialization model. | IG |

If `type` is omitted, ICB defaults to `homogeneous`.

## Direct Assignment

| Strategy | `type` | Phase | When to use |
|----------|--------|-------|-------------|
| Homogeneous ideal gas | `homogeneous` | Ideal gas | Chamber or freestream starts with constant fields. |
| Homogeneous real fluid | `homogeneous` | Real fluid | High-pressure/cryogenic starts from one reference state. |
| Homogeneous condensed | `homogeneous` | Condensed (dispersed) | Equilibrium or vacuum starts for dispersed populations. |
| Homogeneous solid | `homogeneous` | Solid | Uniform initial wall/material temperature. |

Example (IG homogeneous):

```ini
[ICB-Block1]
type = homogeneous
p = 101325.0
T = 300.0
u = 0.0
v = 0.0
w = 0.0
```

## Profile-Based

| Strategy | `type` | Phase | When to use |
|----------|--------|-------|-------------|
| File-backed variable field | `variable` | IG, RF, SP | Non-uniform starts from measured/analytical profiles. |

Example:

```ini
[ICB-Block1]
type = variable
T-file = T_profile.dat
T-direction = x
p = 101325.0
```

A profile file holds one coordinate and one value per row. The coordinates must be monotone (a decreasing
column is read as the same rows in increasing order): a row that is not two numbers (a header without `#`,
a typo) is skipped with `[WARNING] table file ...`, and a coordinate column that turns back is refused with
`[ERROR] table file ...`.

### Species profiles

The mass fraction of a species can be a profile too: `y<species>-file`, with an optional
`y<species>-direction`, follows the rules of the scalar profiles above (a Tecplot field on the
block grid, or a two-column table `coordinate value` interpolated along the direction at the
cell centres) and makes the zone `variable`. In every cell of the zone the profile values take
the place of the constants `y<species>` of the same species; the composition of the cell must
then sum to 1: a deviation `|1 - sum y|` up to 1e-3 is renormalised with one WARNING per zone,
a larger one stops ICB with an ERROR; both messages name the block and the deck section
(`(section [mix])`), the ERROR also the first offending cell. ICB also stops on a profile of a species the phase does
not declare, on a profile given next to the constant of the same species, on a direction without
a file and on a profile inside an interpolation zone (its composition comes from the old
solution). The species without a key keep 1e-20.

```ini
[ICB-Block1]
direction = x
zone1 = mix
range1 = 0.0 1.0

[mix]
type = variable
p = 101325.0
T = 300.0
yH2-file = yH2.dat
yH2-direction = x
yO2 = 0.25
yN2-file = yN2.dat
yN2-direction = x
```

Details of the composition rule and of the profile files:

- the tolerance carries a margin of 1e-12, so a decimal sum of exactly `1 - 1e-3` (for example
  `yO2 = 0.249`, `yN2 = 0.75`) is renormalised, not refused; a deviation up to 1e-12 (binary
  rounding of decimal constants such as `0.233 + 0.767`) is renormalised without a message;
- a negative profile value down to `-1e-3` is set to 0 with its own WARNING (number of cells and
  smallest value) and counts in the deviation; below `-1e-3` ICB stops;
- a table is interpolated at every cell centre of the block, also outside the zone range: it must
  cover the whole block along its direction, and its first coordinate must lie below the first
  cell centre (a centre equal to the first coordinate is reported as outside the file data range);
  its rows follow the rules of the profile files above (monotone coordinates, a row that is not two
  numbers skipped with a WARNING);
- a Tecplot field gives every cell the value of the nearest cell of the file, taken from the first
  cell-centred variable of the file (one file per species);
- a profile in a `nozzle` zone makes the zone `variable` with a WARNING: the nozzle law is not
  applied (the same holds for the scalar profiles `T-file`, `p-file`, ...).

## Nozzle Initialization

| Strategy | `type` | Phase | When to use |
|----------|--------|-------|-------------|
| De Laval nozzle | `nozzle` | Ideal gas | Cold-start of nozzle/plenum configurations to reduce startup transients. |

Example:

```ini
[ICB-Block1]
type = nozzle
p0 = 10.342
T0 = 555.56
nozzle-direction = dx
nozzle-threshold = 0.0
```

## Interpolation

| Strategy | `type` | Phase | When to use |
|----------|--------|-------|-------------|
| Interpolate old solution | `interpolation` | Any | Mesh refinement studies, remeshing, or projection from previous runs. |

Example:

```ini
[ICB-Block1]
type = interpolation
old-solution = field.tec
old-block-id = 0
interpolation-law = outlaw
```

Optional keys:

- `old-species` for ideal-gas species remapping.
- `theta`, `nz` when using `interpolation-law = extrude`.
`interpolation-law = extrude` revolves a one-cell source (a pure-2D x-r solution or a one-cell
wedge) about the x axis into a 3D sector of `theta` degrees (default 90) in `nz` cells (default 4):
the sector starts at the source plane (azimuth 0) and turns towards +z, every field is copied onto
each cell of the sector, and the velocity (and, under the Reynolds-stress model, the stresses) is
turned by the azimuth of the cell. Each target cell then takes the nearest cell of the revolved
source. On a target revolved with the same cells this is the field of `index`; unlike `index`, the
target may have another resolution. The target mesh must be 3D. `theta` and `nz` are read with
`extrude` only (a `[WARNING]` says so when they are given with another law).

## Multizone Combinations

Every cell of every block must be written by a zone, for every phase of the block. Each writer
records the cells it assigns: the cells of its range (an `interpolation` zone too: it writes its
range only, like every other zone type), the plenum rows of a `nozzle` zone, every cell of the block
for the dispersed phase. A cell that no zone wrote stops ICB (`[ERROR] build_IC block <b>, <type> phase <name>: <n> of <N> cells are initialised by no zone (first cell (i,j,k))`, followed by the cells written after each zone) instead of reaching the IC file with the content of unset memory. Under an omega turbulence model (k-omega, Reynolds stresses) the turbulence bands that no zone sets are refused in the same way; under SA they are reported with a `[WARNING]`.
`range<n>` holds one pair `low high` per letter of `direction` (six values for `xyz`); the letters are
written in the order x, y, z, r, t, i, j, k; an index letter (`i`, `j`, `k`) ranges cell indices
(`range1 = 1 4` = the cells 1 to 4 along that index). A `zone<n>` after a missing index is never read
(ERROR under strict-keys, WARNING otherwise), and `type = multizone` needs `direction`.
ICB can combine different states inside one block through `zoneN`/`rangeN` with a block-level `direction`.

```ini
[ICB-Block1]
direction = x
zone1 = state1
range1 = 0.0 0.02
zone2 = state2
range2 = 0.02 0.10

[state1]
type = homogeneous
p = 200000.0
T = 500.0

[state2]
type = interpolation
old-solution = field.tec
```
