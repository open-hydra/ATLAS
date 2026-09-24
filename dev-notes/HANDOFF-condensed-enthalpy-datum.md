# HANDOFF — fix the condensed enthalpy datum **in ATLAS** (route B)

**For:** a fresh Claude session working in ATLAS (`utils/ATLAS`, remote `open-hydra/ATLAS`).
**Date:** 2026-09-09. Written from the hydra-MI2 side; every claim re-verified against source today.

> ## Read this first
> **`dev-notes/condensed-enthalpy-datum.md` (in this repo) is the analysis of record.** It is
> correct and thorough — the datum tables, why `cp·T` was always legitimate, where the level leaks,
> the A-vs-B algebra, the worked water numbers, and the `Lv`/vapour-column discussion. **Do not
> re-derive any of that.**
>
> **This file exists to record what has changed since it was written (2026-08-30), including a
> reversal of its §5 recommendation.**

---

## 1. The decision has changed — §5 of the observation doc is superseded

That document recommends **route A**: leave ATLAS alone, correct in the coupler.
**Route A was implemented, shipped, and measured. The user has now rejected it** and wants the datum
fixed at generation time in ATLAS — i.e. **route B**.

The doc's objections to B were not wrong and are still the cost you must plan for:

| objection (§5) | status |
|---|---|
| B shifts `sourceEn` by `ṁ·Δh`, so every IGLOO evaporation oracle must be regenerated | **still true — budget for it** |
| B needs an IGLOO change or it is a no-op (§6) | **still true — this is the crux, see §3** |
| `cp·T` is intentional for a variation-only table | true, but no longer decisive: the table now feeds an absolute energy balance |

So: B is a deliberate scope increase, not a bug fix. Treat the oracle regeneration and the IGLOO
edit as *in scope from the start*.

---

## 2. What exists now that did not on 2026-08-30

Route A is **live** in hydra-MI2 and gives you a free acceptance test:

- `src/app/MI2/MI2_Stoichiometry.f90` — `dhDatum(m)`, `Build_Datum_Offsets`, `T_datum_ref = 298.15`:
  `dhDatum(m) = Σ_s ν(m,s)·h_FLINT(s,T_ref) − ( h_IGLOO,liq(m,T_ref) + Lv(m) )`
- Applied in `MI2_Coupling.f90::IGLOOxMOSE`; escape hatch `[MI2-Coupling] datum-correction = false`.
- Measured on `test/evap-box-ta` (water, `cp = 4184`):
  `h_FLINT(H2O,298.15) = −1.3423515e7`, `h_IGLOO = +1.2474596e6` (= 4184×298.15 exactly),
  `Lv = 2.4624780e6` ⇒ **offset −1.7133453e7 J/kg** (hand-derived −1.71338e7, agrees to 2e-5).
  Correction ON ⇒ gas ΔT **−0.686 K**; OFF ⇒ **+2.874 K**. The sign flip is the discriminator.

### ⭐ You do not have to modify MI2, and this is your acceptance test

`hIGLOOref` is deliberately read as *whatever IGLOO itself would use*: the tabulated `hTab` value when
the material is `cpVariable`, `cp·T_ref` otherwise (see the setup block in `src/app/MI2/hydra_MI2.f90`
that calls `Build_Datum_Offsets`). Therefore:

- once the table is absolute **and IGLOO consumes it**, `hIGLOOref` becomes absolute and
  **`dhDatum → 0` by itself** — the coupler correction self-cancels rather than double-correcting;
- any material still on constant `cp` keeps `hIGLOOref = cp·T_ref`, and its correction stays correct.

**Acceptance criterion: run `test/evap-box-ta` and read the startup block
`[MI2] enthalpy-datum reconciliation`. When route B is complete, `=> datum offset applied by MI2`
must print ≈ 0 for the migrated material, and the gas ΔT must match the pre-change run.** MI2 already
prints all of this; you do not need to instrument anything.

---

## 3. The crux, restated because it decides your plan

§6 of the observation doc is right and I re-verified it today:

- `IGLOO/src/lib/IO.f90:109-127` — `cpVariable` is **auto-detected** from whether the Cp column
  varies; `hTab` is allocated **only** when it is true.
- `IGLOO/src/lib/obj_particles.f90:181-182` —
  `enthalpy = self%stateVar(7); if (.not.self%varCp) enthalpy = self%cp*enthalpy`.

So a constant-cp material never opens the Enthalpy column. **An ATLAS-only change is inert for
exactly the materials that have the problem.** The IGLOO half (allocate `hTab` whenever the column is
present; use `lookupTab(hTab, part%tp)` in `computeSource` regardless of `cpVariable`) must land
together with it. IGLOO is a **plain checkout, not a submodule** (`figaro submodule update` will not
touch it).

**Corpus check (new, empirical):** every dispersed case in hydra — `evap-box`, `evap-box-ta`,
`evap-box-ord2`, `evap-probe`, `JPL-Lagrangian-20micron`, `JPL-Eulerian-20micron`, `JPL-nomollify` —
sets `cp` under `[GPB-Phase2]`, so **all seven take the `fixed` branch** and all their shipped tables
satisfy `Enthalpy == Cp·T` exactly (verified numerically). The correct `cantera` path has **zero**
coverage: ATLAS's own `test/GPB/CP-Tvar-dispersed/` (`material = AL2O3(L)`, `thermo = Burcat`, no
`cp`) commits **no reference `properties.dat`**, so nothing asserts on enthalpy anywhere.

---

## 4. Findings not in the observation doc

1. **A second `KeyError` hole, symmetric to the known one.** The doc lists `SP-database` + dispersed
   (no `enthalpy`). There is also **`cantera` + NON-dispersed**: the `cantera` branch
   (`properties.py:28-59`) never assigns `conductivity` or `energy`, but the non-dispersed writer
   (`io.py:48-58`) indexes both. Full matrix:

   | | dispersed (needs `enthalpy`) | non-dispersed (needs `conductivity`,`energy`) |
   |---|---|---|
   | `cantera` | OK (absolute `h`) | **KeyError** |
   | `fixed` | writes `cp·T` | OK |
   | `SP-database` | **KeyError** | OK |

2. **IGLOO's reader takes a hardcoded variable count**:
   `tec_read_points_multivars(orion, 3, 'INPUT/'//trim(prefix)//'properties.dat')`
   (`IGLOO/src/lib/IO.f90:93`) — the `3` is Cp, Density, Enthalpy. This constrains the doc's
   "write a vapour-enthalpy column" idea: **adding a column requires changing that literal too.**
   It also means a datum tag is safer as a **column rename** (`Enthalpy` → `Enthalpy_abs`) than as an
   extra header line, since the reader goes by position, not name — verify ORION's point reader
   tolerates whatever you choose.
3. **Nothing records which datum a file carries.** `io.py:33-36` writes a bare
   `VARIABLES = "Temperature", "Cp", "Density", "Enthalpy"` — no units, no tag. Whatever else you do,
   **tag it**, so a consumer can assert instead of assume. This is arguably the root defect.
4. **Branch selector, stated plainly:** `cp` present in the INI ⇒ `fixed`; `cp` absent and
   `thermo != SP-database` ⇒ `cantera`; `thermo = SP-database` ⇒ `SP-database`
   (`builder.py:70,83,99`). INI surface is `[GPB-Condensed]` keys `thermo, material, groups, cp, k,
   rho` (`input_registry.py:261-266`).

---

## 5. Suggested order of work

1. **Fix the two `KeyError` holes.** Unambiguous bugs, no design question, independent of the datum.
2. **Tag the datum in the file** (§4.3) — cheap, and it is what makes every later step checkable.
3. **Make the `fixed` branch able to emit absolute enthalpy.** Recommended: keep `cp·T` as the
   default so no existing case changes silently, and add an **optional** `[GPB-Condensed]` key
   (e.g. `h0`/`hf`, formation enthalpy) so the column becomes `cp·T + h0` only when asked.
4. **Land the IGLOO half in the same change** (§3), or step 3 is inert.
5. **Regenerate the IGLOO evaporation oracles** — expected and unavoidable under B.
6. **Commit a reference `properties.dat` for `test/GPB/CP-Tvar-dispersed/`** and assert on enthalpy.
7. **Verify with `test/evap-box-ta`**: `dhDatum → 0`, gas ΔT unchanged (§2).

---

## 6. Traps

- **Do not add a separate `+ ṁ·Lv` anywhere.** `sourceEn` already credits evaporated mass at
  `h_liq + Lv` (`Lib_RHS.f90:565`, `F(7) = (Qdot + mdot·Lv·cpFactor)/m`). The coupler *subtracts* `Lv`
  for that reason. Adding it double-counts by 2.44e6 J/kg. The observation doc's §4 "trap" says the
  same thing — heed it.
- **A constant table cannot test this.** Every shipped table has constant Cp *and* `Enthalpy == Cp·T`,
  so plausible errors are numerically invisible on them. An identical trap in ICE cost real time this
  week: a hardcoded-path bug was masked because the only test table was constant *and equal to* the
  scalar it fell back to. Any new test must use values that vary and that differ from the fallbacks.
- **`Lv = const` is separately inconsistent** with any absolute pair of curves (0.29 % on
  `evap-box-ta` — 5.0e4 J/kg against the 1.71e7 J/kg datum error, ~350× smaller). Fix the datum
  first; do not bundle.
- **IGLOO cannot read FLINT** — it links `FiNeR::FiNeR OSLO ORION` only
  (`IGLOO/src/lib/CMakeLists.txt:3`). Any gas-side enthalpy must arrive through ATLAS.
- **The `cantera` branch takes only the first species** (`properties.py:31`, `n = 0`). Fine for a
  single-substance material; unverified whether anything depends on more.
- **Column order is load-bearing** — IGLOO indexes `vars(1)=Cp, vars(2)=Density, vars(3)=Enthalpy`,
  with Temperature consumed as the mesh coordinate. Rows must stay on **integer** kelvin
  (`Tmin = nint(mesh(1,1,1,1))`, lookups use `nint(T)`).

---

## 7. Repo state, 2026-09-09

- **ATLAS** — `main` @ `59081ae` ("update docs"). **Dirty, not from this work:**
  `src/BCB/types_block.f90`, `src/ICB/io_fields.f90`. Untracked: `build-fix/`, `observations/`,
  `CLAUDE.md`, `database/chemistry/Singh.yaml`, and this file. Inspect before branching.
- **IGLOO** — `src/lib/IGLOO`, plain checkout (not a submodule), at `a66e02f`.
- **ICE** — `src/lib/ICE` (`open-hydra/ICE`), on branch `fix/io-prefix-and-atlas-bc-schema`,
  3 commits, not pushed.
- **hydra** — `main`, large uncommitted working tree; `src/app/MI2/` and `plan-bucket/` are untracked
  and exist only there. Background sessions run in `.claude/worktrees/`.
- ATLAS has its **own** auto-memory directory (keyed on the ATLAS path, separate from hydra's) —
  check it for CI status and pending decisions before starting.

## 8. First commands

```bash
cd /data10/passarani/Desktop/Software/hydra/utils/ATLAS
cat dev-notes/condensed-enthalpy-datum.md          # the analysis — read before anything else
git status -sb && git log --oneline -3
sed -n '11,76p' src/GPB/condensed/properties.py       # the three branches
sed -n '24,58p' src/GPB/condensed/io.py               # the two output layouts + the KeyError matrix
sed -n '26,105p' src/GPB/condensed/builder.py         # branch selection
grep -n 'GPB-Condensed' src/GPB/input_registry.py     # INI surface

# the IGLOO half — why an ATLAS-only fix is inert
sed -n '93,130p' ../../src/lib/IGLOO/src/lib/IO.f90
sed -n '178,190p' ../../src/lib/IGLOO/src/lib/obj_particles.f90

# see the wrong datum directly: row 1 is "1.0 4184.000000 997.000000 4184.000000" -> h == cp*T
head -6 ../../test/evap-box-ta/INPUT/part-properties.dat
```
