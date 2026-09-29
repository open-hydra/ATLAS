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

The dispersed-phase keys `krho`, `kT`, `Pp`, `dp` and `rp` take one value, which every (material, population) pair of the
phase receives, or one value per pair in the order of `<name>phase.txt` (material by material, populations in order); any
other count stops ICB.

In a block with zones the dispersed-phase keys of a zone apply to the cells of that zone, like its gas keys: each zone
derives the dispersed state of its cells from its own `krho` and `kT` and the gas state it wrote there, starts them from
vacuum when it has no `krho` (or `krho = 0`), or interpolates them from its own `old-solution`; every zone that is not
interpolated gives `dp` or `rp`. The layout of the dispersed IC file (the pseudo-pressure bands of `neuler`) is one per
block: the `neuler` of the last zone that is not interpolated decides it, as in a block without zones.

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

The plenum of a `nozzle` zone is every row of cells upstream of `nozzle-threshold` (along
`nozzle-direction`), over the whole cross-section of the block: in a multizone block the plenum rows
are written also outside the `range<n>` of the zone, and only the rows downstream take the nozzle law
inside the range. The zone order therefore decides the state of the plenum cells that lie in the range
of another zone:
- a `nozzle` zone listed after another zone overwrites the cells of its plenum rows that the earlier
  zone wrote (`[WARNING] build_IG_field block <b> (section [<zone>]): the plenum rows of this nozzle zone
  ... overwrite <n> cells that an earlier zone wrote: the zone order decides their state`);
- a zone listed after a `nozzle` zone overwrites, inside its own range, the plenum cells that lie
  outside the range of the nozzle zone (`[WARNING] build_IG_field block <b> (section [<zone>]): this zone
  overwrites <n> cells that the plenum rows of an earlier nozzle zone wrote outside the range of that
  zone ...`).

To keep the state of another zone upstream of the nozzle, list the `nozzle` zone first and the other
zone after it; the WARNING then names the cells the later zone takes back.

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

- `old-species` for ideal-gas species remapping. It names where the phase file
  of the OLD solution is found, in one of two forms:
    - the directory form `old-species = old/` (trailing slash): the old species
      are read from `old/<phase>phase.txt` (e.g. `old/gas-phase.txt`) and nothing
      else changes;
    - the prefix form `old-species = old-`: the old species are read from
      `old-<phase>phase.txt` in the case directory. Because `ATLAS.sh` discovers
      the phases of a run from every `*phase.txt` of the case directory, such an
      `old-phase.txt` is also listed as a phase of the run that no block builds:
      ICB prints a `[WARNING]` for it and writes no `old-ic.tec`. Prefer the directory form.

2D -> 3D restarts with `interpolation-law = index`: a one-cell source (a pure-2D Q2D
x-r solution, or a one-cell MOSE wedge) is revolved about the x axis. The velocity
(radial and azimuthal components) and, when the source carries Reynolds stresses,
the stress tensor are rotated to the azimuth `theta = atan2(z, y)` of every target
cell. The target geometry decides: if its k-lines conserve y better than r the
target is a z-extrusion (planar case) and receives a plain copy, otherwise it is
revolved; a revolved target whose radius is conserved worse than the solver's own
axisymmetry test (1e-5 of the radius) is refused (a one-cell source can only be
revolved onto a body of revolution or copied onto a z-extrusion). With any other
`interpolation-law` a one-cell source on a revolved target cannot be revolved (its
donors are picked by Cartesian distance) and the field would be wrong away from the
source azimuth: ICB stops with `[ERROR] rotate_2d_to_3d ...`; use `index`. Scalar
sources (`p-file`, `T-file`, solid and dispersed fields) are never refused this way.
A pure-2D source is always taken as axisymmetric (Q2D does not record its regime in
the file).
A wedge or one-cell 3-D source mapped onto a pure-2D (`x,y`) target keeps `u`, `v` only: its third velocity
component (the swirl `w` = v_theta) is discarded with a `[WARNING]` naming the component and its largest magnitude.

Turbulence of a laminar source onto a RANS target: under an omega model (`nrans =
2` or `7`) a zero `omega`, `kappa` or stress band divides in the solver kernels, so
ICB refuses to write it and names the zone keys (`kappa`/`omega`, `rhoRij`/`omega`)
that give the free-stream values; under Spalart-Allmaras (`nrans = 1`) `mi_t = 0` is
written with a `[WARNING]`. Species of the source that the run does not declare are
dropped: the partial densities are rescaled to the source density with a `[WARNING]`
when the lost fraction is at most 1e-3, the block is refused beyond that (declare
the species, or use a source with the species of the run); `y<species>` keys of a
zone must sum to 1 (renormalised within 1e-3 with one `[WARNING]`, refused beyond)
on every IC type (homogeneous, zoned, `variable`, `nozzle`; the messages name the zone by its deck section, e.g. `(section [zone2])`); a zone of a multi-species phase that
gives neither `y<species>` keys nor `eq-CEA-file` is refused (every mass fraction would be
1e-20). The mandatory
pressure band of a source may be named `p` or `pressure` (`h`/`enthalpy` for a
real-fluid source). The written field is checked before the file is written: a
non-positive or non-finite `T`, `p` or partial density stops ICB; temperatures
outside the loaded thermo table are reported, on every IC type, and the cp/h
lookups that build the field read the end row of the table there, as the solvers'
lookups do (no out-of-bounds read, no refusal). A stagnation `T0` outside the table is refused
instead, on every path that expands from it (`nozzle`, and the homogeneous or `variable` zones
given by `T0`): the enthalpy balance reads the tables between `T0` and the static state, and the
BCB `420` and `405` kernels refuse their `T0` in the same way.
`interpolation-law = extrude` revolves a one-cell source (a pure-2D x-r solution or a one-cell
wedge) about the x axis into a 3D sector of `theta` degrees (default 90) in `nz` cells (default 4):
the sector starts at the source plane (azimuth 0) and turns towards +z, every field is copied onto
each cell of the sector, and the velocity (and, under the Reynolds-stress model, the stresses) is
turned by the azimuth of the cell. Each target cell then takes the nearest cell of the revolved
source. On a target revolved with the same cells this is the field of `index`; unlike `index`, the
target may have another resolution. The target mesh must be 3D. `theta` and `nz` are read with
`extrude` only (a `[WARNING]` says so when they are given with another law).

### Interpolation assumptions

- **Same weights on every band.** Each law gives a target cell a set of donor cells of the source
  with non-negative weights, and applies the same weights to every band: the partial densities,
  the Cartesian velocity components, the pressure and the turbulence bands (`index`,
  `minimum_distance`, `spherical_minimum_distance`, `outlaw` and `extrude` take one donor with
  weight 1; `multiple` combines up to 8 donors with weights that sum to 1). The written state is then a convex combination of donor states: when the species of the run are those of the source,
  the temperature it implies (`p` over the sum of the partial densities times their gas constants)
  lies between the lowest and the highest temperature of its donor cells, also across a flame or
  a shock.
- **Not conservative.** The interpolation acts on the primitive variables, not on cell integrals:
  the total mass, momentum and energy of the new field differ from those of the source (the
  initial transient of the run washes this out).
- **`multiple`** uses index-space weights: fixed fractions of the refinement or coarsening ratio
  (e.g. 27/64, 9/64, 3/64, 1/64 for a refinement by 2 in 3-D, 1/8 for a coarsening by 2), equal to
  volume weights only on uniform cells; the cell geometry never enters. For a refinement by 3 the
  weights are products of 2/3 (own cell) and 1/3 (neighbour): 2/3 and 1/3 on a face sub-cell,
  4/9, 2/9, 2/9, 1/9 on an edge sub-cell (and on a corner sub-cell in 2-D), 8/27, 4/27, 2/27, 1/27 on
  a vertex sub-cell in 3-D, so a field linear in the cell indices is reproduced exactly inside the
  block (the sub-cells next to the block boundary take the boundary cell instead of a neighbour).
- **Distances** (`minimum_distance`, `spherical_minimum_distance`, `outlaw`, `extrude`) are
  Cartesian distances between cell centres.
- **Velocity of a one-cell source.** A pure-2D (`x`, `r`) source is read as axisymmetric: its
  second velocity component is the radial one, `v = v_r`. A one-cell wedge stores the Cartesian
  `v`, `w` of its cells, which at azimuth 0 are (`v_r`, `v_theta`); the revolve turns them by the
  azimuth of the target cell minus that of the donor cell. On a pure-2D target the source `v` is
  written as the second component (`v_r` at azimuth 0) and the swirl `w` is discarded (see above).

### Turbulence and species through interpolation

The bands after the mandatory ones (species densities, velocity components and
`p` for IG; `h` for RF) are classified **by name** when the source file carries one
name per coordinate and per band (Tecplot ASCII): one Spalart-Allmaras band, a
`k` + `omega` pair, or Reynolds stresses + one `omega` are adopted (`- read_vtk_tec:
adopting N turbulence band(s) ... by name`; components the source solver did not
write, such as `R13`/`R23` of a 2D source, are set to 0). Any other trailing band
(`T`, soot, passive scalars, ...) is ignored with a notice; a set that is not one of
the three (for example k-epsilon) is not adopted and a `[WARNING]` lists the names.
Without names (VTK sources; `.szplt` sources carry their names with the pinned ORION)
nothing is adopted: `variable names unavailable or inconsistent with the data,
turbulence not adopted`. When names are present, the last mandatory band must be
named `p` (IG) or `h` (RF): otherwise the species count of `old-species` does not
match the file and ICB stops (`[ERROR] read_vtk_tec: band N of '...' is named
'...'`) instead of writing shifted bands. A zone whose turbulence model has neither
a source band nor a free-stream key (`mit`, `kappa`, `omega`, `rhoRij`) keeps its
current content in that band (0 unless another zone set it) and says so with a
`[WARNING]`. Species are mapped by name through `old-species`: a species absent
from the source is set to `1e-20`.
By-name adoption also requires the ORION library pinned by this tree (the pinned commit or later, which also exports the names of `.szplt` sources): an older ORION checkout (for example d4e04a1) does not return the unquoted names that ATLAS writes, so nothing is adopted from an ATLAS-written source.

## Multizone Combinations

Every cell of every block must be written by a zone, for every phase of the block. Each writer
records the cells it assigns: the cells of its range (an `interpolation` zone too: it writes its
range only, like every other zone type), the plenum rows of a `nozzle` zone (the whole cross-section
upstream of `nozzle-threshold`, also outside its range: the zone order decides, see
[Nozzle Initialization](#nozzle-initialization)); the dispersed phase of a zone is written in the cells of its range and in
the plenum rows its gas writer wrote. A cell that no zone wrote stops ICB (`[ERROR] build_IC block <b>, <type> phase <name>: <n> of <N> cells are initialised by no zone (first cell (i,j,k))`, followed by the cells written after each zone) instead of reaching the IC file with the content of unset memory. Under an omega turbulence model (k-omega, Reynolds stresses) the turbulence bands that no zone sets are refused in the same way; under SA they are reported with a `[WARNING]`.
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

## Keys of pre-2026 decks

ICB reads the keys of its input reference only; a key it does not read stops the tool (or is reported
under `strict-keys = F`). Decks of the earlier ATLAS generation carry names that have a current
equivalent or no equivalent at all:

| Key of older decks | Use instead |
|---|---|
| `CEA-CEAfile`, `CEA-of`, `CEA-section` | `eq-CEA-file` (+ `eq-CEA-section`) |
| `oldsolution` | `old-solution` |
| `law` | `interpolation-law` |
| `oldid` | `old-block-id` |
| `oldmesh`, `R1`, `uTF` | no equivalent: remove them (the mesh of the old solution comes with the file) |
| `law = extrude` (with `nz`, `theta`) | `interpolation-law = extrude` with `nz` and `theta` (see above) |
