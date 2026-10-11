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
  density-weighted band (`rhoNuTilde`, `rhoK`, `rhoOmega`, or the earlier `mi_t`, `mi_tilde`,
  `kappa` with its `omega`) is interpolated as it is. A specific band (`nuTilde`, `k` with
  its `omega`) is first multiplied by the density of the source; a real-fluid source
  with specific bands stops ICB. A band named `mut`, `mu_t`, `nut` or `nu_t` is the
  eddy viscosity, the auxiliary band of the solvers: it is ignored with a notice, not
  read as the Spalart-Allmaras variable.

The keys `mit` and `kappa` of earlier decks are retired and stop ICB with a hint, as
an unknown key. ICB wrote them as given, so they held the density-weighted values:
`mit` becomes `rhoNuTilde`, `kappa` becomes `rhoK`, and **`omega` becomes `rhoOmega`**: the
key `omega` keeps its name but is now specific. `rhoRij` is unchanged. Alternatively,
divide each by the density and give the specific keys.

The boundary records written by BCB take the specific `nuTilde`, `k` and `omega`
([inlet turbulence keys](../bcb/bc-types.md#inlet-turbulence-keys)).

## Next

- [IC Strategies](./ic-strategies.md)

!!! note "A zone whose keys cover part of the block"
    The turbulence constants (`nuTilde`, `k`, `omega`, `Rij` or `rhoNuTilde`, `rhoK`, `rhoOmega`, `rhoRij`) of a zone are applied to the cells of
    its range only, exactly like `p`, `T` and the velocity: the cells outside it keep the field
    written by the other zones (ICB prints ` - build_IG_field: turbulence constants of this zone
    applied to n of N cells`). A zone that is meant to cover the whole block must have no `range`.
