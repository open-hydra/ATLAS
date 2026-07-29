# Block Connectivity — `connection` and `chimera`

BCB couples blocks in two different ways. They are not interchangeable: they have
different mesh requirements, different accuracy, and different failure modes.
This page describes how each is resolved, what the mesh must provide, and where
the limits are.

| | `connection` | `chimera` |
|---|---|---|
| Mesh requirement | interfaces conform: matching face centers | blocks overlap in space |
| Coupling | one receiver facelet ↔ one donor cell | receiver ghost cell ↔ weighted set of donor cells |
| Conservative | yes | no (interpolation) |
| Cost | cheap (distance search) | overlap search over donor cells |
| Output ID | `101` (`103` across phases) | `102` |

!!! tip "Prefer `connection` whenever the mesh allows it"
    If the two grids share the interface facelets, `connection` is exact,
    conservative and much cheaper. Reach for `chimera` only when the grids
    genuinely do not conform.

---

## `connection`

Two facelets are connected when their **face centers coincide within `1e-7`**
(Euclidean distance, in mesh units — the tolerance is absolute, so it is a real
constraint on how you write the mesh file). The orientation map `c1..c4` in the
output is then derived from the covariant/contravariant bases of the two faces,
so the blocks may be rotated or index-reversed with respect to each other.

Requirements:

- The interface must be discretised identically on both sides: same facelet
  count and same node positions on the shared surface. The distribution *normal*
  to the interface is free — the two blocks may be refined differently in the
  direction crossing the interface.
- Matching is searched **between different blocks only**. A face cannot connect
  to another face of the same block; use `periodic` for that.
- `BC-force-connect` (default `true`) extends the search to facelets whose BC is
  not `connection`, so a large face declared `symmetry` will pick up the
  facelets that happen to match a neighbouring block and keep symmetry
  elsewhere. Set it to `false` to search only the declared `connection` faces,
  which is faster on large meshes.

---

## `chimera`

Enabled with `BC-chimera = true`. For every receiver facelet BCB takes the
**two ghost cells** behind it and finds all donor cells that overlap them:

- Donors are the **interior** cells of the **other** blocks. A block never
  donates to itself, and the ghost cells of a donor block are not donors.
- Each donor's weight is its intersection volume divided by the total
  intersection volume of that ghost cell, so the weights of one ghost layer
  **sum to 1**. Donors contributing less than `1e-6` of the receiver cell volume
  are dropped.
- The `i` and `j` faces are always searched; the `k` faces only on a full 3-D
  mesh.
- `chimera.log` lists every receiver with its total intersected volume against
  its real volume. A ratio below 1 means the ghost cell is only partly covered
  — see [Limitations](#limitations).

`BC-force-chimera` (default `false`) extends the search to every unresolved
facelet whatever its declared type, for partial interfaces — a block facing only
a strip of a larger one. Facelets that find donors become `102`; those that do
not keep their own BC. Leave it off when the overlap regions are declared
explicitly: BCB then only searches the `chimera` faces, which is considerably
faster.

Ordering: `connection` is always resolved first, so with `BC-chimera = true` a
face declared `connection` keeps its exact matching. Only the facelets matching
failed on are handed to the overset search.

---

## Limitations

!!! warning "Partially covered facelets are reported as if fully covered"
    This is the limit to keep in mind when generating a mesh for chimera.

    At the rim of an overlap a receiver ghost cell is only partly inside the
    donor block — say a fraction φ of its volume. BCB still normalises the donor
    weights to sum to 1, so the payload looks exactly like a fully covered cell:
    **the coverage fraction φ is not written to `bc.txt` and cannot be recovered
    from it**. The solver has no way to know the facelet is a hybrid, and applies
    the interpolated flux over its *whole* area.

    Consequences on such a facelet:

    - the ghost state is reconstructed from whatever sliver is covered, which for
      small φ is an extrapolation rather than an interpolation;
    - mass, momentum and energy crossing it are over-counted by roughly `1/φ`,
      because the uncovered part is physically a wall or a symmetry plane that
      should carry no mass or energy flux at all;
    - the momentum balance additionally loses the pressure force acting on the
      uncovered part.

    For an internal flow this is a steady, one-signed error that accumulates —
    do not size a duct or a pipe interface so that its rim lands in the middle
    of a coarse cell.

    **What to do**: make overlaps end on a cell boundary rather than mid-cell,
    or make the interface conform and use `connection`, which has no partial
    facelets — a facelet there is either fully matched or not matched at all.
    `chimera.log` tells you which receivers are affected: compare the reported
    total volume with the real volume.

!!! danger "Both ghost layers must find donors"
    The overlap has to be deep enough to contain **two** ghost cells of the
    receiver, measured against the donor block's *interior* cells. If the second
    layer finds nothing BCB writes a donor count of `0` for it, and MOSE aborts
    at read time (`... donor volume fractions summing to ~0 ...`).

    Ghost cells are built by linear extrapolation of the boundary nodes, not
    from the donor mesh, so on a strongly curved or stretched boundary they
    drift away from the true geometry. Leave margin beyond the bare two cells.

!!! danger "A `chimera` face that finds no donor at all is silently inert"
    Such a facelet keeps ID `100` (the unresolved connectivity marker). MOSE has
    no case for `100`: the line is read without error and no boundary flux is
    ever applied to that facelet. Nothing warns you at run time. Check the ID
    histogram of `bc.txt` for `100` entries before running.

!!! note "Overset coupling is not conservative"
    Even with full coverage, the two sides of a chimera interface solve
    independent Riemann problems on interpolated states, so the mass leaving one
    block does not exactly equal the mass entering the other. This is inherent
    to the method, not a BCB limitation. Where conservation matters, use
    `connection`, or correct the interface mass flux globally in the solver.

---

## Checklist for mesh generation

- Conforming interface? Use `connection`, and write the shared nodes so the face
  centers agree to better than `1e-7`.
- Overlapping grids? Give at least two receiver cells of overlap, plus margin
  where the boundary is curved or stretched.
- Ending an overlap part-way across a face? Align the rim with a cell boundary
  of the coarser block.
- After running BCB: no `100` in `bc.txt`, no donor count of `0`, and
  `chimera.log` closure at 1 for every receiver you care about.

## Next

- [BC Types](./bc-types.md)
- [Output Files](./output.md)
