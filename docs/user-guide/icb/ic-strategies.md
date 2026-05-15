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

## Multizone Combinations

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
