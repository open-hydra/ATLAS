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

For ideal-gas blocks, `p0`/`T0` and `mach` are also supported ([Total conditions](#total-conditions)).

### Velocity

The velocity of a zone is given by its components `u`, `v`, `w` [m/s], or by a speed $V$ and a
direction. The speed is `mach` times the speed of sound (ideal gas) or `vel` (real fluid). The
direction is set by the flow angles `alpha` and `beta`, in radians:

$$\mathbf{u} = V\,(\cos\alpha\cos\beta,\ \sin\alpha\cos\beta,\ \sin\beta)$$

`alpha` turns the flow in the x-y plane from x towards y, and `beta` lifts it out of that plane
towards z; without angles the flow is along x. This is the direction the solvers give the `alpha`
and `beta` of an inflow BC, so an inlet and an initial field written from the same keys agree. An
ideal-gas zone that gives any of `u`, `v`, `w` takes the three components and ignores the angles;
in a real-fluid zone each component given replaces its own term.

!!! note "Initial fields written before this fix"
    Earlier ICB versions wrote $v = V\cos\alpha\sin\beta$: with either angle non-zero the direction
    was wrong, and so was the speed ($V\cos\alpha$ along x alone when `beta` is 0). Rebuild the
    initial fields of cases that give `alpha` or `beta`.

An ideal-gas zone gives its speed once: `mach` next to a non-zero `u`, `v` or `w` stops ICB.

### Total conditions

An ideal-gas zone can give its state by the stagnation pressure `p0` and temperature `T0`, alone or
next to the static `p` or `T` (`p0` with `T`, `p` with `T0`). ICB derives the static state the way
the solvers' supersonic inlet (BC 405) does, on the cp and h tables of `thermo.dat`:

* the static $T$ follows from the energy balance $h(T_0) = h(T) + V^2/2$, the speed $V$ being given
  by `mach` ($V = M a(T)$) or by `u`, `v`, `w`;
* the static $p$ lies on the isentrope from $p_0$ down to $T$,
  $\ln(p_0/p) = \int_T^{T_0} c_p(T')/(R\,T')\,dT'$; with a static `T` the stagnation temperature
  is that of $T$ at the speed of the zone.

A zone and an inlet given by the same `p0`, `T0` and `mach` therefore carry the same static T and
p, whatever the variation of $c_p$ with temperature.

!!! note "Initial fields written before this fix"
    Earlier ICB versions took $T = T_0$ when the speed was given by `u`, `v`, `w` (the speed
    entered the pressure only), and expanded $p_0$ with
    $(1 + \frac{\gamma-1}{2}M^2)^{\gamma/(\gamma-1)}$ at the $\gamma$ of the static temperature,
    1.5 % off the isentrope for N2 at $T_0$ = 1200 K, $M$ = 2. Rebuild the initial fields of
    ideal-gas zones that give `p0` or `T0` with a speed; the fields of zones at rest move by
    less than 1e-8.

## Variable Initialization (file-driven)

A value can vary cell by cell: `<key>-file` gives it from a file, in place of the constant `<key>`
(the zone is then built as `variable`). The keys that take a profile are `mach`, `p0`, `T0`, `p`, `T`,
`rho` and `y<species>` for an ideal gas, `p`, `T`, `h`, `vel` for a real fluid, `T` for a solid.

```ini
[ICB-Block1]
type = variable
T-file = T_profile.dat
T-direction = x
p = 101325.0
```

The file is read in one of two ways:

* **With `<key>-direction`** (`x`, `y`, `z`, `r` or `t`): a table of two columns, the coordinate and
  the value, one row per point (`#` or `!` starts a comment). The coordinate must be monotone, and
  `t` is in degrees. Each cell takes the value interpolated linearly at its centre, along the letter
  ($r$ and $t$ about the x axis, as for the [zone ranges](#multizone-setup)). The table must hold the
  centre of every cell of the zone: only the cells of the zone's own range, not the whole block.
* **Without it**: a Tecplot field (`.tec`, or `.szplt` with a TecIO build) on a structured grid, any
  grid: each cell takes the value of the nearest cell of the file, the first variable after the
  coordinates. That variable must be cell-centred (`VARLOCATION=([3]=CELLCENTERED)` after `x`, `y`);
  a file of nodal variables stops ICB.

A constant next to its profile (`T` and `T-file`), and a direction without its profile, stop ICB:
give one of the two.

!!! note "Profiles read before this fix"
    ICB read a 1-D table at every cell of the block, so a zone whose table covered only its own range
    stopped ICB; a cell centre on the first point of a table stopped it too. A constant next to its
    profile dropped the profile in silence, and a direction without a profile was ignored. A field of
    nodal variables gave 0 in every cell (ICB then stopped on a state "not physical").

## Nozzle Initialization (IG)

```ini
[ICB-Block1]
type = nozzle
p0 = 10.342
T0 = 555.56
nozzle-direction = dx
nozzle-threshold = 0.0
```

The nozzle law starts a nozzle from rest in its plenum: every row of cells i is a cross-section, and
the quasi-1-D isentropic law gives it the Mach number of its area ratio A/A*, from `p0` and `T0`.

- **The geometry.** The block must be a duct about the x axis, meshed along it: i from inlet to exit
  (the cell centres advance along +x with i), j from the axis or the inner wall to the outer wall. The
  area of row i is `pi |r_ext^2 - r_int^2|`, from the distances to the x axis of its walls j = 1 and
  j = J (on the first node plane of k): an axisymmetric duct, or a sector of one. The throat is the
  row of smallest area, in this block. On a 2-D planar channel the law reads the area ratio squared.
- **The law.** Upstream of the throat (along the flow) the rows are subsonic, downstream
  supersonic, the throat row exactly sonic; `p`, `T` and the speed follow from `p0`, `T0` and gamma
  of the gas at `T0`. The velocity runs along the i lines of the mesh.
- **The plenum.** `nozzle-direction` is the direction of the flow: `dx` towards +x, `sx` towards -x.
  The rows upstream of `nozzle-threshold` (an x) keep `p0` and `T0` at rest. With `dx` the plenum
  runs from the first row to the first cell whose centre lies past the threshold, that cell included;
  with `sx` from the last row down to the second cell past it. A threshold that no cell lies past
  makes every row plenum with `dx`, none with `sx`. Without `nozzle-threshold` there is no plenum and
  the law takes every row.

A block that is no nozzle stops ICB before anything is written, naming what is missing:

- `[ERROR] build_IG_field block <b> (section [<s>]): the nozzle law needs a duct about the x axis,
  meshed along it (...), and its cross-section is constant along i (A max/min = <r>, the law needs
  1.001 at least): a duct without a throat is no nozzle ...`;
- `... and the row of cells i = <i> has no cross-section: its walls j = 1 and j = J lie at the
  distances <r1> and <r2> from the x axis` (a planar channel from y = -h to y = h, say);
- `... and its cell centres do not advance along +x with i: at j = 1, k = 1 cell i = <i> lies at x = ...`.

!!! note "Nozzle fields written before 2026-10-28"
    The throat row was sonic to 1e-9 only (the Newton iteration of `legge_aree` crawls at the double
    root M = 1), and on a duct of constant section the iteration stalled: ICB stopped with a Fortran
    backtrace (`legge_aree: Max iterations reached`). Without `nozzle-threshold`, `sx` made every row
    but the first a plenum, and `dx` wrote the first row as plenum outside the range of a zone; a
    threshold that no cell lies past gave no plenum with `dx` and a plenum of every row with `sx`.

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
- Turbulence keys are available for IG/RF; see [Turbulence](#turbulence) below.

## Turbulence

The free-stream turbulence of a zone is given either **specific** or
**density-weighted**, each quantity with its own pair of keys:

| Quantity | Specific key | Density-weighted key | Model |
|----------|--------------|----------------------|-------|
| Spalart-Allmaras working variable $\tilde\nu$ | `nuTilde` $= \tilde\nu$ [m²/s] | `rhoNuTilde` $= \rho\tilde\nu$ [kg/(m·s)] | `nrans = 1` |
| Turbulent kinetic energy $k$ | `k` [m²/s²] | `rhoK` $= \rho k$ [kg/(m·s²)] | `nrans = 2` |
| Specific dissipation rate $\omega$ | `omega` [1/s] | `rhoOmega` $= \rho\omega$ [kg/(m³·s)] | `nrans = 2`, `7` |
| Normal Reynolds stresses $R_{11} = R_{22} = R_{33}$ | `Rij` [m²/s²] | `rhoRij` $= \rho R_{ii}$ [kg/(m·s²)] | `nrans = 7` |

The names are those of the [NASA Turbulence Modeling Resource](https://tmbwg.github.io/turbmodels/).
`nuTilde` is the variable the Spalart-Allmaras model transports, $\tilde\nu$, and
`rhoNuTilde` its density-weighted form. It is not the eddy viscosity
$\mu_t = \rho\tilde\nu f_{v1}$, which the Resource and the solvers call `mut` and
which is not an input: the keys `nut` and `mut` stop ICB with a hint. The two differ
where $\tilde\nu$ is of the order of the molecular viscosity: at the usual free-stream
level $\tilde\nu = 3\nu$ the eddy viscosity is $0.21\,\mu$.

The IC file carries the density-weighted variables the solvers advance, in bands that
take the names of the density-weighted keys: `rhoNuTilde`, `rhoK`, `rhoOmega` (the Reynolds
stresses keep their names `ru'u'` ... `rv'w'`). A specific key is multiplied by the
density of each cell; a density-weighted key is written as given. Give each quantity
once: `k` and `rhoK` together stop ICB. The model (`nrans`) follows from the keys
given, or from `nrans`.

- **Ideal-gas zone:** both forms are accepted.
- **Real-fluid zone:** only the density-weighted keys. The real-fluid table
  ($p$, $h$ → $T$) carries no density, so a specific key stops ICB.
- **Interpolation source:** the turbulence bands are recognised by name. A
  density-weighted band (`rhoNuTilde`, `rhoK`, `rhoOmega`) is interpolated as it is. A specific band (`nuTilde`, `k` with
  its `omega`) is first multiplied by the density of the source; a real-fluid source
  with specific bands stops ICB.

The boundary records written by BCB take the specific `nuTilde`, `k`, `omega` and `Rij`
([inlet turbulence keys](../bcb/bc-types.md#inlet-turbulence-keys)).

## Next

- [IC Strategies](./ic-strategies.md)

!!! note "A zone whose keys cover part of the block"
    The turbulence constants (`nuTilde`, `k`, `omega`, `Rij` or `rhoNuTilde`, `rhoK`, `rhoOmega`, `rhoRij`) of a zone are applied to the cells of
    its range only, exactly like `p`, `T` and the velocity: the cells outside it keep the field
    written by the other zones (ICB prints ` - build_IG_field: turbulence constants of this zone
    applied to n of N cells`). A zone that is meant to cover the whole block must have no `range`.
