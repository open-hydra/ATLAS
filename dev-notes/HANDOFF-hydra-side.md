# HANDOFF — hydra-side steps of the dispersed-phase handoff plan

**For:** a Claude session working in the hydra tree (`/data10/passarani/Desktop/Software/hydra`), not in `utils/ATLAS`.
**Written:** 2026-09-17, by the ATLAS job that produced branch `feat/dispersed-phase-handoff` (`open-hydra/ATLAS`).
**Source plan:** `utils/ATLAS/plan-bucket/dispersed-phase-handoff-plan.md` — items P3.3, P3.4, P3.5, P8 steps 4/5/7, P6
acceptance, P9 hydra half, §10. Every file:line below was re-verified on 2026-09-17 against the trees named in §0.

## 0. State anchors and the contract the ATLAS branch now honours

- hydra `main`, large uncommitted working tree; `src/app/MI2/`, `test/mi2-checks/`, `plan-bucket/` untracked. Gitlink
  `utils/ATLAS` = fb3d69d at the time of writing (item 6 bumps it). `$MAIN` = `hydra/utils/ATLAS` is still at fb3d69d
  with two dirty files: this job could not touch the shared checkout (worktree sandbox). Do first:
  `cd utils/ATLAS && git stash push -m atlas-p0-dirty -- src/BCB/types_block.f90 src/ICB/io_fields.f90 && git pull --ff-only origin main`.
- IGLOO `src/lib/IGLOO` is a **plain checkout** of its own repo (branch `work-in-progress`, HEAD `92f7c4f`, 12 dirty files =
  the P3.3 surface; the plan audit was taken one commit earlier at `b6ce417` — every anchor below holds at `92f7c4f`).
  `figaro submodule update` never touches it. IGLOO links `FiNeR OSLO ORION` only — it cannot read FLINT.
- **ATLAS `main` was broken at 0015e33** ("new ORION commit", ORION c9fe983 → 34f4397 "improve tecplot ASCII reader"):
  every mesh-reading ATLAS case SIGSEGV'd after "Reading mesh file ... Done!" (22/30 red, reproduced locally, CI red).
  Fixed upstream the same day: ORION e13eedb/92665c9/1d78e9c ("improve Tecplot ASCII reader", "add error diagnostic",
  "Normalize line endings") and ATLAS 7b14e60 (`read_mesh.f90` now `stop 1`s on a reader error); CI green again from
  7b14e60 on. The feat branch was rebased onto 72c7d70 (ORION 1d78e9c) and its full ctest re-run from a clean build.
  Bump hydra's ATLAS gitlink to the merged SHA, never to 0015e33 itself.
- **What ATLAS writes now.** `<name>phase.txt`: line 1 = type word (`condensed-dispersed` | `liquid-dispersed` |
  `solid-dispersed` | `solid-bulk`) optionally followed by ` modeling=lagrangian|eulerian`; then one `<name> <groups>`
  line per material, followed by zero or more `key=value` tokens (item 3 landed on the branch: GPB writes them, reals
  as `{v:.10g}`; test `CP-fixmat-tokens`). `<name>properties.dat`: 4 columns in the same ORDER, column 4 named
  `Enthalpy` (relative: `cp·T`, or the SP-database integral) or `Enthalpy_abs` (absolute: NASA/Burcat tables, or fixed
  `cp` with the new `[GPB-Phase*] h0`). `<name>-bc.txt`: per-phase ids/payloads (P4), exact phase-name matching (P5),
  `<phase>-type = outlet` on a `type = axisymmetric` face (P6).
- **Inline `;` comments.** GPB's loader now strips an inline `;` comment from `type` and `modeling` values
  (`src/GPB/ini/common.py`), so `modeling = lagrangian ; ...` in `test/evap-box-ta/input.ini:106` and
  `test/JPL-3solver-20micron/input.ini:94` is accepted. Other keys still keep the tail — keep comments on their own line.

## 1. P3.3 — IGLOO reads the per-material keys from the phase file (delete `[IGLOO-Material<i>]`)

Anchors (`src/lib/IGLOO/src/lib/`):
- `IO.f90` `read_cdp_properties` :14-213; decl :31 `character(len=30) :: wholestring, args(2)`; parse :53-55
  (`call parse(wholestring,' ',args)` / `read(args(1),*) material(i)%matName` / `read(args(2),*) material(i)%ngroups`);
  the `read_phase_models` import at :22 and its call inside the material loop (grep it).
- `Lib_INI.f90` `read_phase_models` :333-404 = 20 sequential `fini%get`: six words :347-359 through
  `assign_evaporation/assign_liquid/assign_interface/assign_boiling/assign_combustion/assign_solidification`
  (module `IGLOO_Lib_Evaporation`), the combustion-vs-evaporation exclusivity :362-368, fourteen reals with their
  defaults :370-397 (`alpha-e` 1, `n-burn` 1.8, `X-eff` 1, `T-ign` 2350, `T-melt` 2327, `T-nuc` 0.8·T-melt, others 0),
  summary line :400-402. `warn_igloo_keys_in_preprocessor_sections` :410-435 with `keys(20)` :412, called at :344.
- `config/Register_IGLOO.f90` :165-205 = the `[IGLOO-MaterialX]` registry block; `docs/user/registry.md` is generated
  from it by `bin/DocGen` (source `src/app/docgen.f90`; rebuild IGLOO first). The `[IGLOO-Models]` descriptions that say
  "per-material override in [IGLOO-MaterialX]" (registry.md:31,32,34) are strings in the same file — reword them.
Steps:
1. Net-new `apply_material_key(mat, key, value)` in `Lib_INI.f90` (there is no `select case` today): `select case (key)`
   — the six words call the `assign_*` routines above; the fourteen reals do `read(value,*,iostat=ios) mat%<field>`
   and `error stop` on `ios/=0`; `case default` → `error stop` naming the key and the material. Keep the defaults (set
   them on `mat` BEFORE the token scan, they were only ever set in `read_phase_models`), keep the exclusivity check and
   the `>> [material i] evap=` summary line, run both after the scan.
2. `IO.f90`: decl → `character(len=512) :: wholestring, tok`; replace :53-55 by
   `read(wholestring,*,iostat=ios) material(i)%matName, material(i)%ngroups` (+ `error stop` on `ios/=0`), then split
   the rest of the line on blanks, skip the first two tokens, and for each `key=value` call `apply_material_key`.
3. Delete `read_phase_models`, `warn_igloo_keys_in_preprocessor_sections`, the registry block; run `DocGen`. IGLOO then
   opens NO `[GPB-*]` or `[IGLOO-Material*]` section.
4. Docs purge: `docs/user/input.md:37,45`; `docs/theory/evaporation.md:190,229`; `docs/theory/combustion.md:4,102`;
   `tests/combustion/INFO.md:5`; hydra `CLAUDE.md` paragraph "Solvers read only their own INI sections" → the keys
   live in `[GPB-Phase*]` and reach IGLOO as tokens on the material line of the phase file.
5. The nine INIs carrying `[IGLOO-Material1]`: IGLOO `tests/evaporation/{tc-box,tc-hexadecane,mhb98-water,lk-neq}`,
   `tests/combustion/burn-box`; hydra `test/{evap-box,evap-box-ord2,evap-box-ta,evap-probe}`. Eight carry only
   `alpha-e = 1.0`; `burn-box` carries `combustion = Beckstead`, `K-burn = 4.5e-7`, `n-burn = 1.8`, `X-eff = 0.5`,
   `T-ign = 550.0`, `beta-part = 0.3`, `q-comb = 1.0e6`. **`test/mi2-checks/migrate_igloo_material_keys.py` moves keys in
   the OPPOSITE direction** (`[GPB-Phase*]` → `[IGLOO-Material1]`, the transitional migration) — do the reverse by hand:
   move the keys into the condensed `[GPB-Phase*]` section, delete the block. Then the tokens: IGLOO tests have no
   ATLAS INI → hand-write `INPUT/phase.txt` line 2 as `<name> <groups> alpha-e=1` (burn-box:
   `<name> <groups> combustion=Beckstead K-burn=4.5e-07 n-burn=1.8 X-eff=0.5 T-ign=550 beta-part=0.3 q-comb=1000000`);
   hydra cases are regenerated by `ATLAS GPB` after item 3 (GPB prints reals with `{v:.10g}`).
Gates: IGLOO `tests/test.sh standard`, `tests/test.sh evaporation`, `tests/test.sh combustion` (13/12/2 passing today,
same counts after); hydra `test/mi2-checks/p3_material_section_check.sh` rewritten: "inert" = shipped `evap-box-ta`
OUTPUT byte-identical; "live" = edit the token to `alpha-e=0.5` in `INPUT/part-phase.txt` → `gas-field.tec` changes;
drop the "warned"/"gasmix" scenarios (no warning exists any more) and assert the log never mentions `IGLOO-Material`.

## 2. P3.4 — the other readers tolerate tokens and the new type words

- ICE `src/lib/ICE/src/lib/io/IO_BC.f90:102` `character(len=256)  :: line` → `len=512` (`Check_Phase_Groups` is
  list-directed, so tokens are ignored once the buffer is long enough).
- MI2 `src/app/MI2/MI2_Mod_Import.f90:341` `if (index(low, 'condensed-dispersed') > 0) then` →
  `if (index(low, 'dispersed') > 0) then` (it already precedes the `solid` test at :345, so `solid-dispersed` and
  `liquid-dispersed` route to the condensed solvers); in the :345 branch refuse `solid-bulk` explicitly (MI2 has no solid
  solver) with a message naming the file.
- MF `src/app/MF/MF_Mod_Import.f90:36` `if (index(type,'solid')>0) then` → `if (index(type,'solid-bulk')>0) then`
  (a `solid-dispersed` phase must never be handed to FUSS).
Gates: `test/mi2-checks/p1_routing_checks.sh <scratch-root>` (evap-box-ta permutations); a hand-made
`solid-dispersed modeling=lagrangian` header routes to IGLOO; a `solid-bulk` file is refused by MI2 with exit ≠ 0.

## 3. P3.5 — wire the token writer and regenerate

- **DONE on the branch (2026-09-24):** the `material_tokens = None` line is gone from `src/GPB/condensed/builder.py`, so
  `CP_IO.write_basics(..., material_tokens=material_tokens)` emits the tokens; test `CP-fixmat-tokens` gates it. The
  T-varying (cantera) branch now sorts `materials` into INI order, so `groups[i]`, `rho[i]` and the tokens land on the
  right material (before, two materials listed against database order swapped their densities, and would have swapped
  their tokens). Remaining ATLAS action: bump the gitlink (item 6).
- Token format: `key=value`, words verbatim, reals `{v:.10g}` (`4.5e-07`, `550`, `1000000`, `1`).
- Regenerate: ATLAS `test/GPB/*dispersed*/reference/*phase.txt` (no INI carries a key today → byte-identical, run anyway);
  hydra `test/{evap-box,evap-box-ord2,evap-box-ta,evap-probe}` (`part-phase.txt` line 2 gains ` alpha-e=1`),
  `test/JPL-{Lagrangian,Eulerian}-20micron`, `test/JPL-3solver-20micron` (line-1 token only).
Gates: `p1_routing_checks.sh`, `p3_material_section_check.sh`, `p1_two_phase_smoke.sh`; `evap-box-ta` closed-domain mass
gate `6.115E-16` byte-identical (`alpha-e=1` is the default, so the run must not change); `alpha-e=0.5` on the material
line changes the gas field.

## 4. P8 steps 4/5/7 — IGLOO consumes the absolute table; oracles; evap-box-ta

Why an ATLAS-only change is inert: `IO.f90:131` sets `cpVariable` only when the Cp column varies, `:142-145` allocate
`hTab` only then, and `obj_particles.f90:181-182` (`computeSource`) does `enthalpy = self%stateVar(7);
if (.not.self%varCp) enthalpy = self%cp*enthalpy` — a constant-cp material never opens the enthalpy column, and every
shipped hydra table is constant-cp with `Enthalpy == Cp·T` (relative).
- Allocate `hTab` unconditionally (the reader count is 3, the column always exists), keep `cpVariable` as the STATE
  choice (T vs h in `stateVar(7)`: `obj_particles.f90:297,308`, `Lib_Integration.f90:163,671,742`, `Lib_RHS.f90:436,525,
  606,690,794`, `obj_block.f90:344`, `obj_IGLOO.f90:664,754` stay as they are).
- Give the ENERGY SOURCE the table datum: for a constant-cp material `h_abs(T) = cp·T + hOff` exactly with
  `hOff = hTab(Tmin) − cp·Tmin` (0 for a relative table, the formation offset for an absolute one — no header parsing
  needed). Store `hOff` on the material (`obj_condensed.f90`, copied to the group next to `gr%cp` at :170 and to the
  particle in `assign_group2particle` :298-371), use it in `computeSource` (:182 → `enthalpy = self%cp*enthalpy +
  self%hOff`) and on the Eulerian path (`Lib_Integration.f90:866`). Read line 2 of `properties.dat` and print which
  datum was found; with `Enthalpy` assert `|hOff| < 1e-6·cp·Tmin` (else `error stop`: relative header but `hTab ≠ cp·T`).
- MI2 `src/app/MI2/hydra_MI2.f90:168-174`: `hIGLOOref` = `hTab` interpolated at `T_datum_ref` when `cpVariable`, else
  `cp·T_ref` → test `allocated(hTab)` instead of `cpVariable` (hTab is now always there): `hIGLOOref` becomes absolute
  exactly when the table is, and `dhDatum` self-cancels; a relative table keeps today's correction. Never add `+ṁ·Lv`
  (`Lib_RHS.f90` already credits `h_liq + Lv`; the coupler subtracts `Lv` for that reason).
- Route B is activated per case by the TABLE: hydra water cases keep `cp = 4184` → add `h0 = -15865000` to their
  `[GPB-Phase2]`, regenerate `part-properties.dat` (header `Enthalpy_abs`, row 298: `-15865627.6`). Without `h0`
  nothing changes and MI2 keeps correcting −1.7133453e7 J/kg.
- Oracles: IGLOO `tests/evaporation/*/{check,verify}.py` are literature oracles on particle trajectories (diameter,
  temperature) — they must NOT move; any expected value that shifts by exactly `ṁ·hOff` is an energy-source datum
  consequence (document it, update it); a trajectory change is a bug. hydra `test/evap-box-ta` references: mass gate
  `6.115E-16` byte-identical, energy line changes.
Acceptance (`test/evap-box-ta`, `figaro hydra-MI2 solve`): the startup block `[MI2] enthalpy-datum reconciliation` prints
`=> datum offset applied by MI2` ≈ 0 for the water material (|offset| ≲ 5e4 J/kg, the `Lv = const` inconsistency, versus
−1.7133453e7 today) and the gas ΔT stays **−0.686 K** (+2.874 K means the correction is missing: that sign flip is the
discriminator).

## 5. P6 acceptance on a TecIO host (JPL nozzle)

- `test/JPL-Lagrangian-20micron/INPUT/part-bc.txt` (shipped: face 3 = 400 axis outflow, face 4 = 301 trap wall; variants
  `.alt-axis200-wall301`, `.orig-axis200-wall300` sit next to it): put the P6 syntax in the INI (`face3 = ax`,
  `[ax] type = axisymmetric`, `part-type = outlet`, `[noz] type = wall`), run `ATLAS BCB`, `diff` against the shipped
  file. Face 3 must now match; if face 4 (301) still differs, BCB has no per-phase wall variant — record it, keep the
  hand-patched record.
- `test/JPL-3solver-20micron/INPUT/{partE,partL}-{phase.txt,properties.dat,bc.txt}` + `partE-ic.tec` from its INI: two
  `[GPB-Phase*]` with `name`/`modeling` (`partE` eulerian, `partL` lagrangian), the two unprefixed `krho = 0.17647`
  (:110, :132) become `partE-krho = 0.17647` and `partL-krho = 0.17647` in `[inj]` (P4/P5: with two phases the keys
  must be prefixed), `face3 = ax` + `[ax] type = axisymmetric` + `partL-type = outlet` (partE keeps 200),
  `[noz] type = wall`; run `ATLAS GPB BCB ICB`; `diff` vs shipped (`partE-bc.txt` f3=200/f4=300, `partL-bc.txt`
  f3=400/f4=301). Then `test/mi2-checks/p1_two_phase_smoke.sh`.

## 6. P9 hydra half

- Bump the gitlink: `cd utils/ATLAS && git fetch && git checkout <merged sha>` then `git -C hydra add utils/ATLAS`
  (commit with the user's other work; never `git add -A`). Any SHA from 7b14e60 on is fine; 0015e33 alone is broken (see §0).
- `rm -rf utils/ATLAS/build-fix` (28 MB stale build tree, untracked). Decide `utils/ATLAS/database/chemistry/Singh.yaml`
  (commit to ATLAS or delete). After the stash in §0: `git -C utils/ATLAS stash list` → `atlas-p0-dirty` holds the
  pre-plan dirty files (`types_block.f90` OMP comment-out, `io_fields.f90` CD→DP which landed as P2 commit 117d8cc)
  → `git -C utils/ATLAS stash drop` once reviewed.
- Rebuild `utils/ATLAS/bin`: `cd utils/ATLAS && cmake --build build` (SERIAL — never `-j`, shared `build/modules`).
- IGLOO's FiNeR: `src/lib/IGLOO/lib/third_party/FiNeR` @ `aab8f72` is older than hydra's `18fa207`; a comment line
  containing `=` kills standalone IGLOO. `cd src/lib/IGLOO/lib/third_party/FiNeR && git fetch && git checkout 18fa207`,
  `git -C src/lib/IGLOO add lib/third_party/FiNeR`, rebuild, `tests/test.sh standard`.

## 7. OpenMP

The ATLAS branch was built and tested with gfortran, `USE_OPENMP=false` (CI parity). BCB under OpenMP is untested on it;
the `types_block.f90` OMP comment-out the user had in the working tree is preserved in stash `atlas-p0-dirty` (after §0).
Before an `intel --use-openmp` `figaro build ATLAS`, run `ctest -L BCB` from an OpenMP build; on a crash, the stash shows where.
