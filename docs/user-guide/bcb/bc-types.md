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

Units: every value is SI (Pa, K, J/kg, kg m⁻² s⁻¹ for `g`, m/s). The one exception is the
`p0-time-file` series of BC `402`, whose values are in **bar**, as the solvers read them (`p0` in the
same section is in Pa).

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
| `axisymmetric` | `200` | No payload. A named section may let a dispersed phase out through the axis or mirror it there, see [Dispersed-phase override on the axis](#dispersed-phase-override-on-the-axis). |
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

A wall section that gives more than one of `q`, `T`, `qrad` is written as BC 300 (Eulerian symmetry, no
thermal condition) with a WARNING; a key of another family on a wall (`p0`, `T0`, `g`, `mach`, ...) has no
field in a 3xx record and is reported as ignored (WARNING).


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
    together with `qrad`. Any other combination falls through to the
    Eulerian-symmetry branch and is written as `id = 300`: two or more of `q`,
    `T`, `qrad` with the WARNING above, `qrad` alone (or none of the three) with
    no diagnostic. Radiative coupling on a gas-side boundary belongs to
    [`gsi`](#gsi); `qrad` remains valid on a **solid-phase** wall.

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

A solid-phase wall whose keys select none of these records (for example `q` and `T` together, or `hconv`
without `Tref`) gets no wall record: its faces are written with BC id 0, as upstream writes them, with a
WARNING that names the section and the keys given.

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

The inlet model is chosen from the provided keys. BCB first looks at the injector
selectors, whatever else the section contains: a non-zero `a1-a3` selects `421`
(which then refuses every other selector, see below), and `Ae_At`, or the complete
`g`, `psub`, `psup` trio, selects `420` (`420` refuses `alpha`/`beta`, `p0-time-file`
and `time-file`). An incomplete trio (`g` with only one of `psub`/`psup`) and `g`
next to an explicit `p0` without the trio are refused (`g, psub and psup must be
given together`; `g together with an explicit p0 selects neither the mass-flux inlet
(403: g, T0) nor the nozzle (420: g, psub, psup)`): `g` with `T0` and no `p0` is the
mass-flux inlet `403`. Only when neither selector applies are the remaining variants
tested in the order below, the first match winning, so a section giving `p0`, `T0`
**and** `p` selects `407`, not `401`.

Once the type is resolved, every other key of the inlet/outlet family in the section
must be one the record carries: a selector of another type (`mach` on a `401`, `un`
on a `420`, `p0` on an outlet) or a field the record has no slot for (composition and
turbulence on an outlet or on a `410`) stops BCB with
`[ERROR] key <key> of section [<name>]: not honoured by BC <id>`; with `strict-keys =
false` it is reported once and ignored. `Ae_At = 0` and `a1-a3 = 0` are the defaults and
mean "not given". `u`, `v`, `w` and `p-time-file` are documented keys that no record carries
(the outlet `406` is written with `p` and `rf` only): one `[WARNING]` per section, whatever
`strict-keys`, and the key has no effect. Negative `T0`, `p0`, `T` or `p` are refused
on every type, the gsi records (502-506) included. Each `y<species>` value is one number in
[0, 1] (`[ERROR] key <key> = <value>: the mass fraction must lie in [0, 1]`, the same message on
every tool); a value outside [0, 1] by rounding only, at most 1e-12 (`1.0000000000000002`,
`-1.0e-20`), is accepted and set exactly to 1 or 0. The mass fractions given by `y<species>` keys must sum to 1: within 1e-3 (with a 1e-12 slack on both limits, the rounding of decimal constants,
so that `0.249 + 0.75` is accepted; deviations up to 1e-12 are silent) they are renormalised with a
`[WARNING]`, beyond it the section is refused; a multi-species inlet that gives neither `y<species>`
keys nor `eq-CEA-file` is refused as well (every mass fraction would be written as 1e-20). A
composition taken from `eq-CEA-file` follows the
same rule on the mass of the CEA products that are not species of the run (dropped species):
renormalised with a `[WARNING]` within 1e-3, refused beyond it (declare the products, or add a
CEA-mixture species to absorb them). Values of enumerated keys (`type`, `axis`, `direction`) are
case-sensitive: `Outlet` or `SX` is refused at
configuration time with the list of allowed values. A section header written twice in a deck
(the INI reader keeps the first `[section]` and drops the second in silence) is refused when the two
copies differ: `[ERROR] section [<name>] of <deck>: declared twice (lines <n1> and <n2>), the second is
ignored: merge them` (a `[WARNING]` under `strict-keys = false`, and a `[WARNING]` only when the tool does
not read that section: a disabled block, a section no `face<n>` names). Two copies with the same keys and
the same values (blank lines, comments and the order of the keys do not count; values are compared as
written, so `p0 = 30e+5` and `p0 = 3.0e6` differ) give the products of the deck with one copy: the same
message is then a `[WARNING]` that ends with `(the two copies hold the same keys and values)`, whatever
`strict-keys`.

Physical envelope of the `420` kernels (MOSE, Q2D): `g <= G*(T0, p0)` (the choked
mass flux of the isentrope from the stagnation state) and `psup <= psub < p0`; a trio
outside it has no root in the solver. When `thermo.dat` is loaded BCB checks the
explicit trio against the isentrope and prints a `[WARNING]` when `g > G*` or when
`psub`/`psup` differ by more than 5 % from the isentropic values (never a refusal).
Between `psup` and `psub` the kernels impose the mass flux `g` and the stagnation enthalpy
and leave `p0` free: this is the exact closure while a normal shock stands inside the
divergent part (subsonic exit, part of `p0` lost), and an approximation in the
over-expanded part of the band next to `psup`, where the real exit stays supersonic at
`psup` with oblique shocks outside it: there the kernel returns the state of mass flux
`g` and stagnation enthalpy at the boundary-cell pressure (a Fanno-type state, supersonic
with an entropy rise) instead of the design exit state; the boundary-cell pressure is
not a far-field back-pressure.
The `line-file` mapping of a `410` inlet samples the unwrapped record at the face
cell centres (point sampling): on a face much coarser than the record it is not
conservative (the flux of the mapped record differs from the record's).

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
| Injector nozzle (tested first, after `421`) | `Ae_At`, or `g` **and** `psub` **and** `psup`; `p0` **and** `T0` (or `eq-CEA-file`) are required as well | `420` |
| Borda choked injector (Q2D only, 2D meshes; tested first) | `a1-a3` **and** `p0` **and** `T0` | `421` |

On a 2D (x,y) mesh, the deck format read by Q2D only, `408` and `410` are refused at build time
(`[ERROR] <section> (normal-velocity inlet, BC 408): a 2D mesh (x,y file) is read by Q2D, which does
not implement BC 408`): Q2D rejects them at start-up. The manifold `501` is refused on a 2D mesh by the same gate (`[ERROR] <section> (manifold, BC 501): a 2D mesh (x,y file) is read by Q2D, which does not implement BC 501: use 101 or 401-407`): Q2D refuses it at its pre-scan. With `BC-force-connect`
(default `true`, see [connectivity](connectivity.md)) the connection step works cell by cell on every face, whatever
its declared type: the cells of a face declared `inlet`, `gsi`, `wall` or `symmetry` that coincide with a cell of another
block are written as connections (101/103) and the other cells keep the declared BC. This is how an injection plate
with holes is set up: declare the whole plate face `inlet` (or `wall`) and mesh every hole as a block of its own; the hole
cells are connected automatically and no multipatch is needed. BCB prints one line per such face
(` [LOG] BC-force-connect: block <b> face <f>: <n> cells connected to block(s) <list>, <m> cells keep the declared BC [<section>]`)
and a `[WARNING]` only when a declared section is left with no cell on the face (the declaration has no effect there);
`BC-force-connect = false` keeps the declared BC on every cell.

The `p0`, `T0` form of `405` writes the static state of the isentropic expansion computed on the
species tables of `thermo.dat` (required: without it BCB stops): `T` from the enthalpy balance
h(T0) = h(T) + M²/2 γ(T) R T (variable cp, Newton) and `p` from ln(p0/p) = ∫ cp/(R T') dT' between
`T` and `T0` (trapezoidal rule on the 1 K grid, the quadrature of the solvers' nozzle kernels); the
constant-γ relation p0/(1 + (γ-1)/2 M²)^(γ/(γ-1)) of earlier versions is 1 % off at T0 = 2000 K, M = 2.
The record is the one of the `p`, `T` form (`mach`, static `T`, static `p`); the solvers know no other.
A `T0` outside the loaded table is refused (`[ERROR] <name> (supersonic inlet, BC 405): T0 = ...
lies outside the temperature range of thermo.dat [Tmin, Tmax] K`) as the 420 kernel refuses its `T0`;
a static `T` that the expansion at `mach` takes outside the table is written with a `[WARNING]`
(the solvers clamp their cp/h lookups at the ends of the table, and ICB reports the same expansion;
extend the table, or give `p` and `T`). This is the rule of the whole family: a stagnation `T0` is
refused outside the table wherever it is expanded (`420`, this form of `405`, the ICB `nozzle`,
homogeneous and `variable` states given by `T0`), while a deck `T0` or `T` that a record carries as
given (`401`-`404`, `405` by `p` and `T`, `407`, `408`) outside the loaded table is reported with a
`[WARNING] <name> (inlet, BC <id>): T0 = ... lies outside the temperature range of thermo.dat` and
never clamped in silence.

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
| `a1-a3` | Borda injector throat-to-face area ratio A1/A3, in (0, 1] |
| `time-file`, `p0-time-file` | Time series replacing the scalars; the `p0-time-file` values are in **bar** (the solvers read them so), `p0` itself in Pa |
| `periodic` | Loop a `time-file` series instead of holding the last value |
| `line-file` | Unwrapped (2D) time series to be mapped onto the 3D face; the `time-file` is then *written* by BCB (see below) |
| `center` | Cylinder axis point `x y z` for the `line-file` mapping (required with `line-file`) |
| `strip-j-face` | Node row of the line-file zone used as the strip (default `1`) |
| `axis` | Cylinder axis of the `line-file` mapping, `x`, `y` or `z`; default: from the face geometry (see below) |
| `n-repeat` | Sector strips: the line-file covers `1/n-repeat` of the lap and is repeated `n-repeat` times around the face (default `1`) |

The names of the series files written into the record (`time-file`, `p0-time-file`, `p-time-file`, `q-time-file`,
`T-time-file`) are limited to 32 characters: the record keeps 32 characters of the name (MOSE reads the `402` series
name and FUSS the wall series name with 32 characters), so a longer name of a file you provide is refused
(`[ERROR] key <k>: file name longer than 32 characters ...`) instead of being truncated in silence. The `time-file`
of a section with `line-file` is written by BCB itself: a longer name is accepted, the file is written under its first
32 characters and the record names that file (one ` [LOG] time-file ...` line).

With `line-file`, BCB maps each zone of the unwrapped 2D record onto the block face and writes the result to `time-file`
(one zone per block and time level). The circumferential coordinate of the line-file (the one with the larger node range)
is assumed to cover exactly **one lap**, or one sector of `1/n-repeat` lap: its full node span L is the period, so cell
centres fall at half-cell offsets from the seam.

**Line-file header.** The header must name exactly the coordinates that the zone shape implies (`x y` for a
2D zone; a 1D zone or a zone with a third coordinate `z` is refused), followed by the variables; a header
that starts with other names, a `strip-j-face` beyond the node rows of the zone and a zone without variables
are refused with an explicit `[ERROR] line-file ...` message instead of being read as shifted columns.

**Angular mapping (thin-annulus assumption).** The angle of every face cell is measured about `center`, right-handed
about the cylinder axis, and the strip coordinate s is mapped as θ = 2π (s − s₀)/(L · `n-repeat`), the pattern being
repeated `n-repeat` times around the face. The face radius does not enter: the number of waves per lap, the angular
velocity of the pattern (the zone times are copied unchanged), the velocity components in m/s, the densities and the
pressure are preserved; the arc length is not. This is the thin-annulus assumption of the unrolled 2D model: the
wave-frame kinematics of the 2D solution (front speed relative to the gas, hence the jump conditions it satisfies) are
exact only at the equivalent radius R₂D = `n-repeat` · L / 2π; at another radius r the front sweeps at D · r/R₂D while the
imposed gas state is unchanged. The mass flux per unit area is preserved, the total mass flow scales with the face area.
With `-v` BCB prints L, R₂D and the face radius range, and it **warns** (always) when R₂D lies outside the radial
extent of the face (node radii) or differs from the mean cell-centre radius by more than 10 %: a strip that covers a sector (L = 2πR/n) but has no
`n-repeat` is stretched over the full lap (wave count not preserved) and triggers this warning.

**Axis and axial sign.** The cylinder axis is the dominant component of the area-weighted mean inward normal of the face
(`axis = x|y|z` overrides it; `auto`, the default, keeps the geometric rule). Face `face` of every block of the mesh is
mapped, but the solver uses a block's zone only where that block carries the inlet: a block whose face has no dominant
component (mean normal more than 30° off every axis) or no mean normal (zero-area or closed face) is written about the
axis of the logical face index (1/2 → x, 3/4 → y, 5/6 → z) with a warning, and BCB stops only when no block gives an
axis: give `axis`. With `axis`, a block face parallel to that axis (no inward component along it) is treated the same way. The velocity component of the line-file along the circumferential coordinate becomes the tangential velocity
(+s → +θ, right-handed about the +x/+y/+z direction whatever the sign of the inward normal: on a face whose inward normal
is −axis the pattern turns the other way when seen from downstream), the other one the axial velocity, imposed **along the inward normal of the face**: a positive 2D axial velocity
is an inflow on every face, minimum- or maximum-index. BCB prints this at every run, whatever the verbosity, one line per face it maps about an axis, e.g. `[INFO] Block 1 face 6: line-file mapped about axis x, inward normal along -x: a positive axial velocity of the record enters the domain`: on a face whose inward normal is −axis, a record whose axial velocity was negated to give an inflow gives an outflow. The radial component is zero, so only planar faces normal to the
axis are consistent with the mapping; BCB warns when a face cell deviates by more than 5° from the axis (conical or
curved injector planes).

**Zone times.** Every zone of the line-file must carry a `SOLUTIONTIME` (a zone header may span several lines); a record
where some zones lack it is refused, a record with none is written without times (warning: MOSE then reads every zone at t = 0 and keeps the last zone of
each block, i.e. a steady inflow), and times that are not
strictly increasing produce a warning.

One mapping serves every block that uses the same section; a `time-file` name can hold only one mapping, so sections
that differ in line-file, face, `center`, `strip-j-face`, `axis` or `n-repeat` must use distinct `time-file` names
(BCB stops otherwise).

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
p0-time-file = p0_transient.dat   ; values in bar, as the solvers read them (p0 is in Pa)
T0           = 300.0
```

Injector nozzle — either give the area ratio and let BCB derive the rest
(`thermo.dat` is required: the thresholds are computed on the species cp/h
tables, which must cover the expansion from `T0` down to the supersonic exit
state, with `T0` at most one grid step below the top of the table because the
solvers' interpolation clamps there), or prescribe the exit pressures together with the mass flux. Both forms need the stagnation state
`p0`, `T0` (explicit, or from `eq-CEA-file`: an explicit value always wins).
The solvers switch on the boundary-cell pressure `p`: `psub <= p < p0` subsonic
inflow from (`T0`, `p0`), `psup <= p < psub` choked inflow with the mass flux
`g`, `p < psup` supersonic inflow — so an explicit trio must satisfy
`0 < psup <= psub < p0` (`psub` is the exit pressure of the just-choked subsonic
solution, `psup` the design supersonic exit pressure); BCB stops otherwise.
The record is steady (no `p0-time-file`, no `time-file`):

```ini
[inlet_nozzle_arearatio]
type  = inlet
Ae_At = 1.5
p0    = 1.013e5
T0    = 300.0

# the same injector written explicitly (air, gamma = 1.4; values rounded):
[inlet_nozzle_explicit]
type = inlet
g    = 157.6
psub = 8.920e4
psup = 1.623e4
p0   = 1.013e5
T0   = 300.0
```

With `Ae_At`, BCB computes `psub`, `psup` and `g` on the tabulated-cp isentrope
from (`T0`, `p0`), with the discrete arithmetic of the MOSE/Q2D nozzle kernels
(cp and h interpolated linearly on the 1 K grid of `thermo.dat`, isentrope by the
trapezoidal rule on the same grid): `g = G*/Ae_At` with `G*` the maximum of
`rho*u` along the expansion (sonic throat), `psub` and `psup` the pressures of
the two exit states with `rho*u = g` (subsonic and supersonic branch, each
bracketed). The thresholds therefore coincide with the states the solvers
recompute from the record (the supersonic kernel returns `psup` to its own
tolerance), and the 420 record is written with 17 significant digits so that
`g` reaches the solvers unrounded: at `Ae_At = 1` a `g` rounded up by more than
1e-9 relative has no root in their supersonic kernel. No frozen `gamma` is
involved; for a calorically perfect table the values differ from the closed-form
area–Mach relations by the quadrature bias of the 1 K grid (~1e-5).

Decks written before June 2026 called the mass flux `rt`; that key was renamed `g`
and BCB now stops with an explicit message when it finds `rt`.

Keys of older decks: a renamed key is an unknown key like any other (`[ERROR]`, or one `[WARNING]` with
`strict-keys = false`) whose hint names the current key; a removed key has no effect and gets one `[WARNING]`:

| Key of older decks | Status | Use instead |
|---|---|---|
| `rt` | renamed | `g` (nozzle mass flux, kg m⁻² s⁻¹) |
| `force-connect` (in a BC section) | moved | `BC-force-connect` in `[ATLAS-Parameters]` |
| `p-time-file` | removed (never read by any record) | `p0-time-file` (BC 402) or a `time-file` inlet (BC 410) |
| `u`, `v`, `w` | removed (no record carries a velocity vector) | `alpha`, `beta` for the direction, `un` for BC 408 |

Borda choked injector (BC `421`, Q2D solver only) — a choked orifice of throat
area A1 followed by a sudden expansion into the boundary face of area A3; the
solver computes the regimes itself from the plenum state, so only the area ratio
is needed:

```ini
[inlet_borda]
type  = inlet
a1-a3 = 0.2
p0    = 1.0e6
T0    = 300.0
```

!!! note "BC 421 is a Q2D feature"
    `a1-a3` is accepted only on a 2D mesh (an `x,y` mesh file, the deck format
    Q2D reads); on any other mesh BCB stops, because no other solver implements
    BC 421. The key is exclusive with every other inlet selector (`Ae_At`,
    `psub`/`psup`, `g`, `mach`, `p`, `un`, `T`, the time files) and with
    `alpha`/`beta`: injection is along the face normal by construction.
    Every refusal stops BCB with a non-zero status, so a chained
    `ATLAS.sh BCB && <solver>` does not continue, and no `bc.txt` is written
    for the refused grid level.

    With `MG-levels > 1` the coarse levels of a 2D mesh keep its 2D form,
    so every level carries the BC 421 records.
    How the solver treats the orifice in each flow regime, and for which
    `a1-a3` its kernel holds, is described in the Q2D documentation.

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
inlet and are appended to the payload after the mass fractions. A band left at zero
under a model (`nrans = 1` without `mit`, `nrans = 2` without `kappa` or `omega`,
`nrans = 7` without `rhoRij` or `omega`) is written with a `[WARNING]` naming the
keys: the inlet carries no turbulence (ICB refuses the same initial field under an
omega model).
On a pure-2D (`x,y`) mesh a Reynolds-stress inlet (`nrans = 7`) carries the 5-band tail
that Q2D reads (`R11, R22, R33, R12, omega`; `R13`, `R23` are not part of its 2-D state);
the 7-band tail (`R11 R22 R33 R12 R13 R23 omega`) is written on 3-D meshes only.

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

!!! note "Values per population"
    A dispersed phase injects every population of every material of `<name>phase.txt`, and `<name>-bc.txt` holds one copy
    of the boundary table per (material, population) pair, material by material, populations in order. Each key above takes
    one value, which every pair receives, or one value per pair in that order: with `alumina 2` and `water 1`,
    `p1-dp = 0.01 0.02 0.03` gives alumina's populations 0.01 and 0.02 and water's 0.03. Any other count stops BCB. The
    variant is chosen once for the phase: `402` needs a non-zero velocity magnitude in every population.

!!! note "One record set per dispersed phase"
    Each named dispersed phase gets its own ids and payloads in its own `<name>-bc.txt`:
    on a face shared by `p1` and `p2`, the `p1-*` keys reach only `p1-bc.txt` and the
    `p2-*` keys only `p2-bc.txt` (variant selection included, so one phase may be `401`
    and the other `402` on the same face). Payload values are always written as numbers;
    only an unset `alphap`/`betap` is written as `normal,`.

#### Dispersed-phase override on the axis

On a 2D-axisymmetric mesh the axis face is `axisymmetric` (`200`) for every phase. A
Lagrangian dispersed phase may instead be let out through it: give the face a named
section with the keyword type and add `<phase>-type = outlet` for that phase only. An
Eulerian phase is mirrored at the axis with `<phase>-type = symmetry` (`300` in that
phase's file).

```ini
[BCB-Block1]
face3 = ax

[ax]
; gas: 200 as before
type       = axisymmetric
; partL only: 400 (particles leave through the axis)
partL-type = outlet
; partE only: 300 (the phase is mirrored at the axis)
partE-type = symmetry
```

`gas-bc.txt` keeps `200` on face 3; `partL-bc.txt` carries `400` there and `partE-bc.txt`
`300` (no payload in either). Only `outlet` and `symmetry` are accepted — any other word
stops BCB with `[ERROR] partL-type = <word>: only "outlet" or "symmetry" is allowed ...`.
The wedge faces BCB auto-tags on a 2Daxi mesh carry no section and always stay `200`. The key
is read only there, for a dispersed phase: on a face of any other type, or with the name of a
phase that is not dispersed, BCB stops with `[ERROR] key partL-type of section [<s>]: not
honoured (type = <type>) ...` (a `[WARNING]` with `strict-keys = F`, and the key is ignored).

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

Output ID: `501`; the payload is the source `block, face` pair, written as two integers (the solvers read them as integers).

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

The injected composition is the CEA product composition restricted to the species of the
run: each species of `phase.txt` takes the mass fraction of the CEA product of the same name,
and a species named `CEA-mixture` takes the rest (1 minus the sum of the others), condensed
products included. Declare the gas products in `phase.txt` together with a `CEA-mixture`
species (GPB writes one with `CEA-file`, `reactions` and `inerts-mixing = true`). Without it,
when the declared products sum to less than 1 − 1e-3 BCB stops with
`[ERROR] composition of section [<name>] from the CEA file: the products declared as species
of the run sum to <sum>, they must sum to 1 within 1e-3 (...)`; a smaller deficit is
renormalised with a `[WARNING]`. For an aluminised ammonium-perchlorate/HTPB propellant (the
`CEA.inp` of `test/ICB/IG-interp-species-decomposition`: 67 % AP, 20 % Al, 13 % HTPB), whose
aluminium products (condensed alumina among them) are not gas species of the run, `phase.txt` reads:

```text
ideal-gas phase
H 1.008000
O2 31.998000
OH 17.007000
O 15.999000
H2O 18.015000
H2 2.016000
CO 28.010000
CO2 44.009000
CL 35.450000
CL2 70.900000
HCL 36.458000
N2 28.014000
CEA-mixture 56.478204
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
