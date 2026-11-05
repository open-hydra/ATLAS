# Inlets From Reservoir Conditions

**Tool:** BCB · **Case:** `test/BCB/IG-nozzle-arearatio` · **Run time:** under a second for each run

Three inlets fed by the same reservoir at 10 bar and 300 K: a subsonic inlet, a supersonic inlet at Mach 2, and the exit
of an injector nozzle of area ratio 2.5. BCB picks the inlet variant from the keys a section gives; for the last two
it expands the reservoir state on the species table of the gas.

## What You'll Learn

- How the keys of an `inlet` section select its variant (`401`, `405`, `420`)
- Why the expanding variants need `thermo.dat`, and what BCB computes from it
- How to run one tool on several INI files in one case directory (`-i`)

## The Case

| File | What it is |
|---|---|
| `mesh.tec` | A block of 2 × 2 × 1 cells: the inlet is face 1 |
| `phase.txt` | One species, `inertMix`, of molar mass 28.96 g/mol: air as one gas |
| `thermo.dat` | Its table: cp of a calorically perfect gas (γ = 1.4) from 1 K to 1000 K |

The three INI files, in `test/tutorials/bcb-reservoir-inlets/`, differ in the section `[inflow]` only. `subsonic.ini`:

```ini
--8<-- "test/tutorials/bcb-reservoir-inlets/subsonic.ini"
```

and `supersonic.ini` and `nozzle.ini`, the same file with these sections:

=== "supersonic.ini"

    ```ini
    --8<-- "test/tutorials/bcb-reservoir-inlets/supersonic.ini:9:13"
    ```

=== "nozzle.ini"

    ```ini
    --8<-- "test/tutorials/bcb-reservoir-inlets/nozzle.ini:9:13"
    ```

| Keys | Variant | What the solver imposes |
|---|---|---|
| `p0`, `T0` | `401`, total conditions | the reservoir state; the flow through the face follows from the pressure inside |
| `mach`, `p0`, `T0` | `405`, supersonic | the whole state: static `T` and `p` from the expansion to Mach 2 |
| `Ae_At`, `p0`, `T0` | `420`, injector nozzle | the mass flux `g` of the choked nozzle, between the pressures `psub` and `psup` |

## Run It

```bash
mkdir -p ~/atlas-tutorials/bcb-inlets && cd ~/atlas-tutorials/bcb-inlets
cp $ATLASDIR/test/BCB/IG-nozzle-arearatio/{mesh.tec,phase.txt,thermo.dat} .
cp $ATLASDIR/test/tutorials/bcb-reservoir-inlets/*.ini .
ATLAS BCB -i subsonic.ini   && cp fromATLAStoSolver/bc.txt bc-subsonic.txt
ATLAS BCB -i supersonic.ini && cp fromATLAStoSolver/bc.txt bc-supersonic.txt
ATLAS BCB -i nozzle.ini     && cp fromATLAStoSolver/bc.txt bc-nozzle.txt
```

Each run writes `fromATLAStoSolver/bc.txt` again: the copies keep the three.

## What It Writes

The values of the inlet cells, run by run:

```text
401   3.0000000000000000E+02,  1.0000000000000000E+06,         normal,         normal,  1.0..., 1.0...
405   2.0000000000000000E+00,  1.6666725764319145E+02,  1.2780369023906579E+05,         normal,  ...
420   3.0000000000000000E+02,  1.0000000000000000E+06,  9.6084929849019449E+05,  6.3985014825673243E+04,  9.3333189507807913E+02, ...
```

- `401`: `T0`, `p0`, the direction (`normal`, `normal`), the relaxation factor, the mass fraction. BCB writes the
  reservoir as given.
- `405`: `mach`, then the static state of the isentropic expansion: T = 166.67 K and p = 1.278 bar. For this gas of
  constant cp they are the textbook values, T0 / (1 + 0.2 M²) and p0 / (1 + 0.2 M²)^3.5; for a gas whose cp varies BCB
  integrates the table.
- `420`: `T0`, `p0`, then `psub` = 9.608 bar and `psup` = 0.640 bar, the exit pressures of the nozzle with a
  subsonic and with a supersonic exit, and the mass flux `g` = 933.3 kg m⁻² s⁻¹ of the choked throat divided by
  2.5. The test that holds this case compares them with an independent integration of the same table (`test/BCB/IG-nozzle-arearatio/input.ini`
  gives the numbers).

!!! note "The table must hold the expansion"
    The supersonic exit of the nozzle is at about 137 K: `thermo.dat` must reach below it, which is why this one starts at
    1 K. With a table that starts at 200 K, BCB stops:
    `[ERROR] Ae_At: supersonic exit temperature below the range of thermo.dat`.

## Try Next

- Remove `thermo.dat` and run `supersonic.ini`: BCB stops, since the `p0`, `T0` form of `405` needs the table
  (`... requires the species thermo table (thermo.dat not found): give p and T instead`). Give `p = 1.278e+5` and
  `T = 166.67` in place of `p0` and `T0`, and it runs without one.
- Give the nozzle by its mass flux and pressures (`g`, `psub`, `psup`) instead of `Ae_At`: the test case
  `test/BCB/IG-inflow-nozzle` does it, with the composition of a CEA equilibrium (`eq-CEA-file`).
- The full list of variants and their keys is in [BC Types](../../user-guide/bcb/bc-types.md#inlet).

---

Next: [Boundary Data From Tables](data-files.md)
