# Gas-Surface Interaction

**Tool:** BCB · **Cases:** `test/BCB/IG-ablation`, `IG-melting`, `IG-pyrolysis` · **Run time:** under a second

A wall that reacts with the gas: a surface that ablates, melts or pyrolyses and injects what it produces. One section
type, `gsi`, covers them all: BCB chooses the model from the keys the section gives.

## What You'll Learn

- How a `gsi` section selects its model (`502` to `506`)
- What each model carries in its record
- How the model codes are written (`surface-reactions = bradley` → `1`)

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | One block of 50 × 20 cells, one cell thick: a 2-D planar mesh; the surface is face 4 |
| `phase.txt` | An ideal gas of three species (written by hand for the test) |
| `input.ini` | The boundary conditions |

```ini
[BCB-Block1]
face1 = symmetry
face2 = symmetry
face3 = symmetry
face4 = grain

[grain]
type = gsi
surface-reactions = bradley
qrad = 1.0e6
```

`surface-reactions = bradley` selects the surface-reaction model, `505`; `qrad` is the radiative heat flux on the
surface (W/m²).

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-gsi && cd ~/atlas-tutorials/bcb-gsi
cp $ATLASDIR/test/BCB/IG-ablation/{input.ini,mesh.tec,phase.txt} .
ATLAS BCB
```

## What It Writes

In `fromATLAStoSolver/bc.txt`, the 50 cells of face 4 are `505` records:

```text
       1       1      20       1       4     505
       1,  1.0000000000000000E+06,  0.0000000000000000E+00,
```

The model code (`bradley` → `1`, an integer: the solvers read it as one), `qrad`, and the emissivity `eps`, 0 when not
given. `505` and `506` write no mass fractions: the composition of what the surface releases comes from the reaction
model, and for `506` that of the pyrolysis gas from a GPB table.

The other models from the same section type:

| Keys of the `gsi` section | Model | Record |
|---|---|---|
| `cp`, `dh`, `T` (melting temperature) and `qrad`; `Ti`, `y<species>` | melting | `503` |
| `pyrolysis-model` and `qrad`; `y<species>` | pyrolysis (`HTPB`, `HDPB`, `PP`) | `504` |
| `surface-reactions` and `qrad` | surface reactions | `505` |
| `surface-reactions`, `pyrolysis-gas`, `phi`, `hv0` and `qrad` | pyrolysing ablator: surface reactions of the char and the pyrolysis gas of a [GPB table](../../user-guide/gpb/pyrolysis.md) | `506` |
| none of the sets above: `eq-CEA-file`, `a`, `n`, `pRef`, `rhoGrain`, `SF` | solid propellant, burning at r = a (p/pRef)ⁿ, its flame temperature and products from CEA | `502` |

BCB tests the sets in this order and the first that matches wins. The solid propellant is what is left: a section
meant for another model that lacks a key (`qrad`, most often) is read as a propellant, and BCB then stops on a missing
burn-rate key.

To see a melting and a pyrolysing surface, run the cases `test/BCB/IG-melting` and `test/BCB/IG-pyrolysis` in the same
way: their `[grain]` sections give the keys of `503` and `504`. `test/BCB/IG-carbon-phenolic` is the pyrolysing
ablator (`506`) on the same mesh.

## Try Next

- [BC Types](../../user-guide/bcb/bc-types.md#gsi) lists every key of the five models and their defaults.

---

Next: the [initial fields](../icb/index.md).
