# BCB Boundary Condition Types

This page covers the full BC roster with reference tables and INI syntax for every type.

---

## Supported Names

| BC name | Requires input section | Notes |
|---|---|---|
| `null` | no | Empty/placeholder BC. |
| `axisymmetric` | no | Axisymmetric boundary. |
| `extrapolation` | no | Extrapolation boundary. |
| `connection` | no | Standard block-to-block connection marker. |
| `chimera` | no | Overset/chimera marker; interpolation info written in chimera payload. |
| `symmetry` | no | Symmetry boundary. |
| `periodic` | yes | Requires periodic setup keys (for example `faces`, optionally `blocks`). |
| `wall` | yes | Wall model depends on phase and provided keys. |
| `inlet` | yes | Inlet model is selected from provided keys. |
| `outlet` | no | Can be used directly by naming section `outlet`, or via `type = outlet`. |
| `manifold` | yes | Special manifold BC. |
| `srm` | yes | Solid rocket motor grain BC. |


| Category | BC names |
|---|---|
| Basic / geometric | `null`, `axisymmetric`, `extrapolation`, `symmetry` |
| Connectivity | `connection`, `chimera`, `periodic` |
| Flow / thermal | `wall`, `inlet`, `outlet` |
| Special | `manifold`, `srm` |

## INI Syntax

### `periodic`

```ini
[periodic_pair]
type = periodic
faces = 1 2
# optional
# blocks = 1 2
```

---

### `wall`

#### Gas / fluid phase

```ini
[wall_adiabatic]
type = wall
q = 0.0

[wall_isothermal]
type = wall
T = 1200.0

[wall_rad]
type = wall
T = 1200.0
qrad = 5000.0

[wall_rad_only]
type = wall
qrad = 5000.0
```

#### Solid phase

```ini
[wall_solid_T]
type = wall
T = 300.0

[wall_solid_q]
type = wall
q = 1000.0

[wall_solid_conv]
type = wall
hconv = 50.0
qrad  = 200.0
Tref  = 300.0

[wall_solid_rad]
type = wall
eps  = 0.9
Tref = 300.0

[wall_solid_conv_rad]
type = wall
hconv = 50.0
eps   = 0.9
Tref  = 300.0
```

Time-varying wall values:

```ini
[wall_solid_Ttime]
type = wall
T-time-file = wall_T.dat

[wall_solid_qtime]
type = wall
q-time-file = wall_q.dat
```

---

### `inlet`

#### Gas / fluid phase

```ini
[inlet_p0T0]
type  = inlet
p0    = 1.013e5
T0    = 300.0
alpha = 0.0
beta  = 0.0

[inlet_g_T0]
type  = inlet
g     = 1983.448
T0    = 269.0
alpha = 0.0
beta  = 0.0

[inlet_g_T]
type  = inlet
g     = 1983.448
T     = 269.0
alpha = 0.0
beta  = 0.0

[inlet_supersonic]
type  = inlet
mach  = 2.0
p0    = 1.013e5
T0    = 300.0
alpha = 0.0
beta  = 0.0

[inlet_p0T0_backpressure]
type  = inlet
p0    = 1.013e5
T0    = 300.0
p     = 0.8e5
alpha = 0.0
beta  = 0.0

[inlet_time_varying]
type      = inlet
time-file = inlet_transient.dat
# periodic = T   ; uncomment to loop the time series

[inlet_p0_timevarying]
type          = inlet
p0-time-file  = p0_transient.dat
T0            = 300.0
alpha         = 0.0
beta          = 0.0

[inlet_nozzle]
type = inlet
rt   = 8.0
psub = 10.0e5
psup = 20.0e5

# alternatively, provide area ratio and BCB computes rt, psub, psup automatically:
# Ae_At = 1.5
# p0    = 1.013e5
# T0    = 300.0
```

#### Dispersed phase

```ini
[dp_in]
type   = inlet
gp     = 345.0
Tp     = 450.0
Vp     = 100.0
alphap = 26.0
dp     = 0.01
```

---

### `outlet`

#### Gas / fluid phase

```ini
[outlet_main]
type = outlet
p    = 1.0
rf   = 1.0
```

---

### `manifold`

```ini
[manifold_link]
type  = manifold
block = 3
face  = 2
```

---

### `srm`

```ini
[grain]
type        = srm
eq-CEA-file = CEA.inp
pRef        = 4.829e6
a           = 0.0052
n           = 0.35
SF          = 1.0
rhoGrain    = 1750.0
```

## Next

- [Output Files](./output.md)