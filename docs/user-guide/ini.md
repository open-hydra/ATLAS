# INI Files

Every ATLAS tool reads its setup from an INI file, `input.ini` in the case directory unless `--input <file>` names
another. A tool reads only the sections of its own namespace (`[GPB-*]`, `[BCB-*]`, `[ICB-*]`, `[STB-*]`, `[MDB-*]`,
`[KAnT-*]`), the sections these name (a boundary condition, a zone), and `[ATLAS-Parameters]`: one file can hold
the whole case, which is what the [ATLAS GUI](gui.md) writes.

```ini
[ATLAS-Parameters]     ; shared by the tools
MG-levels = 2

[GPB-Phase1]           ; GPB
name = gas
...

[BCB-Block1]           ; BCB: face1 names the section [inflow]
face1 = inflow
...

[inflow]
type = inlet
...

[ICB-Block*]           ; ICB: every block without a section of its own
...
```

## Shared Parameters

`[ATLAS-Parameters]` holds the keys that several tools read:

| Key | Default | Read by | Meaning |
|---|---|---|---|
| `BCB-file`, `ICB-file`, `STB-file`, `MDB-file` | `input.ini` | that tool | another INI file for the sections of that tool (its *deck*) |
| `MG-levels` | `1` | BCB, MDB | number of multigrid levels: BCB writes one BC file per level, MDB cuts at multiples of 2^(MG-levels − 1) |
| `IC-format` | `tec` | ICB | format of the initial field: `tec`, `tec-binary`, `vtk`, `vtk-binary`, `vtk-ascii`, `vtk-raw` |
| `BC-force-connect` | `T` | BCB | connect the cells of any face that coincide with a cell of another block ([Block Connectivity](bcb/connectivity.md)) |
| `BC-chimera` | `F` | BCB | run the overset search on the faces declared `chimera` |
| `BC-force-chimera` | `F` | BCB | extend the overset search to every unresolved face |
| `strict-keys` | `T` | BCB, ICB, STB, MDB | `F` turns the errors on unknown keys and on sections written twice into warnings (below) |

Logical keys take `T` or `F`. The full tables are in the input reference of each tool.

## What The Tools Check

The section headers of `input.ini` and of a `<tool>-file` deck are checked when the file is read. A section
written twice with copies that differ stops the tool:

```text
[ERROR] section [<name>] of <deck>: declared twice (lines <n1> and <n2>), the second is ignored: merge them
```

Two copies with the same keys and the same values (blank lines, comments and the order of the keys do not count;
values are compared as written) give that message as a `[WARNING]`.

BCB, ICB and STB accept only the keys they read; the tables of their input references are generated from the same
registry. A key a tool does not read stops it, with the closest known key as a hint:

```text
[ERROR] key T00 of section [inflow]: unknown key (did you mean T0?)
```

For a key of an older deck that was renamed (`rt` became `g`) the hint names the new key. Keys with the prefix
`ignore-` are never read: `ignore-note = draft` is a comment that the GUI keeps.

`strict-keys = F` in `[ATLAS-Parameters]` turns into a `[WARNING]` the error on an unknown key, on a key the
resolved BC type does not honour, on a `y<species>` of a species that no phase of the run declares, and on two
differing copies of a section (the first copy is then used).

Wrong values are always errors, whatever `strict-keys`:

- a numeric key whose value is not a number: `g = abc`, `g = 8,5` (decimal comma);
- two numbers for a key that takes one: `T0 = 300 400` gives `value 300 400 is not one number` (list keys such as
  `center = 0 0 0` take several);
- a logical key that is not `T` or `F`;
- a value outside the set or the range of the input reference: `axis = w`, `n-repeat = 0`,
  `interpolation-law = nearest`, `IC-format = hdf5`. The values of these keys are case-sensitive: `Outlet` is
  not `outlet`.

```text
[ERROR] key g of section [inflow]: value abc is not a number
```

Section names are free (a boundary section, a zone, the section of another tool in a combined file), but a key
that a tool knows, found in a section of the `ATLAS-` or of its own namespace that it never reads, is reported:

```text
[WARNING] key IC-format is ignored in section [ATLAS-General]
```

(the key belongs to `[ATLAS-Parameters]`). MDB does not check the keys of `[ATLAS-Parameters]`: an unknown key
there is ignored. GPB checks its keys on its own, as described in the [GPB guide](gpb/ideal-gas.md#checks-and-messages).

## Mass Fractions

The `y<species>` keys of a BC section or of an ICB zone give mass fractions, one number each in [0, 1], that must
sum to 1: within 1e-3 they are renormalised with a `[WARNING]`, beyond it the section is refused. A section of a
multi-species phase that gives neither `y<species>` keys nor `eq-CEA-file` is refused (every mass fraction would
be 1e-20). The details are in [BC Types](bcb/bc-types.md#inlet) and [IC Strategies](icb/ic-strategies.md#species-profiles).
