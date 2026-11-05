# Profiles From Tables

**Tool:** ICB · **Case:** `test/ICB/IG-species-profile-linear` · **Run time:** under a second

A mixture whose composition changes along the block: the mass fraction of H2 rises linearly with x, that of N2 falls,
O2 stays constant. A `variable` zone reads each varying quantity from a table.

## What You'll Learn

- How a `type = variable` zone mixes constants and tables
- The form of a 1-D table and of its `<key>-file` and `<key>-direction` keys
- Why the tables of mass fractions must sum to 1 with the constants

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | One 2-D block of 6 × 3 cells of uneven length, x from 0 to 1 m |
| `phase.txt`, `thermo.dat` | A gas of three species, H2, O2 and N2, and their tables |
| `yH2.dat`, `yN2.dat` | The profiles of H2 and N2 against x |
| `input.ini` | The initial state |

```ini
[ICB-Block1]
direction = y
zone1 = mix
range1 = 0.0 1.0

[mix]
type = variable
p = 100000.0
T = 300.0
yH2-file = yH2.dat
yH2-direction = x
yO2 = 0.25
yN2-file = yN2.dat
yN2-direction = x
```

The block is one zone, `mix`; its keys are constants (`p`, `T`, `yO2`) or tables (`yH2-file`, `yN2-file`), each table
read along its own direction. The tables are two columns, the coordinate and the value:

=== "yH2.dat"

    ```text
    # x yH2 (yH2 = 0.1 + 0.4 x)
    0.0 0.1
    1.0 0.5
    ```

=== "yN2.dat"

    ```text
    # x yN2 (yN2 = 1 - yO2 - yH2 = 0.65 - 0.4 x)
    0.0 0.65
    1.0 0.25
    ```

The value at a cell centre is interpolated linearly between the rows. The mass fractions of every cell must sum to 1:
ICB renormalises a deviation up to 1e-3 with a warning and stops beyond it, so `yN2.dat` is written as the complement
of the other two.

## Run It

```bash
mkdir -p ~/atlas-tutorials/icb-profiles && cd ~/atlas-tutorials/icb-profiles
cp $ATLASDIR/test/ICB/IG-species-profile-linear/{input.ini,mesh.tec,phase.txt,thermo.dat,yH2.dat,yN2.dat} .
ATLAS ICB
```

## What It Writes

`fromATLAStoSolver/ic.tec`, with a density band per species, `rho1`, `rho2`, `rho3` (in the order of `phase.txt`), then `u`, `v`,
`p`. Along x the mass fraction of H2 goes from 0.12 to 0.47 in the six cells, that of N2 from 0.63 to 0.28, and the
density of the mixture follows its composition, from 0.45 to 0.16 kg/m³ at the same p and T. The test of this case
checks every cell against the analytic values.

## Try Next

- The same keys work for the other quantities: `T-file`, `p-file`, `mach-file`, `vel-file`, each with its
  `<key>-direction` ([ICB Input Reference](../../user-guide/icb/input-reference.md)).
- Split the block into several `variable` zones, each with its own tables ([Zones in a Block](zones.md)).

---

Next: [Restart From Another Solution](restart.md)
