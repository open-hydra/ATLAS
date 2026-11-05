# A Volumetric Heat Source

**Tool:** STB · **Cases:** `test/STB/uniform`, `test/STB/x-variable` · **Run time:** under a second

A power density deposited in the gas, the same everywhere or varying along the block: STB writes it cell by cell in
the file the solvers add to their energy equation.

## What You'll Learn

- How `qvol` gives a uniform source and `qvol-file` with `direction` a profile
- What STB writes, and in which formats

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | One 3-D block of 120 × 40 × 1 cells, x from -273 to 1135 |
| `qvol.txt` | The profile: the source (W/m³) against x |
| `input.ini` | The source terms |

A uniform source, from `test/STB/uniform`:

```ini
[STB-Block1]
qvol = 3.0
```

A profile, from `test/STB/x-variable`:

```ini
[STB-Block1]
direction = x
qvol-file = qvol.txt
```

with `qvol.txt` a two-column table, the coordinate and the power density, linear between its rows:

```text
-500.0 0.0
1500.0 100.0
```

A block without an `[STB-BlockN]` section is written with `qvol = 0`.

## Run It

```bash
mkdir -p ~/atlas-tutorials/stb-uniform && cd ~/atlas-tutorials/stb-uniform
cp $ATLASDIR/test/STB/uniform/{input.ini,mesh.tec} .
ATLAS STB

mkdir -p ~/atlas-tutorials/stb-profile && cd ~/atlas-tutorials/stb-profile
cp $ATLASDIR/test/STB/x-variable/{input.ini,mesh.tec,qvol.txt} .
ATLAS STB
```

STB says what it built, block by block: `Block   1 - 1D distribution qvol using x`.

## What It Writes

`fromATLAStoSolver/st.tec`: the mesh and one cell-centred variable, `qvol`. In the first case it is 3.0 in every cell; in the
second it follows the table, from 11.6 in the first cell to 81.2 in the last.

Other formats: `ATLAS STB -- -o vtk` writes `fromATLAStoSolver/qvol.vtm` with the blocks under `fromATLAStoSolver/vtk/`, `-o tec-binary` an
`st.szplt` (with a TecIO build), `-o all` the Tecplot and the VTK files ([STB Output](../../user-guide/stb/output.md)). The option goes after
`--`: `ATLAS` passes what follows to the tool.

## Try Next

- A source computed on another mesh (a neutronics tally, in W per cell or W/m³), remapped conservatively onto this
  one: `qvol-file` with no `direction`, the case `test/STB/qvol-3D-conservative` ([STB](../../user-guide/stb/index.md)).

---

Next: [Area Tables for Q2D](area-tables.md)
