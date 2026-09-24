# Observation — dispersed-phase enthalpy datum in `GPB/condensed`

**Date:** 2026-08-30. **Updated 2026-09-09** — see the decision banner below.
**Files:** `src/GPB/condensed/properties.py`, `src/GPB/condensed/io.py`
**Found while:** planning the hydra MI2 coupler (MOSE + ICE + IGLOO), which adds **two-way mass coupling**
between the Lagrangian particles and the gas.

> ## ⚠ DECISION, 2026-09-09 — the route has been chosen, and it is **B**
>
> This note originally recommended **route A** (leave ATLAS alone, correct in the coupler). Route A was
> then implemented, measured and shipped in hydra-MI2 — and the **user has since rejected it**. The datum
> is to be fixed **at generation time, here in ATLAS**: route B.
>
> **§5's recommendation is superseded.** Its arguments were not wrong and are retained below, but they
> are now the *cost sheet* for B, not reasons to prefer A:
> - every IGLOO evaporation oracle shifts by `ṁ·Δh` and must be regenerated — **budget for it**;
> - B is inert without a matching IGLOO change — **§6 is now required reading, not a contingency**.
>
> **Companion document:** `../HANDOFF-condensed-enthalpy-datum.md` — the actionable handoff for a session
> doing the work (decision context, acceptance test, repo state, first commands). **This file remains the
> analysis of record**; the handoff deliberately does not repeat it.

**Status: not a bug in isolation.** The current convention is correct and sufficient for every use ATLAS has
had until now. It becomes insufficient the moment evaporated mass is booked into a gas solver's species and
energy equations. Read the whole note before changing anything — under route B the fix has a real blast
radius (§5, §6), and the *naive* version of it is a silent no-op (§6).

---

## 1. What ATLAS writes today

`compute_properties()` builds the Enthalpy column three different ways depending on material `type`:

| `type` | line | enthalpy | datum |
|---|---|---|---|
| `cantera` | `properties.py:56` | `h = solution.h` | **formation-inclusive** (Cantera/NASA: `h(298.15 K) = Δh_f°`) |
| `fixed` | `properties.py:66` | `enthalpy = cp * temperatures` | **sensible from 0 K** |
| `SP-database` | `properties.py:74` | **never assigned** | — |

The column reaches disk through `io.py::write_properties`, in the 4-column *dispersed* layout
`"Temperature", "Cp", "Density", "Enthalpy"`.

### 1.1 Three real defects, independent of any coupler

1. **`SP-database` + dispersed ⇒ `KeyError`.** `compute_properties_from_database()` returns only
   `mass_cp, density, conductivity, energy`. `enthalpy[mat.name]` is never set, but the dispersed branch of
   `write_properties` unconditionally reads `enthalpy[species_name][i]`. Any `SP-database` material declared
   as a dispersed phase crashes the writer. (The non-dispersed branch writes `Conductivity, Energy` instead
   and is unaffected — which is why this has not been hit.)

2. **`cantera` + NON-dispersed ⇒ `KeyError`** *(added 2026-09-09; the exact mirror of defect 1).* The
   `cantera` branch (`properties.py:28-59`) assigns only `mass_cp, enthalpy, density` — never
   `conductivity` or `energy` — but the **non-dispersed** writer (`io.py:48-58`) indexes
   `conductivity[species_name][i]` and `energy[species_name][i]`. The two holes are symmetric, and between
   them the branch × layout matrix has two crashing cells:

   | | dispersed (needs `enthalpy`) | non-dispersed (needs `conductivity`, `energy`) |
   |---|---|---|
   | `cantera` | OK — absolute `h` | **KeyError** |
   | `fixed` | writes `cp·T` | OK |
   | `SP-database` | **KeyError** | OK |

   Neither has been hit because the two working diagonals happen to be the combinations in use.

3. **The datum is inconsistent *within ATLAS*.** `cantera` materials get formation-inclusive enthalpy;
   `fixed` materials get sensible enthalpy. A case declaring one of each writes **one file whose two zones
   are on two different scales**. Nothing downstream can detect this.

Worth noting: the `cantera` branch is the *same line* as the ideal-gas generator
(`src/GPB/ideal_gas/thermo.py:56`, also `h = solution.h`), which is what produces the gas `thermo.dat` that
FLINT loads. So `cantera`-typed condensed materials are already on FLINT's datum; only `fixed` is not.

---

## 2. Why `cp·T` has always been fine (and why IGLOO's fallback is correct)

IGLOO uses the enthalpy state `Z(7)` in exactly two ways, and **neither depends on its absolute level**:

- `tp = comp_TfromTab(hTabM, Z(7))` — a table inversion h→T (`Lib_RHS.f90:441,530,611,695,799`). A constant
  offset in the table cancels on inversion.
- `F(7) = (Qdot + mdot*Lv*cpFactor)/m` (`Lib_RHS.f90:565`) — a *rate*, `dh/dt`. A constant offset has zero
  derivative.

So IGLOO's fallback to `cp·T` when cp is constant is **not a shortcut or an oversight** — it is valid
precisely because only the *variation* of h enters the particle physics. Adding an absolute datum to the
table would change nothing about a droplet's trajectory, temperature, or evaporation rate.

## 3. Where the level does leak — and only there

The single place the absolute level escapes IGLOO is `computeSource` (`obj_particles.f90:178-195`), which
exports a flux to whoever is coupling:

```
E = ṁ · ( h + ½|v|² )
```

and the coupler consumes `sourceEn = E_in − E_out` per cell. Substitute `h → h + c` for a constant datum
offset `c`:

```
(E_in − E_out)  →  (E_in − E_out) + c·( ṁ_in − ṁ_out )
```

**The offset cancels identically whenever `ṁ_in = ṁ_out`** — i.e. for every non-evaporating,
non-burning particle. That is why the datum has never mattered: without phase change, `sourceEn` only ever
contains *differences of h at fixed mass flow*.

With evaporation, `ṁ_in ≠ ṁ_out`, and the residual error is exactly

```
c · (evaporated mass rate)
```

For water with today's `fixed` convention, `c` is the gap between `cp_liq·T` and the absolute scale — of
order **1.7 × 10⁷ J per kg evaporated**. The run completes and the fields look plausible; the energy balance
is silently wrong.

---

## 4. The two ways to fix it — same formula, different table

First, an audit result that fixes the size of the problem (derivation in §4.1): **IGLOO's `sourceEn` is a
correct total-energy source, and it already credits the evaporated mass at the *vapour* enthalpy
`h_table + Lv`.** So the coupler does **not** owe a latent-heat term — it owes only the offset of the
**liquid** enthalpy table:

```
correction  =  ṁ_evap · [ h_abs,liquid(T_p)  −  h_table,liquid(T_p) ]
```

Routes A and B differ **only** in what `h_table,liquid` is:

| | condensed table holds | correction reduces to | touches |
|---|---|---|---|
| A — leave ATLAS as is *(implemented, now superseded)* | `cp_liq·T_p` (sensible) | `ṁ·[ h_abs,liq(T_p) − cp_liq·T_p ]`, and since FLINT tabulates only gas species, `h_abs,liq = h_FLINT,vap − Lv` | coupler only |
| **B — ATLAS emits absolute `h` ← CHOSEN 2026-09-09** | `h_abs,liq(T_p)` | **zero** — nothing left to correct | ATLAS + IGLOO + coupler |

### Worked numbers, water at 298.15 K

| quantity | value (J/kg) |
|---|---|
| `cp_liq·T` = 4184 × 298.15 — what ATLAS writes today | `+1.2475e6` |
| `h_abs,vapour` (= Δh_f° of H₂O gas; matches FLINT's `thermo.dat`) | `−1.34238e7` |
| `L_v(298.15)` | `+2.442e6` |
| `h_abs,liquid` = `h_abs,vap − L_v` — what ATLAS would write under B | `−1.58658e7` |
| **Route A correction** = `−1.58658e7 − 1.2475e6` | **`−1.71133e7`** |
| **Route B correction** | **`0`** |

**Confirmed against a real run (2026-09-09).** Route A was implemented and its startup diagnostic printed,
on `<hydra>/test/evap-box-ta` (water, `cp = 4184`, `Lv` from that case's INI):

| quantity | measured (J/kg) |
|---|---|
| `h_FLINT(H2O, 298.15)` | `−1.3423515e7` |
| `h_IGLOO = cp·T_ref` = 4184 × 298.15 | `+1.2474596e6` |
| `Lv` (case INI, not the 298.15 K physical value) | `+2.4624780e6` |
| **offset applied** | **`−1.7133453e7`** |

The estimate above (`−1.71133e7`) and the measurement (`−1.7133453e7`) differ by 0.12 % purely because the
table uses `Lv = 2.442e6` at 298.15 K while the case declares `2.4624780e6`. Both are right for their own
`Lv`; the discrepancy is the `Lv = const` issue of §4.1, not an error in either number.

### The trap

An extra `+ṁ·Lv` is **wrong under both routes** — `sourceEn` already contains the latent heat. Under A, the
`−Lv` inside `h_abs,liq = h_FLINT,vap − Lv` is only converting FLINT's *vapour* enthalpy into the *liquid*
enthalpy the table is meant to hold; it is not a latent-heat term being added. Pick one route and state it in
a comment at the injection site.

### 4.1 Audit — why `sourceEn` is already right

With `h` the liquid enthalpy, `e ≡ h + ½|v|²`, `ṁ_d = dm/dt < 0`, and from `rhsEvaporation`
(`Lib_RHS.f90:551-566`) `m·dh/dt = Q_conv + ṁ_d·Lv`, `m·dv/dt = F_drag + m·g`:

```
d(m·e)/dt = Q_conv + v·F_drag + m·(g·v) + ṁ_d·( Lv + e )
```

Multiplying by `npdot`, integrating across a cell, `Δṁ = −npdot·ṁ_d > 0`:

```
E_in − E_out = Δṁ·( e + Lv ) − Q_conv − W_drag − W_gravity
```

`srcBodyForce` adds `W_gravity` back into `E_in`, correctly removing it (gravity's work comes from the
potential field, not the gas). What remains, `Δṁ·(e + Lv) − Q_conv − W_drag`, is exactly what the gas should
gain: the vapour arriving at `h_vap + ½|v|² = e + Lv`, minus the heat the gas gave the droplet, minus the drag
work it did on it. Note `Q_conv` from `interphase` is **convective only** — no drag-work term in the droplet
enthalpy equation, which is what makes the accounting close.

**Second-order caveat.** IGLOO's `Lv` is a per-material **constant**, while the true
`h_abs,vap(T) − h_abs,liq(T)` varies with temperature (water: 2.442 MJ/kg at 298 K, 2.257 at 373 K, → 0 at the
critical point). A perfectly reconciled datum still leaves `ṁ·(Lv_true(T_p) − Lv_const)` — ~10⁵ J/kg against
the ~10⁷ J/kg datum error, so two orders smaller. It is a separate physics choice (temperature-dependent
`Lv`), not part of the datum fix.

---

## 5. Recommendation — SUPERSEDED 2026-09-09

> **The decision is route B.** What follows is the original case for A, kept because every point in it is
> still true and now constitutes the **cost sheet for B**. Read it as "what B will cost", not as advice.

~~**Prefer A — leave the ATLAS enthalpy convention alone; correct in the coupler.**~~ Reasons given at the
time:

- The `cp·T` convention is *intentional and correct* for a table whose only job is to supply enthalpy
  variation (§2). Forcing an absolute datum onto it imposes a requirement the table was never meant to carry.
  → **Still true.** It is now an accepted change of contract: the table must carry an absolute level because
  it feeds an absolute energy balance. Say so explicitly in the file (defect 3, §1.1).
- B changes `sourceEn` by `ṁ·Δh`, so **every IGLOO evaporation reference output shifts** and all oracles must
  be regenerated — real cost, no physics gain, since A and B are algebraically identical.
  → **Still true, and the single largest cost item. Plan the regeneration up front.**
- B additionally needs an IGLOO change to have any effect at all (§6), doubling the blast radius.
  → **Still true. §6 is mandatory, not optional** — the ATLAS-only change is a silent no-op.

The original escape clause read: *"adopt B only if `sourceEn` is wanted as a meaningful absolute energy flux
in its own right."* That is now effectively the situation — the coupler consumes it as exactly that, and the
user prefers the meaning to live in the data rather than in a correction term downstream.

### What route A left behind, and why it does not obstruct B

Route A is live in hydra-MI2 (`src/app/MI2/MI2_Stoichiometry.f90`, `dhDatum`/`Build_Datum_Offsets`). **It
does not need to be removed, and it will not double-correct.** `hIGLOOref` is read as whatever IGLOO itself
would use — the tabulated `hTab` value when the material is `cpVariable`, `cp·T_ref` otherwise. So once the
table is absolute *and IGLOO consumes it* (§6), `dhDatum → 0` on its own; any material still on constant `cp`
keeps its correct non-zero correction. Both regimes are already handled.

**Acceptance test, free and already instrumented:** run `<hydra>/test/evap-box-ta` and read the startup block
`[MI2] enthalpy-datum reconciliation`. Two things must hold when B is complete:

1. `=> datum offset applied by MI2` prints **≈ 0** for the migrated material — the coupler correction has
   self-cancelled because the table now carries the absolute level.
2. The mass-weighted gas **ΔT = −0.686 K**, i.e. unchanged from the route-A run. That is the *pass* value:
   the physics must not move, only the place the datum lives.

**+2.874 K is the failure signature**, not an alternative outcome — it is what the run produced with route A
disabled (`[MI2-Coupling] datum-correction = false`), i.e. the gas heating instead of cooling because the
formation enthalpy went missing. If B lands and you see ≈ +2.9 K, the absolute level is not reaching
`sourceEn` — almost certainly the §6 IGLOO half is missing or ineffective.

### On making `Lv` a variable property

Tempting, since the `psat` machinery in IGLOO looks like a template for it. Three reasons to derive rather
than tabulate:

1. **The `psat` template does not work.** `obj_material%psatVariable` / `%psatTab` / `propFlags(5)` exist and
   the RHS reads `lookupTab(psatTabM, tp)`, but the code that would populate them is commented out
   (IGLOO `src/lib/IO.f90:156-161`, annotated *"not wired yet"*), and this writer emits no `psat` column —
   the commented code reads `blk%vars(6,...)`, a 6-variable layout `write_properties` never produces.
2. **`Lv` and `psat` are coupled.** Clausius–Clapeyron derives `psat` from `Lv`
   (`Lib_Evaporation.f90:552`, via the *constant* `LvMvOverRu`). Tabulating `Lv(T)` alone puts the energy
   equation on `Lv(T)` and the mass equation on a constant `Lv` — inconsistent, and invisible to every
   existing test.
3. **Under route B it is redundant.** With absolute enthalpy on both sides,
   `Lv(T) ≡ h_abs,vap(T) − h_abs,liq(T)` is computed, not stored — T-dependence for free, CC satisfiable by
   construction, no second source of truth.

### The better move: write a VAPOUR enthalpy column, not an `Lv` column

`Lv` has exactly three consumers in IGLOO, and two of them are just `h_vap − h_liq` in disguise:

| site | use | with both curves |
|---|---|---|
| `Lib_RHS.f90:565`,`:746` | latent sink `ṁ_d·Lv` in the droplet energy equation | derived |
| `Lib_Evaporation.f90:324` | Spalding `B_T = cp_g(T_g−T_p)/Lv` | derived |
| `Lib_Evaporation.f90:552` | Clausius–Clapeyron `psat = P_atm·exp(−LvMvOverRu(1/T − 1/T_boil))` | ⚠ closed form assumes **constant** `Lv` |

So emitting a **vapour-enthalpy column** alongside the liquid one makes `L(T) = h_vap(T) − h_liq(T)` derived,
temperature-dependent for free, and — decisively — **on the same datum by construction**, since both come
from one Cantera call. That is the original defect solved at its root rather than patched.

It also matters that **IGLOO does not link FLINT** (`FiNeR::FiNeR OSLO ORION` only), so it cannot read the gas
enthalpy table itself. The vapour curve has to come through this file or not at all.

Three caveats:
- **IGLOO's reader takes a hardcoded variable count** *(added 2026-09-09)*:
  `tec_read_points_multivars(orion, 3, 'INPUT/'//trim(prefix)//'properties.dat')`
  (IGLOO `src/lib/IO.f90:93`) — the `3` is Cp, Density, Enthalpy. **Adding any column therefore requires an
  IGLOO-side change too**, on top of the parsing in `IO.f90:109-127`. This also affects defect 3's proposed
  `DATASETAUXDATA` tag: verify ORION's point reader skips unknown header lines, or prefer a column
  **rename** (`Enthalpy` → `Enthalpy_abs`), since the reader indexes by position and not by name.
- **Clausius–Clapeyron.** The integrated closed form is only valid for constant `Lv`; with `L(T)` the correct
  statement is `ln(psat/P_atm) = (Mv/Ru)∫L(T')/T'² dT'`. So add a `psat` column in the same change (Cantera
  returns it from the same saturation call) and retire the closed form where the column exists — otherwise the
  energy equation runs on `L(T)` while the mass equation runs on a constant `Lv`.
- **Not all materials can supply it.** The `cantera` branch pulls a single species
  (`mat.solution.species(n)`); a matched liquid+vapour pair wants a two-phase object (`ct.Water()`) or two
  explicit species. Easy for common fluids, awkward for arbitrary ones — so scalar `Lv` should remain the
  documented **fallback** when the vapour column is absent, not be deleted.

**Independent of the route, these are defects under any convention and should be fixed first:**

1. `SP-database` dispersed materials must populate `enthalpy` (currently a `KeyError`, §1.1 defect 1).
2. `cantera` non-dispersed materials must populate `conductivity` and `energy` (also a `KeyError`,
   §1.1 defect 2).
3. The datum must be **recorded in the file** written by `write_properties`, so a consumer can tell which
   convention a zone uses. A `DATASETAUXDATA`-style tag
   (`EnthalpyDatum = "sensible-0K" | "absolute-298.15K"`) would let a coupler assert rather than assume — and
   would make the mixed-material case detectable instead of silent. See the reader caveat above before
   choosing header-tag vs column-rename.

## 6. ⚠ MANDATORY under route B — the ATLAS-only fix is a silent no-op

*(Written as a contingency; since 2026-09-09 route B is the decision, so this section is required.)*

IGLOO decides `cpVariable` by testing whether the **Cp column varies** (`src/lib/IO.f90:110-127`). A `fixed`
material has constant cp by construction, so `cpVariable = .false.`, `hTab` is never allocated, and
`computeSource` uses `self%cp * stateVar(7)` — the Enthalpy column is **ignored entirely**. Fixing
`properties.py` alone therefore changes nothing for exactly the materials that have the problem.

B additionally requires IGLOO to allocate `hTab` whenever the column is present and use
`lookupTab(hTab, part%tp)` in `computeSource` regardless of `cpVariable`. (`stateVar(7)` *is* `tp` on that
branch, so the substitution is local.) Re-verified 2026-09-09 at IGLOO `src/lib/IO.f90:109-127` and
`src/lib/obj_particles.f90:181-182`. IGLOO is a **plain checkout, not a submodule** — `figaro submodule
update` will not touch it.

**How much of the corpus this covers** *(surveyed 2026-09-09)*: every dispersed case in hydra —
`evap-box`, `evap-box-ta`, `evap-box-ord2`, `evap-probe`, `JPL-Lagrangian-20micron`,
`JPL-Eulerian-20micron`, `JPL-nomollify` — declares `cp` under `[GPB-Phase2]`, so **all seven take the
`fixed` branch**, and all seven shipped tables satisfy `Enthalpy == Cp·T` exactly (checked numerically).
⇒ Without the IGLOO half, route B changes **nothing anywhere**. Conversely the already-correct `cantera`
path has **zero** regression coverage: ATLAS's own `test/GPB/CP-Tvar-dispersed/` (`material = AL2O3(L)`,
`thermo = Burcat`, no `cp`) commits no reference `properties.dat`, so nothing asserts on enthalpy at all.
Committing one is cheap and would be the first real guard on this behaviour.

---

## 7. Reproducing the finding

```bash
# Gas side — formation-inclusive. H2O @298 K should be ~ -1.34238e7 (= Δh_f°/M)
sed -n '35017,35020p;35315,35318p' \
  <hydra>/src/lib/MOSE/test/1D/Fer14/INPUT/thermo.dat

# Condensed side — h == cp*T exactly, in every shipped table
head -8 <hydra>/src/lib/IGLOO/tests/common/properties.dat
```

Cross-check: H₂O `Δh_f° = −241.83 kJ/mol ÷ 0.018015 kg/mol = −1.3424e7 J/kg`, matching the gas table exactly;
H₂ (a reference element, `Δh_f° = 0`) tabulates ≈ 0 at 298 K.

Quicker, on a case that ships with hydra — row 1 is `1.0 4184.000000 997.000000 4184.000000`, i.e.
`Enthalpy == Cp·T` exactly:

```bash
head -6 <hydra>/test/evap-box-ta/INPUT/part-properties.dat
```

And the IGLOO half of §6, in two reads:

```bash
sed -n '93,130p'  <hydra>/src/lib/IGLOO/src/lib/IO.f90           # cpVariable auto-detect; hTab only if true
sed -n '178,190p' <hydra>/src/lib/IGLOO/src/lib/obj_particles.f90 # h = cp*T when .not. varCp
```

---

**Related:**
- `../HANDOFF-condensed-enthalpy-datum.md` — actionable handoff for the session doing route B
  (decision context, acceptance test, suggested order, repo state, first commands).
- hydra `plan-bucket/MI2-coupler-plan.md` §6d/§6e.
- hydra `src/app/MI2/MI2_Stoichiometry.f90` — the route-A implementation and its derivation comment.
