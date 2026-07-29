# BCB Output Files

BCB writes plain-text BC files into `fromATLAStoSolver/` (created automatically if absent).

The files are consumed directly by all Hydra solvers.

The format is designed to be simple and flexible, with a fixed coordinate line followed by a variable payload depending on the BC type. See [File Format](#file-format) for details.

---

## Output Files

One file is produced per phase type, hence one file per Hydra solver. The naming depends on the phase name and the multigrid level:  

- For a single unnamed phase: `bc.txt`, `bc2.txt`, etc.
- For named phases: `<phase_name>-bc.txt`, `<phase_name>-bc2.txt`, etc.

The phase name prefix is added only when the phase has a non-empty name. For a single unnamed phase the file is simply `bc.txt`.

Example with two phases `gas` and `solid` and `MG-levels = 2`:

```
fromATLAStoSolver/
  gas-bc.txt       ← gas, level 1
  gas-bc2.txt      ← gas, level 2
  solid-bc.txt     ← solid, level 1
  solid-bc2.txt    ← solid, level 2
```

---

## File Format

The file contains one record per boundary face cell. Each record is composed of a coordinate line followed by zero or more payload lines, depending on the BC type.

### Coordinate line

Every record starts with a coordinate line identifying the cell:

| Mesh type | Format | Fields |
|-----------|--------|--------|
| 1-D  | `4I8` | `block  i  face  id` |
| 2-D  | `5I8` | `block  i  j  face  id` |
| 3-D  | `6I8` | `block  i  j  k  face  id` |

- `block` — 1-based block ID (assigned per phase; blocks not associated with the current phase are skipped).
- `i`, `j`, `k` — 1-based cell indices on the face.
- `face` — face number within the block (1–6 for 3-D, 1–4 for 2-D, 1–2 for 1-D).
- `id` — BC type ID (see table below).

### Payload line

Depending on `id`, zero, one, or more additional lines follow the coordinate line.

---

## ID Reference

### IDs with no payload

| ID | BC type | Solver |
|----|---------|--------|
| `0` | Null | all |
| `200` | Axisymmetric | all |
| `300` | Symmetry | all |
| `400` | Extrapolation | all |

These records consist of the coordinate line only.

---

### `101` — Standard connection

Written for block-to-block connections after the automatic connection-finding pass.

**Payload line** (one line, all integers, `I8` format):

| 1-D | `b2  i2  f2  c1  c2  c3  c4` |
|-----|------------------------------|
| 2-D | `b2  i2  j2  f2  c1  c2  c3  c4` |
| 3-D | `b2  i2  j2  k2  f2  c1  c2  c3  c4` |

- `b2`, `i2`, `j2`, `k2` — neighbor block ID and cell indices.
- `f2` — neighbor face number.
- `c1..c4` — orientation map integers.

Example (3-D, `id = 101`):

```
       1       1       1       1       1     101
       2      25       1       1       2       1       0       0       1
```

---

### `102` — Chimera (overset)

Written after the chimera interpolation pass. Covers two ghost-cell layers inward from the face.

**Record structure** (multiple lines):

1. Counts line: `nchi_g1  nchi_g2` — number of donor cells for ghost layers 1 and 2 (`I8` format).
2. For ghost layer 1: `nchi_g1` donor lines, each `b  i  j  k  weight` (`4I8 + E20.10`).
3. For ghost layer 2: `nchi_g2` donor lines, same format.

`weight` is the donor's share of the receiver ghost cell, so the weights of one
ghost layer sum to 1. They are normalised over the donors that were found: a
ghost cell only partly inside the donor block produces the same payload as a
fully covered one, and how much of the facelet is actually covered is **not**
recorded. See [Block Connectivity](./connectivity.md#limitations) before relying
on it. A count of `0` for a layer means no donor was found and the BC file is
not usable.

Example (3-D, `id = 102`, 1 donor for layer 1, 2 donors for layer 2):

```
       1       1      30       1       4     102
       1       2
       2       1       1       1    0.1000000000E+01
       2       1       1       1    0.4514333088E+00
       2       1       2       1    0.5485666912E+00
```

---

### `103` — Multi-solver connection

Written for block-to-block connections in multi-solver setups. Similar to `101` but with a different ID to allow separate handling in the solver.

### `201` — Periodic

Identical payload structure to `101`/`103`.

Example (3-D, `id = 201`):

```
       1       1       1       1       1     201
       1      50       1       1       2       1       0       0       1
```

---

### `301`–`305` — Wall (MOSE/ARES solver)

| ID | Payload fields (in order) |
|----|--------------------------|
| `301` | `q, ks, eps` |
| `302` | `T, ks, eps` |
| `303` | `T, qrad, ks` |
| `304` | `qrad, ks` |

`ks` = roughness height; `eps` = wallemissivity; `q` = heat flux; `T` = wall temperature; `qrad` = radiative heat flux.

Example (`id = 301`, prescribed heat flux):

```
       1       1      21       1       1     301
    0.000000E+00,    0.000000E+00,    0.000000E+00,
```

---

### `301`–`305` — Wall (FUSS solver)

| ID | Payload fields (in order) |
|----|--------------------------|
| `301` | `q` (or time-file name) |
| `302` | `T` (or time-file name) |
| `303` | `hconv, qrad, Tref` |
| `304` | `eps, Tref` |
| `305` | `hconv, eps, Tref` |

`hconv` = convective heat transfer coefficient; `q` = heat flux; `T` = wall temperature; `qrad` = radiative heat flux; `eps` = wall emissivity; `Tref` = reference temperature for convective coupling.

!!! tip "Time-file option"
    For time-varying wall conditions, the payload line contains the time-file name string instead of numeric values.

Example (`id = 302`, prescribed wall temperature):

```
       1       1      21       1       1     302
    0.000000E+00,
```

---

### `401`–`420` — Inlet / Outlet (MOSE/ARES solvers)

| ID | Payload fields (in order) |
|----|--------------------------|
| `401` | `T0, p0, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `402` | `T0, <p0_time_file>, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `403` | `T0, g, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `404` | `T, g, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `405` | `mach, T, p, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `406` | `p, rf` |
| `407` | `T0, p0, p, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `408` | `T, un, alpha, beta, rf, massf(1:ns) [, turb…]` |
| `410` | `<time_file>, 'periodic'` |
| `420` | `T0, p0, psub, psup, g, alpha, beta, rf, massf(1:ns) [, turb…]` |

`p0`, `T0` = total pressure/temperature; `p`, `T` = static pressure/temperature; `g` = mass flux [kg m⁻² s⁻¹]; `un` = normal velocity [m s⁻¹]; `mach` = Mach number; `alpha`, `beta` = inflow direction angles (`normal,` sentinel when free-stream normal); `rf` = relaxation factor; `massf(1:ns)` = injected species mass fractions; `psub`/`psup` = subsonic/supersonic injector nozzle pressures.

!!! tip "Time-file option"
    For time-varying inlet conditions, the payload line contains the time-file name string instead of numeric values.

!!! note "Direction angles"
    For normal injection, write `normal,` in place of numeric `alpha` and `beta`.

For turbulence-specified inlets, the payload line is extended with additional fields depending on the turbulence model and (see [input reference](./input-reference) for details).

Turbulence suffix:

| Appended fields |
|----------------|
| `mit` |
| `kappa, omega` |
| `rhoR11, rhoR22, rhoR33, 1e-8, 1e-8, 1e-8, omega` |

---

### `401`–`403` — Inlet / Outlet (ICE/IGLOO solvers)  

| ID | Payload fields (7 numeric values + 1 string + 1 numeric, in order) |
|----|-------------------------------------|
| `401` | `krho, kV, alphap, betap, kT, rp, sigmap, distribution, ds` |
| `402` | `gp, velocity_magnitude, alphap, betap, Tp, rp, sigmap, distribution, ds` |
| `403` | `gp, kV, alphap, betap, Tp, rp, sigmap, distribution, ds` |

Field key: `krho`/`kV`/`kT` = scaling coefficients for mass/velocity/temperature wrt the gaseous phase; `gp` = mass flux; `alphap`/`betap` = direction angles; `Tp` = particle temperature; `rp` = particle radius; `sigmap` = variance coefficient; `distribution` = size-distribution law (a string); `ds` = injection-point spacing (last token, meters).

!!! note "Direction angles"
    For normal injection, write `normal,` in place of numeric `alphap` and `betap`.

!!! note "Distribution (8th field)"
    A string the solver maps to its size-distribution model: one of `Dirac`, `Normal`, `LogNormal`, `RosinRammler`, or a path to a two-column numeric file (any extension) tabulating the distribution by points. Resolved by BCB from the inlet's `distribution` option: `sigmap = 0` always yields `Dirac` (a zero-width delta, overriding any entry); a non-zero `sigmap` with no `distribution` set defaults to `LogNormal`.

!!! note "Injection spacing `ds` (9th field)"
    Per-population injection-point spacing in **meters** (the BCB `ds` input option is in cm and converted on write). `0.00000E+00` (option unset) tells the solver to fall back to its global `[IGLOO-BC] ds`; a positive value activates per-cell spacing for this population.

Example (DP inlet, `id = 402`, LogNormal, `ds` unset):

```
       2       1       1       1       1     402
   0.34500E+03   0.10000E+03   0.26000E+02   0.00000E+00   0.45000E+03   0.50000E-02   0.50000E+00 LogNormal   0.00000E+00
```

---

### `501` –  Manifold 

| ID | Payload fields (in order) |
|----|-----------|--------------------------|
| `501` | `block, face` |

`block`, `face` = source block/face index from which the manifold draws its conditions; 

### `502` — Solid rocket motor (SRM) grain burning

| ID | Payload fields (in order) |
|----|-----------|--------------------------|
| `502` | `Taf, a, n, pRef, rhoGrain, SF, massf(1:ns) [, turb…]` |

`Taf` = adiabatic flame temperature [K]; `a` = burn rate pre-exponential coefficient; `n` = burn rate pressure exponent; `pRef` = reference pressure [Pa]; `rhoGrain` = propellant grain density [kg m⁻³]; `SF` = geometric scale factor (default 1); `massf(1:ns)` = species mass fractions. Turbulence suffix same as inlet IDs (depends on `nrans`).

Example (`id = 502`, single-species, no turbulence):

```
       1       1      20       1       4     502
    0.342053E+04,    0.520000E-02,    0.350000E+00,    0.482900E+07,    0.175000E+04,    0.100000E+01,    0.100000E+01,
```

---

## Record Order

Within each file, records are written in the following nested loop order:

1. Blocks (in block index order, skipping blocks not associated with the current phase).
2. Faces within each block (face 1 to `nfaces`).
3. Cell indices `n` then `m` across the face.

For face `f`, the `m` and `n` dimensions map to:

| Face | `m` direction | `n` direction |
|------|--------------|--------------|
| 1, 2 (i-faces) | j | k |
| 3, 4 (j-faces) | i | k |
| 5, 6 (k-faces) | i | j |

