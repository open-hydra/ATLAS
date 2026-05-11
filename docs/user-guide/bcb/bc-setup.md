# BCB Boundary Condition Setup

This page covers the full BCB input setup:

- global parameters and solver settings (`[ATLAS-Parameters]`);
- block-level face assignment (`[BCB-BlockN]`);
- uniform, spatially-varying, and multipatch BC definitions;
- special multipatch cases;
- multigrid considerations

---

## Block Face Mapping

BCB assigns BCs to block faces based on the face mapping defined in the `[BCB-BlockN]` sections. Each face of a block is numbered according to the following convention:

<figure style="margin-top: -90px; margin-bottom: -90px; overflow: hidden;">
  {% include "user-guide/bcb/images/block-faces.svg" %}
</figure>

!!! warning
    The face numbering convention is fixed and cannot be changed. It is the user's responsibility to ensure that the mesh and the BC sections follow the user's intended mapping.

---

## File Structure

A BCB input file is a standard INI file with three kinds of sections:

1. **`[ATLAS-Parameters]`** — optional global solver settings.
2. **`[BCB-BlockN]`** — one per mesh block; maps each face to a named BC section.
3. **Named BC sections** — define the actual boundary condition models.

```ini
[ATLAS-Parameters]
MG-levels = 2

[BCB-Block1]
face1 = inlet_main
face2 = out
face3 = symmetry
face4 = wall_hot

[inlet_main]
type = inlet
g = 2000.0
T = 300.0

[out]
type = outlet
p = 1.0

[wall_hot]
type = wall
T = 1200.0
```

### `[ATLAS-Parameters]` keys

| Key | Default | Description |
|-----|---------|-------------|
| `BCB-file` | `input.ini` | Path to the BCB INI input file |
| `MG-levels` | `1` | Number of multigrid grid levels to generate |
| `BC-force-connect` | `true` | Automatically resolve block-to-block connections |
| `BC-chimera` | `false` | Enable chimera/overset connectivity workflow |

### `[BCB-BlockN]` keys

| Key | Description |
|-----|-------------|
| `face1` … `face6` | Name of the BC section assigned to each face (up to 6 for 3-D blocks) |
| `phase` | Space-separated list of phase names active in this block (omit to use all phases) |

If a face is not listed an error is generated. Except for 2-D plane or axisymmetric meshes, in these cases BCB automatically assigns `null` or `axisymmetric` to face 5 and face 6.

**Multi-phase example** — restricting a block to a single phase:

```ini
[BCB-Block1]
phase = gas
face1 = symmetry
face2 = out

[BCB-Block2]
phase = solid
face1 = wall_hot
face2 = symmetry
```

---

## Spatially-Varying BCs

### Uniform (single patch)

The simplest case: one BC section applied uniformly to the whole face.

```ini
[BCB-Block1]
face4 = wall_hot

[wall_hot]
type = wall
T = 500.0
```

### Varying via external file

A single-patch face can have spatially-varying scalar data read from external ASCII files.
Add a `direction` key to specify the coordinate direction and add one or more `*-file` keys
pointing to data files.

```ini
[isoth]
type = wall
direction = xt          ; variation along x and theta
T-file = Twall.dat      ; two-column or tabular data file
```

Supported `direction` values:

| String | Meaning |
|--------|---------|
| `x`, `y`, `z` | Cartesian coordinates |
| `r`, `t` | Cylindrical radius and theta (degrees in the file, converted internally) |
| `i`, `j`, `k` | Mesh indices (triggers index-based cell assignment) |

Two-direction combination strings (`xt`, `rt`, `xy`, …) activate 2-D bilinear interpolation.

Supported `*-file` keys: `ks-file`, `q-file`, `T-file`, `Tref-file`, `hconv-file`, `qrad-file`,
`eps-file`, `alpha-file`, `beta-file`, `g-file`, `krho-file`, `a-file`, `n-file`, `pRef-file`,
`rhoGrain-file`, `Taf-file`, `SFgeo-file`, `SF-file`.

Mass-flux varying along `y` from a file:

```ini
[inflow]
type = inlet
direction = y
g-file = mfile.txt
T0 = 500.0
```

When `direction` is coordinate-based (`x`/`y`/`z`/`r`/`t`) and a `*-file` key is present,
BCB reads the file and interpolates linearly (1-D) or bilinearly (2-D) for each cell.

When `direction` is index-based (`i`/`j`/`k`) and a `*-file` key is present, the `file-direction`
key can select a different spatial coordinate for the file lookup:

```ini
[isoth]
type = wall
direction = j
file-direction = y
T-file = Twall.dat
```

---

## Multipatch BCs

A multipatch section divides one face into regions, each handled by a different BC section.
Regions are defined by `patchN` / `rangeN` pairs under a common parent section that carries
the `direction` key.

### 1-D multipatch (coordinate)

```ini
[left]
direction = y
patch1 = symmetry
range1 = 0.0 0.1
patch2 = inflow
range2 = 0.1 1.0

[inflow]
type = inlet
p0 = 3.0
T0 = 500.0
```

Each `rangeN` is a pair of coordinate bounds along `direction`. Cells whose coordinate falls
inside `(range_lo, range_hi]` get the corresponding `patchN` BC.

### 1-D multipatch (index)

```ini
[left]
direction = j           ; mesh index along j
patch1 = symmetry
range1 = 1 24
patch2 = inflow
range2 = 25 60
```

When `direction` is `i`, `j`, or `k`, ranges are integer cell indices (1-based).

### 2-D multipatch (two coordinates)

Combine two direction characters to partition a face in two dimensions:

```ini
[plate]
direction = rt
patch1 = inj1
range1 = 0.0 1.5e-3 -30.0 30.0
patch2 = adiabatic
range2 = 1.5e-3 9.5e-3 -30.0 30.0
patch3 = inj2
range3 = 9.5e-3 12.5e-3 -6.0 6.0
patch4 = adiabatic
range4 = 9.5e-3 12.5e-3 6.0 30.0
```

Each `rangeN` is four numbers: `r_lo r_hi theta_lo theta_hi`.

Cells are assigned to the **first** patch whose range they fall within. Ranges may overlap —
order matters.

### Multipatch via file (`range-file`)

For injector-plate style setups, you can drive multipatch assignment from an external file
instead of `patchN` / `rangeN` pairs.

Use a parent section with:

- `direction` (typically `y` for plate-like layouts)
- `range-file` (path to the injector map file)
- `inner-patch` (BC section used for cells mapped to an injector)
- `outer-patch` (BC section used for cells not mapped to any injector)

In this mode, the parent section does not need a `type` key.

```ini
[BCB-Block1]
face1 = plate
face2 = extrapolation
face3 = extrapolation
face4 = extrapolation

[plate]
direction = y
range-file = plate.txt
inner-patch = inflow
outer-patch = isoth

[inflow]
type = inlet
p0 = 10d+5
T0 = 300
yN2 = 0.7435
yO2 = 0.228
yH2 = 0.0285

[isoth]
type = wall
T = 300
```

The file pointed to by `range-file` is used to identify injector regions on the target face.
Cells inside injector regions receive `inner-patch`; all remaining cells receive `outer-patch`.

---

## Multigrid

When `MG-levels > 1` in `[ATLAS-Parameters]`, BCB runs the full BC assignment loop for each
grid level. Each coarser grid is obtained by halving the node count in every direction (`Ni/2`,
`Nj/2`, `Nk/2`). Grid dimensions must be divisible by `2^(MG-levels − 1)` in each direction
(BCB checks this at startup and stops with an error otherwise).

The same INI file produces BC files for all levels; there is no per-level configuration.
Output files are distinguished by the level suffix (see [Output Files](./output)).

```ini
[ATLAS-Parameters]
MG-levels = 3
```

## Notes

- For BCs that require input (`periodic`, `wall`, `inlet`, `manifold`, `srm`), that section must include `type = ...`.
- For BCs without required input (`null`, `axisymmetric`, `extrapolation`, `connection`, `chimera`, `symmetry`, `outlet`), a further section is not needed.
- `connection` and `chimera` are geometry/connectivity-driven. They generally do not need scalar parameters in the section.

## Next

- [BC Types](./bc-types.md)