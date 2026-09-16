# BCB Boundary Condition Types

This page covers the full BC roster with reference tables and INI syntax for every type.

---

## Supported Names

| BC name | Requires input section | Notes |
|---|---|---|
| `null` | no | Empty/placeholder BC. |
| `axisymmetric` | no | Axisymmetric boundary. |
| `extrapolation` | no | Extrapolation boundary. |
| `connection` | no | Standard block-to-block connection marker; always resolved by face-center matching, also when `BC-chimera` is on. |
| `chimera` | no | Overset/chimera marker; interpolation info written in chimera payload. Only these faces are searched when `BC-chimera` is on. |
| `symmetry` | no | Symmetry boundary. |
| `periodic` | yes | Requires periodic setup keys (for example `faces`, optionally `blocks`). |
| `wall` | yes | Wall model depends on phase and provided keys. |
| `inlet` | yes | Inlet model is selected from provided keys. |
| `outlet` | no | Can be used directly by naming section `outlet`, or via `type = outlet`. |
| `manifold` | yes | Special manifold BC. |
| `gsi` | yes | Gas-surface interaction boundary. Covers solid-propellant burning, melting, pyrolysis and surface reactions; the variant is selected from the provided keys. |


| Category | BC names |
|---|---|
| Basic / geometric | `null`, `axisymmetric`, `extrapolation`, `symmetry` |
| Connectivity | `connection`, `chimera`, `periodic` |
| Flow / thermal | `wall`, `inlet`, `outlet` |
| Special | `manifold`, `gsi` |

!!! warning "Before using `connection` or `chimera`"
    Both take no input section, but they place real requirements on the mesh and
    have failure modes that are not reported at run time — in particular
    partially covered chimera facelets. Read
    [Block Connectivity](./connectivity.md) first.

## INI Syntax

Every BC below is selected by the `type` key of a named section, except the
keyword BCs, which are written straight onto the face line. Where a type has
several variants, BCB picks one from the **keys present in the section** — the
key set is the model selection, and the variant tables below give the exact
condition and the resulting output ID.

Output IDs are the numbers written into the BC file; see
[Output Files](./output.md#id-reference) for their payload layouts.

### Keyword BCs

`null`, `axisymmetric`, `extrapolation`, `symmetry`, `connection` and `chimera`
take **no input section**. Assign them directly to a face:

```ini
[BCB-Block1]
face1 = symmetry
face2 = extrapolation
face3 = connection
face4 = wall_hot        ; a named section, defined below
```

| Keyword | Output ID | Notes |
|---|---|---|
| `null` | `0` | Placeholder; no payload. |
| `axisymmetric` | `200` | No payload. |
| `symmetry` | `300` | No payload. |
| `extrapolation` | `400` | No payload. |
| `connection` | `101` / `103` | Resolved by face-centre matching during the connection pass. |
| `chimera` | `102` | Resolved by the overset donor search. |

`connection` and `chimera` carry no parameters but do constrain the mesh — read
[Block Connectivity](./connectivity.md) before using either.

---

### `periodic`

Pairs two faces so the solver treats them as periodic. The pairing is stored as
connection integers rather than as a numeric payload.

| Key | Required | Meaning |
|---|---|---|
| `faces` | **yes** | Source and destination face indices |
| `blocks` | no | Source and destination block indices; omit for a pair within one block |

```ini
[periodic_pair]
type  = periodic
faces = 1 2

[periodic_across_blocks]
type   = periodic
faces  = 1 2
blocks = 1 4
```

Output ID: `201`.

!!! warning "`faces` is silently required"
    If `faces` is missing, the section is skipped and **no periodic connection is
    built** — with no error and no diagnostic. The faces keep whatever BC they
    would otherwise have. `blocks` alone is not enough.

---

### `wall`

The wall model depends on the **phase** the block belongs to, and within a phase
on the keys provided.

#### Gas / fluid phase

| Variant | Selected when the section sets | Output ID |
|---|---|---|
| Prescribed heat flux | `q` (and neither `T` nor `qrad`) | `301` |
| Prescribed temperature | `T` (and neither `q` nor `qrad`) | `302` |
| Eulerian symmetry | anything else — the fallback | `300` |

| Key | Meaning |
|---|---|
| `q` | Wall heat flux |
| `T` | Wall temperature |
| `ks` | Roughness height (`0` = smooth wall) |
| `eps` | Wall emissivity |

```ini
[wall_adiabatic]
type = wall
q    = 0.0

[wall_isothermal]
type = wall
T    = 1200.0
ks   = 1.0e-5
eps  = 0.8
```

!!! warning "`qrad` is not a fluid-wall key"
    A fluid-phase `wall` accepts **either** `q` **or** `T`, never both and never
    together with `qrad`. Any other combination — including a section that sets
    `qrad` — falls through to the Eulerian-symmetry branch and is written as
    `id = 300`, with no diagnostic. Radiative coupling on a gas-side boundary
    belongs to [`gsi`](#gsi); `qrad` remains valid on a **solid-phase** wall.

#### Solid phase

The solid wall supports convective and radiative coupling, and time-varying
values through `*-time-file` keys.

| Variant | Selected when the section sets | Output ID |
|---|---|---|
| Heat flux | `q` or `q-time-file` (and neither `T` nor `qrad`) | `301` |
| Temperature | `T` or `T-time-file` (and neither `q` nor `qrad`) | `302` |
| Convection + radiative flux | `hconv` **and** `qrad` **and** `Tref` | `303` |
| Radiative exchange | `eps` **and** `Tref` | `304` |
| Convection + radiative exchange | `hconv` **and** `eps` **and** `Tref`, no `qrad` | `305` |

| Key | Meaning |
|---|---|
| `q`, `T` | Prescribed heat flux / temperature |
| `hconv` | Convective heat-transfer coefficient |
| `Tref` | Reference temperature for convective or radiative coupling |
| `qrad` | Radiative heat flux |
| `eps` | Wall emissivity |
| `q-time-file`, `T-time-file` | Time series replacing the corresponding scalar |

```ini
[wall_solid_T]
type = wall
T    = 300.0

[wall_solid_q]
type = wall
q    = 1000.0

[wall_solid_conv]
type  = wall
hconv = 50.0
qrad  = 200.0
Tref  = 300.0

[wall_solid_rad]
type = wall
eps  = 0.9
Tref = 300.0

[wall_solid_conv_rad]
type  = wall
hconv = 50.0
eps   = 0.9
Tref  = 300.0
```

Time-varying values:

```ini
[wall_solid_Ttime]
type        = wall
T-time-file = wall_T.dat

[wall_solid_qtime]
type        = wall
q-time-file = wall_q.dat
```

!!! warning "No fallback on the solid wall"
    Unlike the fluid wall, the solid wall has **no default branch**. A key set
    matching none of the five variants above leaves the BC id at `0`, so the face
    is written as `null` with no error. Note `304` needs `eps` *and* `Tref` —
    `eps` alone does not select it.

---

### `inlet`

The inlet model is chosen from the provided keys. The variants are tested in the
order below and the first match wins, so a section giving `p0`, `T0` **and** `p`
selects `407`, not `401`.

#### Gas / fluid phase

| Variant | Selected when the section sets | Output ID |
|---|---|---|
| Total conditions | `p0` **and** `T0`, no `p` | `401` |
| Total pressure from file | `p0-time-file` (`T0` also required) | `402` |
| Mass flux, total temperature | `g` **and** `T0` | `403` |
| Mass flux, static temperature | `g` **and** `T` | `404` |
| Supersonic | `mach` **and** (`p0` **and** `T0`) or (`p` **and** `T`) | `405` |
| Total conditions with back-pressure | `p0` **and** `T0` **and** `p` | `407` |
| Normal velocity | `un` **and** `T` | `408` |
| Full state from file | `time-file` | `410` |
| Injector nozzle | `Ae_At`, or `g` **and** `psub` **and** `psup` | `420` |

| Key | Meaning |
|---|---|
| `p0`, `T0` | Total (stagnation) pressure and temperature |
| `p`, `T` | Static pressure and temperature |
| `g` | Mass flux [kg m⁻² s⁻¹] |
| `un` | Normal velocity [m s⁻¹] |
| `mach` | Mach number |
| `h0` | Total enthalpy; for a single-species phase `T0` is derived from it |
| `alpha`, `beta` | Inflow direction angles |
| `rf` | Relaxation factor |
| `Ae_At` | Nozzle exit-to-throat area ratio (must be ≥ 1) |
| `psub`, `psup` | Subsonic / supersonic injector exit pressures |
| `time-file`, `p0-time-file` | Time series replacing the scalars |
| `periodic` | Loop a `time-file` series instead of holding the last value |

```ini
[inlet_p0T0]
type = inlet
p0   = 1.013e5
T0   = 300.0

[inlet_g_T0]
type = inlet
g    = 1983.448
T0   = 269.0

[inlet_g_T]
type = inlet
g    = 1983.448
T    = 269.0

[inlet_supersonic]
type = inlet
mach = 2.0
p0   = 1.013e5
T0   = 300.0

[inlet_backpressure]
type = inlet
p0   = 1.013e5
T0   = 300.0
p    = 0.8e5

[inlet_normal_velocity]
type = inlet
un   = 120.0
T    = 288.0
```

Time-varying inlets:

```ini
[inlet_time_varying]
type      = inlet
time-file = inlet_transient.dat
# periodic = T   ; uncomment to loop the time series

[inlet_p0_timevarying]
type         = inlet
p0-time-file = p0_transient.dat
T0           = 300.0
```

Injector nozzle — either give the area ratio and let BCB derive the rest, or
prescribe the exit pressures together with the mass flux:

```ini
[inlet_nozzle_arearatio]
type  = inlet
Ae_At = 1.5
p0    = 1.013e5
T0    = 300.0

[inlet_nozzle_explicit]
type = inlet
g    = 1983.448
psub = 10.0e5
psup = 20.0e5
```

With `Ae_At`, BCB solves the area–Mach relation for the subsonic and supersonic
branches using the mixture `gamma` from the phase composition, and derives
`psub`, `psup` and `g` from `p0` and `T0`.

!!! note "Direction defaults to normal"
    Omit `alpha` and `beta` and BCB writes the `normal,` sentinel, meaning
    injection along the face normal. Writing `alpha = 0.0` is **not** the same
    thing — it prescribes an explicit zero angle.

!!! note "Total conditions can come from CEA"
    When the section provides an equilibrium file (`eq-CEA-file`), `p0` and `T0`
    default to the CEA values if not given explicitly.

!!! warning "Unmatched key sets are a hard error"
    A gas inlet whose keys match none of the variants stops BCB with
    `insufficient or inconsistent inflow properties specified`. Unlike the walls,
    it does not fall through silently.

Turbulence keys (`mit`, `kappa`, `omega`, `rhoRij`, `nrans`) may be added to any
inlet and are appended to the payload after the mass fractions.

#### Dispersed phase

| Variant | Selected when the section sets | Output ID |
|---|---|---|
| Scaled to the gas phase | no `gp` | `401` |
| Mass flux and velocity | `gp` **and** a non-zero velocity magnitude | `402` |
| Mass flux, scaled velocity | `gp`, no velocity magnitude | `403` |

| Key | Meaning |
|---|---|
| `gp` | Particle mass flux |
| `Vp` | Velocity magnitude; or give `up`, `vp`, `wp` components and BCB computes it |
| `Tp` | Particle temperature |
| `krho`, `kV`, `kT` | Density / velocity / temperature scaling wrt the gas phase (variant `401`) |
| `alphap`, `betap` | Injection direction angles |
| `dp`, `rp`, `sigmap` | Particle diameter, radius and distribution width |
| `distribution` | Size-distribution law (`Dirac`, `Normal`, `LogNormal`, `RosinRammler`, or a file) |
| `ds` | Injection-point spacing [cm] |

```ini
[dp_in]
type   = inlet
gp     = 345.0
Tp     = 450.0
Vp     = 100.0
alphap = 26.0
dp     = 0.01

[dp_mult]
type = inlet
p1-gp = 10
p2-gp = 20
p1-dp = 0.01
p2-dp = 0.001

; p1 and p2 refer to phase name (prefix of phase.txt files).
```

!!! warning "Phase name requirements"
    For the dispersed phase, the phase name may be added in front of the entry name to assign a property to that phase. This is mandatory when multiple phases are injected together through the same boundary face.

---

### `outlet`

A pressure outflow. It needs no section when the defaults suffice — naming a
face `outlet` is enough — but a section lets you set the back-pressure and
relaxation factor.

| Key | Meaning |
|---|---|
| `p` | Static back-pressure |
| `rf` | Relaxation factor |

```ini
[BCB-Block1]
face2 = outlet          ; bare keyword, no section needed
```

```ini
[outlet_main]
type = outlet
p    = 1.0
rf   = 1.0
```

Output ID: `406` for a fluid phase, `400` for a dispersed phase.

---

### `manifold`

Draws its conditions from another block face rather than from prescribed values,
so one boundary can mirror the state of another.

| Key | Required | Meaning |
|---|---|---|
| `block` | yes | Source block index |
| `face` | yes | Source face index |

```ini
[manifold_link]
type  = manifold
block = 3
face  = 2
```

Output ID: `501`; the payload is the source `block, face` pair.

---

### `gsi`

Gas-surface interaction. One marker, five variants: BCB picks the variant from
the keys present in the section, so the key set *is* the model selection.

| Variant | Selected when the section sets | Output ID |
|---|---|---|
| [Solid propellant](#gsi-solid-propellant) | none of the combinations below (default fallback) | `502` |
| [Melting](#gsi-melting) | `cp` **and** `dh` **and** `T` **and** `qrad` | `503` |
| [Pyrolysis](#gsi-pyrolysis) | `pyrolysis-model` **and** `qrad`, no `surface-reactions` | `504` |
| [Surface reactions](#gsi-surface-reactions) | `surface-reactions` **and** `qrad`, no `pyrolysis-model` | `505` |
| [Pyrolysis + surface reactions](#gsi-pyrolysis-surface-reactions) | `pyrolysis-model` **and** `surface-reactions` **and** `qrad` | `506` |

The variants are tested in the order above and the first match wins.

!!! warning "Solid propellant is the fallback"
    A section matching none of the four model combinations is built as a
    propellant grain, and then fails on the missing `n`/`rhoGrain` checks rather
    than reporting the unrecognised key set. If you meant to configure a
    pyrolysis or ablation surface and see a burn-rate error, check that `qrad`
    is set — every variant except solid propellant requires it.

| Key | Meaning |
|---|---|
| `pyrolysis-model` | Pyrolysis model name — selects the pyrolysis variants |
| `surface-reactions` | Surface-reaction model name — selects the ablation variants |
| `qrad` | Radiative heat flux; required by every variant except solid propellant |
| `eps` | Surface emissivity |
| `cp` | Specific heat of the melting material |
| `T` | Melting temperature |
| `Ti` | Ignition (initial) temperature |
| `dh` | Heat of reaction (negative for an exothermic surface) |
| `a`, `n`, `pRef` | APN burn-rate law coefficients, `r = a (p/pRef)^n` |
| `rhoGrain` | Propellant grain density |
| `SF` | Geometric scale factor |
| `eq-CEA-file` | CEA equilibrium file supplying flame temperature and composition |
| `y<species>` | Injected species mass fractions |

#### Available models

| Key | Accepted values |
|---|---|
| `pyrolysis-model` | `HTPB`, `HDPB`, `PP` |
| `surface-reactions` | `bradley` |

Both default to `none`. The names are case-sensitive and an unknown value stops
BCB with the list of valid options.

#### `gsi` — Solid propellant

Grain burning with an APN burn-rate law, `r = a (p/pRef)^n`. The adiabatic flame
temperature and the injected composition come from the CEA equilibrium file.

```ini
[grain]
type        = gsi
eq-CEA-file = CEA.inp
pRef        = 4.829e6
a           = 0.0052
n           = 0.35
SF          = 1.0
rhoGrain    = 1750.0
```

`n` and `rhoGrain` are mandatory — BCB stops if either is left at `0`.
Turbulence keys (`mit`, `kappa`, `omega`, `rhoRij`, `nrans`) may be appended and
are written after the mass fractions.

#### `gsi` — Melting

Surface melting driven by a radiative heat load, with the injected composition
given by the `y<species>` keys.

```ini
[grain]
type = gsi
cp   = 1000.0
T    = 500.0
Ti   = 300.0
dh   = -500.0
qrad = 10000.0
yH2  = 0.3
yO2  = 0.7
```

All four of `cp`, `T`, `dh` and `qrad` must be present or the section falls back
to the solid-propellant variant. `Ti` and `eps` are optional and default to `0`.

#### `gsi` — Pyrolysis

A pyrolysing surface with no heterogeneous chemistry. The injected composition
is taken from the `y<species>` keys.

```ini
[grain]
type            = gsi
pyrolysis-model = HTPB
qrad            = 10000.0
yH2             = 0.3
yO2             = 0.7
```

#### `gsi` — Surface reactions

Heterogeneous surface chemistry (ablation). This is the only `gsi` variant that
writes **no** species mass fractions — the solver derives the products from the
surface model.

```ini
[grain]
type              = gsi
surface-reactions = bradley
qrad              = 1.0e6
```

#### `gsi` — Pyrolysis + surface reactions

Both mechanisms on the same face: pyrolysis gases injected with the prescribed
composition, plus heterogeneous surface chemistry.

```ini
[grain]
type              = gsi
pyrolysis-model   = HTPB
surface-reactions = bradley
qrad              = 1.0e6
eps               = 0.9
yH2               = 0.3
yO2               = 0.7
```

## Next

- [Block Connectivity](./connectivity.md)
- [Output Files](./output.md)