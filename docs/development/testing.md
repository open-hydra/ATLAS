# Testing

This page describes the ATLAS tests in plain terms: what each test is trying to prove. The
[Tutorials](../tutorials/index.md) are built on some of these cases; this page lists them all.

## What A Test Checks

Most regression tests run one tool (`GPB`, `BCB`, `ICB`, `MDB`, or `STB`) from a case folder and then compare produced files with reference files.

If outputs match, the test objective is considered met.

## Registered Tests

Every test registered in `test/CMakeLists.txt` (205; `IG-ic-write-failure` only in a build with TecIO), by
tool. The tests labelled `tutorial` hold the [Tutorials](../tutorials/index.md): `ctest -L tutorial` runs them.

| Test name | Tool | Case folder | Main goal |
|---|---|---|---|
| `ceafile-reactive-OG` | GPB | `GPB/IG-ceafile-reactive-OG` | Reactive gas setup from CEA data produces the expected composition/chemistry output. |
| `database-flint-contract` | GPB | `tools` | Every `database/chemistry` yaml whose phase name selects a compiled FLINT routine matches that routine in the copy of FLINT's contract file (`test/tools/flint_mechanism_contract.json`); the hooked names are pinned. |
| `database-figure-current` | GPB | `tools` | The figure of the mechanism catalog (`docs/databases/chemistry/mechs.svg`) is what `database/chemistry/resume.py` gives for the mechanisms of the database now. After adding or changing a mechanism, run `python3 database/chemistry/resume.py` and commit the figure; a new file also needs a family in the script. |
| `IG-reactions-without-thermo` | GPB | `GPB/IG-reactions-without-thermo` | `reactions =` without `thermo`: the thermo records of the file are used, said with an INFO line; `thermo.dat`, `chemistry-info.txt` and `chemistry-Arrhenius.dat` equal those of `phase =` on the same file. |
| `IG-strict-thermo` | GPB | `GPB/IG-strict-thermo` | `strict-thermo = true` refuses a database thermo record that differs from the file record by more than 1 kJ/mol. |
| `IG-fixgas-gas-constant` | GPB | `GPB/IG-fixgas-gas-constant` | A species given by `gamma` and `mw`: `cp = gamma/(gamma-1) R_u/mw` with the exact `R_u`. |
| `IG-fixgas-mil-alone` | GPB | `GPB/IG-fixgas-mil-alone` | A fixed species given `mil` without `kl` or `Pr` stops GPB naming the key; no product is left. |
| `IG-transport-CEA-species-without-data` | GPB | `GPB/IG-transport-CEA-species-without-data` | `transport = CEA` with a mechanism species that has no transport data but is in the thermo database: accepted, `transport.dat` equal to the one with transport records. |
| `IG-transport-CEA-nasa-names` | GPB | `GPB/IG-transport-CEA-nasa-names` | `transport = CEA` with the names of `nasa9.yaml` (`species = Ar He N2`): every species takes its `CEApolynomials.yaml` record, with no WARNING; `transport.dat` equal from 200 K to the NASA CEA fits of `lib/cea/data/trans.inp` within the print precision, and below 200 K to the intervals that ATLAS adds and the rule below them. |
| `IG-transport-CEA-aliases` | GPB | `GPB/IG-transport-CEA-aliases` | `transport = CEA` with `AR` and `HE` of a Chemkin-style file, with the thermo of the file and with `thermo = Burcat`: the records `Ar` and `He` through their aliases, with no WARNING; the `AR` and `HE` columns equal the `Ar` and `He` columns of `IG-transport-CEA-nasa-names`. One reference per thermo database: below its lowest conductivity bound (373.2 K) the H2O conductivity keeps the Prandtl number of that bound with the specific heat of the run, which differs between the two databases; the other columns of the two runs are equal. |
| `IG-transport-CEA-exact-names` | GPB | `GPB/IG-transport-CEA-exact-names` | `transport = CEA` with `CO` and `Co` (cobalt) of a mechanism file: `CO` takes its record, `Co` the simplified law with its WARNING (names compared character by character). |
| `GPB-cea-transport-records` | GPB | `tools` | The index of the `CEApolynomials.yaml` records, without Cantera: a name finds its record by name or alias, character by character (`AR` finds `Ar`, `Co` finds no record); malformed records and a name or alias given twice are refused with their messages. |
| `database-cea-transport` | GPB | `tools` | `CEApolynomials.yaml` equal to `lib/cea/data/trans.inp` of NASA CEA (names, NASA intervals, also as counted by the code `V<n>C<n>` of the record `source`, coefficients), except the fits ATLAS defines itself: the records listed in `ATLAS_RECORDS` of `test/tools/cea_trans_inp_check.py`, where a new record absent from `trans.inp` is added, and the intervals with their own `source`, which come before the NASA intervals of their property, each ending where the next begins, the last at the lowest NASA bound; not run (exit 77) without the CEA submodule. |
| `GPB-cea-transport-low-temperature` | GPB | `tools` | Without Cantera: the intervals that ATLAS adds to `CEApolynomials.yaml` increase strictly, join their neighbours in value and slope within the rounding error and reproduce their references (Lemmon and Jacobsen 2004; Bich, Millat and Vogel 1990, data in `test/tools/bich1990_dilute_gas.csv`) within the bounds of the tool; every record gives positive increasing rows from 1 K (the viscosity of `RP-1` held at its 270 K value) with a constant Prandtl number below its lowest conductivity bound; the rule below and above the intervals, the records refused with their messages and the malformed records handled without a stop, on records built in the tool. |
| `IG-transport-CEA-air-low-temperature` | GPB | `GPB/IG-transport-CEA-air-low-temperature` | The air of the guide with `transport = CEA`: viscosity at 100 K and 37 K and conductivity at 100 K within the bounds of `check_air.py` from the dilute-gas air of Lemmon and Jacobsen (2004); no WARNING or INFO line of `transport = CEA`. |
| `IG-transport-CEA-falling-viscosity` | GPB | `GPB/IG-transport-CEA-falling-viscosity` | `transport = CEA` with `RP-1` of `CKJLR-10sp`: one INFO line says that the viscosity keeps its 270 K value below 270 K; with `Tmin = 300` no line. |
| `CP-tmin-noninteger` | GPB | `GPB/CP-tmin-noninteger` | A non-integer `Tmin` of a condensed phase is refused naming the key; an integer `Tmin = 300` is accepted; no product is left behind. |
| `GPB-tmin-range` | GPB | `GPB/GPB-tmin-range` | `Tmin` at or below 0 K, or above `Tmax`, stops GPB naming the key (ideal gas and condensed phase). |
| `IG-falloff-irreversible-orders` | GPB | `GPB/IG-falloff-irreversible-orders` | `k_c = 0` on the rows of an irreversible falloff reaction; the explicit orders written as the orders block of `chemistry-info.txt`. |
| `IG-orders-block-always` | GPB | `GPB/IG-falloff-irreversible-orders` | The orders block ends `chemistry-info.txt` whatever the phase name: a phase named `WD` keeps its explicit orders. |
| `GPB-falloff-form-refused` | GPB | `GPB/IG-falloff-irreversible-orders` | A falloff form other than Troe and Lindemann (here Tsang) stops GPB naming the reaction. |
| `IG-phase-file-name-hint` | GPB | `GPB/IG-phase-file-name-hint` | `phase =` naming a file that does not exist stops GPB with an error that suggests the file holding that phase. |
| `IG-ct-equilibrium` | GPB | `GPB/IG-ct-equilibrium` | The Cantera equilibrium of the tutorial builds the phase: species and composition files as in the reference. |
| `IG-ct-equilibrium-inerts` | GPB | `GPB/IG-ct-equilibrium-inerts` | Cantera equilibrium with `inerts-mixing = true` and `add-species`: the `cte-mixture` molecular weight of the kept species, each with its own mass fraction; N2 a separate species. |
| `GPB-launcher-atlasdir` | GPB | `GPB/IG-falloff-irreversible-orders` | `ATLAS.sh` derives `ATLASDIR` from its own location and passes it to GPB when the environment does not set it. |
| `CP-fixmat-dispersed` | GPB | `GPB/CP-fixmat-dispersed` | Fixed-property dispersed phase: phase-file header and modeling token. |
| `SP-fixmat` | GPB | `GPB/SP-fixmat` | Fixed-property solid phase with the `solid-bulk` header. |
| `CP-Tvar-dispersed` | GPB | `GPB/CP-Tvar-dispersed` | A Burcat or Cantera table gives the absolute enthalpy (header `Enthalpy_abs`). |
| `CP-fixmat-h0` | GPB | `GPB/CP-fixmat-h0` | Fixed `cp` plus `h0` gives `Enthalpy_abs` with h(298.15 K) = h0. |
| `CP-fixmat-tokens` | GPB | `GPB/CP-fixmat-tokens` | Per-material `key=value` tokens are written on the material line; the properties table does not change. |
| `IG-mixture-cantera` | GPB | `GPB/IG-mixture-cantera` | Frozen air mixture with Cantera transport: the mixture zone of `gas-transport.dat` holds air, not the last pure species. |
| `CP-Tvar-fallback` | GPB | `GPB/CP-Tvar-fallback` | A material missing from the database (`thermo = Burcat`) takes the `cp`, `rho`, `h0` of the INI, the others keep their tables, and `groups` reach the phase file in order. |
| `CP-Tvar-missing` | GPB | `GPB/CP-Tvar-missing` | A material the database lacks, given no constants, stops GPB. |
| `CP-Tvar-fallback-h0` | GPB | `GPB/CP-Tvar-fallback-h0` | A fallback material next to a database one without `h0` stops GPB: the phase would mix two enthalpy datums. |
| `CP-psat-water` | GPB | `GPB/CP-psat-water` | `psat-vapour = H2O` adds the columns `Psat`, `Lv`, `Mv`, `Cpv` from the liquid/vapour pair of `nasa9.yaml`: `Psat` held to the IAPWS saturation line at 300 and 350 K, `Lv` to the slope of `Psat` (Clausius–Clapeyron), `Mv` to the atomic weights, `Cpv` and `Lv` to NIST-JANAF; the phase file is that of `CP-fixmat-h0`. |
| `CP-psat-water-eulerian` | GPB | `GPB/CP-psat-water-eulerian` | The same with `modeling = eulerian`: the `Psat` column does not change. |
| `CP-psat-refuse` | GPB | `GPB/CP-psat-refuse` | `psat-vapour` naming a species of another composition (`O2` for water) stops GPB. |
| `IG-fixgas` | GPB | `GPB/IG-fixgas` | Two species given by `gamma`, `mw`, `mil` and `kl` ([Fixed-Gas Mixture](../tutorials/gpb/fixed-gas.md)): the phase and composition files as in the reference, the thermo and transport tables on a sample. |
| `IG-reactive` | GPB | `GPB/IG-reactive` | A mechanism read by Cantera, NASA9 thermo and Cantera transport ([Cantera Ideal-Gas](../tutorials/gpb/cantera-ideal-gas.md)): phase, composition and `chemistry-info.txt` as in the reference; the thermo, transport, diffusion and rate tables (12 MB) on a sample. |
| `IG-gri30` | GPB | `GPB/IG-gri30` | GRI-Mech 3.0, which the Cantera of ATLAS ships (`reactions = gri30`, no file in `database/chemistry/`): `chemistry-info.txt` names the phase `gri30` and counts 53 species and 325 reactions. |
| `IG-mixture-HG` | GPB | `GPB/IG-mixture-HG` | Air with liquid alumina as one heavy gas ([Heavy-Gas Mixture](../tutorials/gpb/heavy-gas.md)): the species of mean properties and its tables, on a sample. |
| `SP-Tvar` | GPB | `GPB/SP-Tvar` | A solid from the solid database ([Solid Phase](../tutorials/gpb/solid.md)): the phase file, and the property table on a sample. |
| `RF-co2` | GPB | `GPB/RF-co2` | The CO₂ tables of a real fluid on a 40 × 40 grid of pressure and enthalpy, from CoolProp ([Real-Fluid Phase](../tutorials/gpb/real-fluid.md)), on a sample. |
| `IG-inflow-nozzle` | BCB | `BCB/IG-inflow-nozzle` | Nozzle inflow boundary-condition construction. |
| `IG-inflow-ceafile-inertmix` | BCB | `BCB/IG-inflow-ceafile-inertmix` | Inflow BC creation using CEA-based inert-mixture inputs. |
| `IG-multipatch-file` | BCB | `BCB/IG-multipatch-file` | Multipatch BC assignment when patches are provided by file. |
| `IG-multipatch-1D` | BCB | `BCB/IG-multipatch-1D` | 1D multipatch face mapping and resulting BC output. |
| `IG-chimera` | BCB | `BCB/IG-chimera` | Chimera/overset boundary metadata generation. |
| `IG-chimera+connection` | BCB | `BCB/IG-chimera+connection` | Chimera and standard connection coexisting on one layout. |
| `IG-force-chimera` | BCB | `BCB/IG-force-chimera` | `BC-force-chimera` on a partial interface. |
| `mesh-p3d-3D` | BCB | `BCB/mesh-p3d-3D` | A PLOT3D mesh alone, with three coordinates and several node planes, is read as 3D: `bc.txt` equals the one of the same grid in Tecplot. |
| `DP-basic` | BCB | `BCB/DP-basic` | Dispersed-phase BC assignment and export. |
| `IG+CD` | BCB | `BCB/IG+CD` | A gas phase and a dispersed phase on one inlet: `gas-bc.txt` and `particles-bc.txt` are written together. |
| `IG-plate-keys` | BCB | `BCB/IG-plate-keys` | The plate keys `full-plate` and `z-hydra` pass the key check and give the product of `IG-multipatch-file`. |
| `IG-renamed-keys-lenient` | BCB | `BCB/IG-renamed-keys-lenient` | `rt` and `force-connect` are unknown keys: with `strict-keys = false` a WARNING naming the current key. |
| `IG-value-not-a-number` | BCB | `BCB/IG-value-not-a-number` | A value with a trailing comment (`T0 = 3400.0 ! K`) stops BCB naming the key: it is not a number; nothing is written. |
| `DP-phase-type-refused` | BCB | `BCB/DP-phase-type-refused` | `<phase>-type` on a face where no reader uses it stops BCB naming the key and the face type. |
| `IG-keys-documented` | BCB | `BCB/IG-keys-documented` | `Ae_At = 0`, `a1-a3 = 0` (not given) are silent; `u` and `p-time-file` get one WARNING each and do not stop BCB. |
| `IG-nozzle-arearatio` | BCB | `BCB/IG-nozzle-arearatio` | BC 420 from `Ae_At` on a constant-cp gas (closed-form thresholds). |
| `IG-borda-2D` | BCB | `BCB/IG-borda-2D` | BC 421 Borda injector on a 2D mesh; the product passes `scripts/check-bc.py`. |
| `IG-turbulence-boundary-weighted` | BCB | `BCB/IG-borda-2D` | `rhoK` on an inlet stops BCB as an unknown key whose hint names the specific `k` (a boundary takes the specific values, weighted by the solver). |
| `IG-inflow-405a` | BCB | `BCB/IG-inflow-405a` | The supersonic 405 given by `mach`, `p0`, `T0` (static state of the isentropic expansion). |
| `IG-composition-sum-refused` | BCB | `BCB/IG-composition-sum-refused` | Mass fractions of an inlet that sum to 0.99 stop BCB naming the section and the sum; nothing is written. |
| `IG-nozzle-inlet-envelope-refused` | BCB | `BCB/IG-nozzle-inlet-envelope-refused` | A nozzle inlet (BC 420) with `psup` above `psub` stops BCB (0 < psup <= psub < p0 is required); nothing is written. |
| `IG-2D-inlet-408-refused` | BCB | `BCB/IG-2D-inlet-408-refused` | A normal-velocity inlet (BC 408) on a pure 2-D mesh stops BCB: Q2D, which reads 2-D meshes, does not implement BC 408; nothing is written. |
| `IG-force-connect-plate` | BCB | `BCB/IG-force-connect-plate` | `BC-force-connect` on an injection plate declared inlet with hole blocks: hole cells connected (101), the rest keeps the inlet, one LOG line. |
| `IG-time-file-long-name` | BCB | `BCB/IG-time-file-long-name` | A time-file name over 32 characters: accepted with `line-file` (32-character file and record), refused for a user file. |
| `IG-linefile-sector-axis` | BCB | `BCB/IG-linefile-sector-axis` | A line-file strip over a quarter of the lap, `n-repeat = 4` and `axis = x`, on a face whose inward normal is -x: every face cell holds the closed-form law of the strip at 4 theta, the axial velocity enters the domain, one `[INFO]` line; `axis = y`, parallel to the face, stops BCB. |
| `IG-multipatch-410-linefile` | BCB | `BCB/IG-multipatch-410-linefile` | A 410 inlet written from a line-file as the one patch of a multipatch face gives the `bc.txt` of the same face declared directly; two patches run. |
| `IG-ablation` | BCB | `BCB/IG-ablation` | BC 505 (ablation, surface reactions): the model id is written as an integer, as the solver reads it. |
| `IG-table-no-data` | BCB | `BCB/IG-table-no-data` | A table file without any row of two numbers is refused as a file without data rows, not as a missing file. |
| `IG-multigrid-2D` | BCB | `BCB/IG-multigrid-2D` | `MG-levels = 3` on a pure-2D mesh: `bc2.txt` and `bc3.txt` are pure 2D, equal to `bc.txt` of the level meshes given directly. |
| `BCB-direction-refused` | BCB | `BCB/IG-xtheta-variable-T` | A direction letter outside x, y, z, r, t, i, j, k (here `X`) stops BCB naming the key. |
| `SP-wall-305` | BCB | `BCB/SP-wall-305` | A solid wall with `hconv`, `eps` and `Tref` is written as BC 305 with the payload in the order FUSS reads it (`hconv, eps, Tref`); `eps` and `Tref` alone stay 304. |
| `mesh-p3d-fallback` | BCB | `BCB/mesh-p3d-fallback` | An unreadable `mesh.p3d` is followed by `mesh.szplt` with a WARNING naming both files. |
| `IG-table-header-skipped` | BCB | `BCB/IG-table-header-skipped` | A table row that is not two numbers is skipped with a WARNING; the product is that of the file without the row. |
| `IG-table-not-monotone` | BCB | `BCB/IG-table-not-monotone` | A table whose coordinate column turns back is refused: the reader names the row and BCB says the file is refused for its content. |
| `IG-table-decreasing` | BCB | `BCB/IG-table-decreasing` | A table with decreasing coordinates gives the `bc.txt` of the same rows in increasing order. |
| `IG-duplicate-section-lenient` | BCB | `BCB/IG-duplicate-section-lenient` | With `strict-keys = false` a section written twice in the `BCB-file` gets one WARNING; `bc.txt` is that of the deck without the copy. |
| `IG-duplicate-section-identical` | BCB | `BCB/IG-duplicate-section-identical` | With the default settings a section written twice with the same keys and values (other key order, a comment line, a blank line) gets one WARNING that says so; `bc.txt` is that of the deck with one copy. |
| `IG-duplicate-section-conflict` | BCB | `BCB/IG-duplicate-section-conflict` | Two copies of a section that differ: the ERROR and no `bc.txt` with the default settings; one WARNING and the `bc.txt` of the first copy with `strict-keys = false`. |
| `mesh-p3d-single-plane` | BCB | `BCB/mesh-p3d-single-plane` | A PLOT3D mesh with one node plane (`Ni Nj 1`) is the pure-2D mesh of its x-y plane: `bc.txt` of the same grid in Tecplot. |
| `mesh-p3d-plane-perpendicular` | BCB | `BCB/mesh-p3d-plane-perpendicular` | A PLOT3D mesh with one node plane in x-z (no area on x-y) is refused. |
| `mesh-tec-single-plane` | BCB | `BCB/mesh-tec-single-plane` | A Tecplot mesh with x y z on one node plane (`K = 1`) follows the PLOT3D rule: on z = 0 and on a tilted plane the `bc.txt` of `mesh-p3d-single-plane` (a WARNING for the tilted plane); on x-z it is refused. |
| `IG-comment-lines` | BCB | `BCB/IG-basic` | Comment lines starting with `#`, `;` or `!` that hold an equals sign are ignored: `bc.txt` equals the one of the deck without them. |
| `IG-massfraction-range` | BCB | `BCB/IG-massfraction-range` | A `y<species>` value outside [0, 1] stops BCB with one message naming the key and the value; a value outside by rounding only (1.0000000000000002, -1.0e-20) is read as 1 and 0. |
| `IG+SP-force-chimera` | BCB | `BCB/IG+SP-force-chimera` | Inter-phase chimera: with `BC-force-chimera` the facelets between a gas block and a solid block are written as 104 in both `gas-bc.txt` and `solid-bc.txt`. |
| `DP-multigrid` | BCB | `BCB/DP-multigrid` | One dispersed-phase BC file per multigrid level, each with its own table and every (material, population) copy. |
| `DP-z-variable-krho` | BCB | `BCB/DP-z-variable-krho` | Dispersed-phase inlet with a `krho` profile read along z and phase-prefixed keys. |
| `DP-tokens-tolerated` | BCB | `BCB/DP-tokens-tolerated` | `key=value` tokens on the material line of a dispersed-phase file are for the solvers: BCB ignores them and writes the `drop-bc.txt` of `DP-basic`. |
| `DP-bad-name` | BCB | `BCB/DP-bad-name` | A phase file name with two dashes is refused. |
| `DP-substring-names` | BCB | `BCB/DP-substring-names` | Phase names nested in each other (`part`, `partL`) are refused before any BC file is built. |
| `DP-two-phases` | BCB | `BCB/DP-two-phases` | Two dispersed phases on the same faces: each `<name>-bc.txt` carries the ids and payloads of its own phase. |
| `DP-mixture-401` | BCB | `BCB/DP-mixture-401` | Three dispersed phases on shared inlet cells: the `401` records carry `krho/(1 - krho_tot)` and end with `G`, the mass flux of the `402` phase; a `krho` sum of 1 or more stops BCB naming the section, with no file; a negative `krho` stops it naming the section and the phase. |
| `DP-distribution-missing` | BCB | `BCB/DP-distribution-missing` | A `distribution` file that does not exist stops BCB naming it, also with `sigmap = 0` (which turns only a law name into `Dirac`); nothing is written. |
| `DP-distribution-long-path` | BCB | `BCB/DP-distribution-long-path` | A 40-character `distribution` path with `sigmap = 0` is written whole in column 8 of the `401` records: the `drop-bc.txt` of `DP-basic` with that path and `sigmap = 0`. |
| `DP-chimera` | BCB | `BCB/DP-chimera` | Two blocks that overlap through one face each: the dispersed-phase file carries the 102 records with their donors and volume fractions (tolerance 1e-6, as `IG-chimera`). |
| `DP-chimera-pure2D` | BCB | `BCB/DP-chimera-pure2D` | The mesh of `DP-chimera` as one node plane (pure 2D): five-integer headers on four faces, and on every 102 facelet the donors and volume fractions of `DP-chimera` (the depth cancels in a volume fraction). |
| `DP-axis-override` | BCB | `BCB/DP-axis-override` | `<phase>-type = outlet` on an axisymmetric face: the dispersed-phase file carries 400 on the axis, the gas file keeps 200. |
| `DP-axis-symmetry` | BCB | `BCB/DP-axis-symmetry` | `<phase>-type = symmetry` on an axisymmetric face: the dispersed-phase file carries 300 on the axis, the gas file keeps 200. |
| `DP-axis-refused` | BCB | `BCB/DP-axis-refused` | Any other `<phase>-type` word on an axisymmetric face stops BCB naming the two accepted ones. |
| `IG+SP-chimera-ks` | BCB | `BCB/IG+SP-chimera-ks` | Chimera between two phases (104) with wall roughness: the donors are found in the other phase, the gas records carry `ks` at the end of the donor-count line, the solid ones none. |
| `IG+SP-chimera-corner` | BCB | `BCB/IG+SP-chimera-corner` | A 104 interface along an L-shaped wall: the ghost cells that touch the corner block with zero volume stay 104. |
| `IG-chimera-warped` | BCB | `BCB/IG-chimera-warped` | Chimera on warped cells: every fully covered receiver closes (no `division failed` in `chimera.log`) and the thin donors are kept. |
| `DP-population-list` | BCB | `BCB/DP-population-list` | A per-population key takes one value per (material, population) pair, in the order of the phase file. |
| `DP-population-count` | BCB | `BCB/DP-population-count` | A per-population key with a count other than 1 or one per pair stops BCB. |
| `DP-population-forms` | BCB | `BCB/DP-population-forms` | The value forms of a per-population key (`450, 460, 470`, `0.01/ 0.02, 0.03`, `3*345.0`) give the BC file of DP-population-list. |
| `DP-logical-forms` | BCB | `BCB/DP-logical-forms` | Logical keys written `.true # ...`, `T ! ...`, `F` or with a TAB read as their first item, the BC files unchanged; `strict-keys` is read before any key table. |
| `IG-2D` | BCB | `BCB/IG-2D` | Four blocks with mass-flux inlets (`404`), an adiabatic wall, connections and an outlet (`406`) ([Inlets, Outlets and Walls](../tutorials/bcb/walls-and-inlets.md)). |
| `IG-multipatch-2D` | BCB | `BCB/IG-multipatch-2D` | Six patches of an injector plate along r and theta ([Several Conditions on One Face](../tutorials/bcb/multipatch.md)). |
| `IG-multipatch-gap` | BCB | `BCB/IG-multipatch-2D` | Ranges that leave 300 cells of the face out stop BCB, naming the face, the count and the first cell; nothing is written (the cells were written `0`, a face with no BC, without a word). |
| `IG-multipatch-overlap` | BCB | `BCB/IG-multipatch-2D` | Overlapping ranges: every cell takes the first patch whose range holds it (a later patch built the cell again and BCB crashed). |
| `IG-chimera-off` | BCB | `BCB/IG-chimera` | `chimera` faces with `BC-chimera = false` stop BCB naming each face; nothing is written (the faces were written `100`, which no solver reads). |
| `IG-xtheta-variable-T` | BCB | `BCB/IG-xtheta-variable-T` | A wall temperature read from a table over x and theta: `302` records, each with its own temperature ([Boundary Data From Tables](../tutorials/bcb/data-files.md)). |
| `IG-inflow-p0time` | BCB | `BCB/IG-inflow-p0time` | A total pressure from a time table: `402` records naming `p0time.txt` ([Boundary Data From Tables](../tutorials/bcb/data-files.md)). |
| `IG-periodic` | BCB | `BCB/IG-periodic` | Connections between blocks and a periodic pair, `201` ([Connections and Periodic Faces](../tutorials/bcb/connections.md)). |
| `tutorial-reservoir-inlets` | BCB | `tutorials/bcb-reservoir-inlets` | The three inlets of one reservoir, `401`, `405` and `420`, from the INI files of [Inlets From Reservoir Conditions](../tutorials/bcb/reservoir-inlets.md) on the mesh and table of `IG-nozzle-arearatio`. |
| `DP-gsi-manifold` | BCB | `BCB/DP-gsi-manifold` | A dispersed phase on the faces of the 500 family: `300` on a manifold and on every gsi patch but a grain (`502`) that gives inlet keys of the phase, which injects it as an inlet does (`401`); the gas file's `502` records carry the propellant mass flux `a·rhoGrain·SF`, times `1 − krho_tot`. |
| `DP-gsi-grain-flow` | BCB | `BCB/DP-gsi-grain-flow` | The gas flow of a solid-propellant grain shared with the dispersed phases it injects: `a·rhoGrain·SF` times `1 − krho_tot`, one `krho` per (material, population) pair; a `krho_tot` above 1, or a mass flux (`403`) on the grain, is refused. |
| `DP-gsi-keys-refused` | BCB | `BCB/DP-gsi-keys-refused` | An inlet key of a dispersed phase on a 500 face that does not inject it (`505`, `501`) stops BCB naming the key, the section, the BC and the face's role; with `strict-keys = false`, one warning and the files of `DP-gsi-manifold`. |
| `IG-2D-grain-inflow` | BCB | `BCB/IG-2D-grain-inflow` | A solid-propellant grain (`502`) on a 2-D mesh: mode 2 (an inlet, the default and `grain-wall = .false.`) with the turbulence of the section, mode 1 (`grain-wall = .true.`, a wall) without it; a turbulence value left at 0 reported with a WARNING; `grain-wall = si` refused, with no file. |
| `IG-grain-a-missing-refused` | BCB | `BCB/IG-grain-a-missing-refused` | A grain (`502`, `grain-wall = T`) without `a` stops BCB naming the key, with no `bc.txt`; `a = 0` writes a surface that does not burn (`a rhoGrain SF` = 0, mode 1); an `a-file` gives `a rhoGrain SF` at each cell centre. |
| `SP-basic` | ICB | `ICB/SP-basic` | Basic solid initial-condition field generation. |
| `IG-nozzle3D` | ICB | `ICB/IG-nozzle3D` | 3D nozzle initial-condition generation and VTK export path. |
| `IG-interp-mindist` | ICB | `ICB/IG-interp-mindist` | Minimum-distance interpolation onto a grid carrying solver-style extra variables. |
| `ICB-type-refused` | ICB | `ICB/ICB-type-refused` | A zone `type` that no writer knows stops ICB naming the value. |
| `IG-interp-2D` | ICB | `ICB/IG-interp-2D` | Pure-2D source onto a pure-2D target (index law). |
| `IG-interp-2Dto3D` | ICB | `ICB/IG-interp-2Dto3D` | Pure-2D source onto a revolved 3D target: the source mesh is classified in its own configuration and the product keeps the 3D layout (tolerance 1e-12). |
| `IG-interp-rans-src` | ICB | `ICB/IG-interp-rans-src` | Source with a trailing turbulence band: the SA model of the source is adopted and `rhoNuTilde` interpolated. |
| `IG-interp-3D` | ICB | `ICB/IG-interp-3D` | 3D source onto a 3D target (index law). |
| `IG-interp-extrude` | ICB | `ICB/IG-interp-extrude` | `interpolation-law = extrude` (`theta`, `nz`) on a target revolved with the same cells gives the field of the index law. |
| `IG-zones-index-direction` | ICB | `ICB/IG-zones-index-direction` | Zones ranged by cell index (`direction = i`) give the field of the same zones ranged by coordinate. |
| `IG-zone-interp-range` | ICB | `ICB/IG-zone-interp-range` | An interpolation zone writes the cells of its range only (both zone orders give the same field). |
| `SP-interp` | ICB | `ICB/SP-interp` | A solid field interpolated onto its own mesh is the source field. |
| `IG-pfile-oneplane-2block` | ICB | `ICB/IG-pfile-oneplane-2block` | One-plane (K=1) `p-file` sources on two blocks: the source array keeps its plane. |
| `IG-zone-unwritten-refused` | ICB | `ICB/IG-zone-unwritten-refused` | Cells that no zone writes stop ICB naming block, phase and count. |
| `IG+DP-phase-order` | ICB | `ICB/IG+DP` | `phase = particles gas` builds as `gas particles`: the dispersed state derives from the gas state. |
| `ICB-phase-key-refused` | ICB | `ICB/IG+DP` | A phase name that no phase file declares, and a dispersed phase without the gas it derives from, stop ICB naming the cause. |
| `IG-pfile-oneplane-noK` | ICB | `ICB/IG-pfile-oneplane-2block` | A two-block pure 2-D p-file written without K in its ZONE lines reads like K = 1: the product equals the K = 1 reference. |
| `IG-zone-interp-range-turb` | ICB | `ICB/IG-zone-interp-range-turb` | A partial interpolation zone that adopts the source turbulence model writes `rhoNuTilde` in its range only; the cells of the other zone keep 0. |
| `IG-turbulence-specific` | ICB | `ICB/IG-turbulence-specific` | Turbulence keys: the specific `k`, `omega`, `nuTilde` are written times the cell density, the density-weighted `rhoK`, `rhoOmega`, `rhoNuTilde` as given, in the bands `rhoK`, `rhoOmega`, `rhoNuTilde`. |
| `IG-turbulence-keys-refused` | ICB | `ICB/IG-turbulence-specific` | `k` and `rhoK` in one zone stop ICB (one quantity given twice); the retired `kappa` stops ICB as an unknown key whose hint names `k` and `rhoK`; `nut`, the eddy viscosity, stops it with a hint that names `nuTilde`. |
| `IG-turbulence-source-names` | ICB | `ICB/IG-turbulence-specific` | Turbulence bands of an interpolation source, by name: the specific `k`, `omega` are multiplied by the density of the source; `rhoK`, `rhoOmega` and the earlier `kappa`, `omega` are carried as they are. |
| `IG-turbulence-source-names-sa` | ICB | `ICB/IG-turbulence-specific` | Spalart-Allmaras band of an interpolation source, by name: `rhoNuTilde` is carried as it is, `nuTilde` is multiplied by the density of the source, and `mut` (the eddy viscosity) is ignored with a notice. |
| `velocity-angles` | ICB | `ICB/velocity-angles` | `alpha`, `beta` give the speed the direction `(cos alpha cos beta, sin alpha cos beta, sin beta)` of the solvers' inflow BC and keep its magnitude, in an ideal-gas zone (`mach`) and a real-fluid zone (`vel`). |
| `IG-nozzle-threshold-last` | ICB | `ICB/IG-nozzle-threshold-last` | `nozzle-threshold` between the centres of the last two cells: with `dx` the two rows upstream of it are the plenum and the last takes the nozzle law, with `sx` the last row is the plenum and the first two take the law (ICB wrote the row after the first cell past the threshold, here past the arrays, a Bus error on macOS). |
| `IG-profile-zones` | ICB | `ICB/IG-profile-zones` | 1-D profiles in zones: a zone's `T-file` table covers its own range only, a cell centre on the first point of a table takes its value, a constant next to its profile and a direction without a profile stop ICB; a solid block split along `xi` honours both letters; a field profile of nodal variables stops ICB naming the file. |
| `IG-range-separator-refused` | ICB | `ICB/IG-multizone` | A TAB between the two values of `range<n>` stops ICB naming the separator (the values are read on blanks). |
| `IG-turbulence-zero-refused` | ICB | `ICB/IG-turbulence-zero-refused` | A k-omega zone (nrans = 2) with `k` and no `omega` stops ICB (omega = 0 would divide in the solver kernels); nothing is written. |
| `IG-state-not-physical` | ICB | `ICB/IG-state-not-physical` | A zone with a negative pressure stops ICB naming the first cell and the state; nothing is written. |
| `IG-interp-band-refused` | ICB | `ICB/IG-interp-band-refused` | An interpolation source whose band after the velocities is `T`, not `p`, stops ICB naming the band; nothing is written. |
| `IG-species-profile-linear` | ICB | `ICB/IG-species-profile-linear` | `y<species>-file` tables along x (`yH2` linear, `yN2` its complement) next to a constant `yO2`: every cell holds the analytic mass fractions, summing to 1, and a density that follows its own composition. |
| `IG-interp-2D-wband` | ICB | `ICB/IG-interp-2D-wband` | The source of `IG-interp-2D` with a third velocity band `w = 0` after `v`: read, same `gas-ic.tec`. |
| `IG-block-no-section` | ICB | `ICB/IG-block-no-section` | A block that no `[ICB-Block<n>]` or `[ICB-Block*]` section describes stops ICB naming the block. |
| `IG-phase-unbuilt` | ICB | `ICB/IG-phase-unbuilt` | A phase that no block names is not written (one `[WARNING]`, no `part-ic.tec`). |
| `IG-interp-spherical-3D` | ICB | `ICB/IG-interp-spherical-3D` | `interpolation-law = spherical_minimum_distance` on a 3-D target: from a one-cell source it equals `minimum_distance`. |
| `IG-interp-src-3coord-plane` | ICB | `ICB/IG-interp-src-3coord-plane` | An interpolation source written as a slice (x y z on one node plane, `K = 1`, z nodal, bands cell-centred) gives the `ic.tec` of the same source written with x y only. |
| `IG-nozzle-plenum-order` | ICB | `ICB/IG-nozzle-plenum-order` | The plenum rows of a nozzle zone and another zone overwrite each other in the zone order: a `[WARNING]` names each case and the products do not change. |
| `IG-nozzle-area-law` | ICB | `ICB/IG-nozzle-area-law` | The nozzle law on a converging-diverging quarter annulus, row by row against the quasi-1-D isentropic law solved independently (3e-15): the throat row exactly sonic; with and without `nozzle-threshold` in both directions: the plenum is the rows whose centre lies upstream of the threshold (x below it with `dx`, above it with `sx`), every row or none for a threshold beyond the block, none without a threshold. |
| `IG-nozzle-geometry-refused` | ICB | `ICB/IG-nozzle-geometry-refused` | The nozzle law on a block that is no nozzle stops ICB before anything is written: a constant section (a Fortran backtrace in `legge_aree` before), walls at the same distance from the x axis, i running towards -x. |
| `IG-interp-multiple-x3-3D` | ICB | `ICB/IG-interp-multiple-x3-3D` | A uniform 2x2x2 source refined by 3 in 3-D with `interpolation-law = multiple` stays uniform: the product equals the one of `minimum_distance`. |
| `IG-interp-multiple-x3-linear` | ICB | `ICB/IG-interp-multiple-x3-linear` | A field linear in the cell indices, refined by 3 with `interpolation-law = multiple`, is reproduced exactly inside the block in 2-D and in 3-D. |
| `IG-ic-write-failure` | ICB | `ICB/IG-ic-write-failure` | When ORION cannot write the binary initial condition (a folder stands where `ic.szplt` goes), ICB stops with exit status 1 naming the file (registered in builds with TecIO). |
| `IG+DP` | ICB | `ICB/IG+DP` | Gas and dispersed phase: the dispersed-phase IC file carries the population fields. |
| `IG+DP-populations` | ICB | `ICB/IG+DP-populations` | A scalar dispersed-phase key of a zone (`krho`, `dp`) reaches every population: population 2 takes the fields of population 1, which are IG+DP's reference. |
| `IG+DP-population-forms` | ICB | `ICB/IG+DP-population-forms` | The value forms of a per-population key in a block section (`krho = 0.20, 0.30`, `dp = 2*20e-6`) give the fields of the plain lists. |
| `ICB-IG-2D` | ICB | `ICB/IG-2D` | One state per block on the four blocks of BCB's `IG-2D`, on a sample of the field. |
| `IG-nozzle2D` | ICB | `ICB/IG-nozzle2D` | The nozzle law of a 2-D nozzle from its reservoir, with k-omega turbulence, on a sample of the field. |
| `tutorial-uniform` | ICB | `tutorials/icb-uniform` | The INI of [A Uniform State, Block by Block](../tutorials/icb/uniform.md) on the mesh of `ICB/IG-2D`. |
| `tutorial-nozzle` | ICB | `tutorials/icb-nozzle` | The INI of [Nozzle Flow](../tutorials/icb/nozzle.md) on the mesh of `ICB/IG-nozzle2D`. |
| `tutorial-zones` | ICB | `tutorials/icb-zones` | The INI of [Zones in a Block](../tutorials/icb/zones.md), a shock tube, on the mesh of `ICB/IG-multizone`. |
| `tutorial-particles` | ICB | `tutorials/icb-particles` | The INI of [A Gas With Particles](../tutorials/icb/particles.md) on the mesh and phases of `ICB/IG+DP`: the gas and the particle fields. |
| `x-variable` | STB | `STB/x-variable` | Spatially varying source-term generation along x. |
| `area-any-order` | STB | `STB/area-any-order` | An area profile in any row order gives the area law of the sorted profile. |
| `qvol-direction-combined` | STB | `STB/qvol-direction-combined` | A qvol profile with `direction = xy` is read along x with a `[WARNING]`: `st.tec` equals the one of `direction = x`. |
| `qvol-3D-conservative` | STB | `STB/qvol-3D-conservative` | A `qvol-file` without `direction` is a 3D Tecplot field remapped conservatively (two donor cells of 10 W and 30 W, the second half covered: 10, 10, 60 W/m3, 40 W in all); the same field as a `qvol` density gives the same `st.tec`, `qvol-remap = fraction` gives 10, 10, 30 W/m3 (25 W); a table without `direction`, a field with `direction` and a `qvol-remap` outside covered/fraction are refused. |
| `STB-uniform` | STB | `STB/uniform` | One volumetric source over the whole block ([A Volumetric Heat Source](../tutorials/stb/heat-source.md)), on a sample of the field. |
| `balance-only` | MDB | `MDB/balance-only` | Load-balancing pass without splitting. |
| `block-directions` | MDB | `MDB/block-directions` | Per-direction block splitting behaviour. |
| `halo-trade` | MDB | `MDB/halo-trade` | Halo exchange bookkeeping between partitions. |
| `mg3-granularity` | MDB | `MDB/mg3-granularity` | Partition granularity under 3 multigrid levels. |
| `split-longest` | MDB | `MDB/split-longest` | Splitting along the longest block direction. |
| `split-solution` | MDB | `MDB/split-solution` | Splitting a case that carries a solution field. |
| `cube48-r12`, `cube48-r20` | MDB | `MDB/cube48-r12`, `MDB/cube48-r20` | `objective = halo` on a 48³ cube for 12 and 20 ranks: the searched decomposition scores strictly better than the greedy walk of `greedy.ini` (`analyse_decomp.py --assert-better`). |
| `three-parents` | MDB | `MDB/three-parents` | The same gate on three parent blocks. |
| `three-parents-cost` | MDB | `MDB/three-parents-cost` | `objective = cost`: the searched cut predicts a strictly smaller rank time (`Predicted rank time (max)` of MDB's model) than the greedy walk. |
| `coupled-phases-chimera-ks` | MDB | `MDB/coupled-phases-chimera-ks` | 104 records with roughness: the donors are remapped against the decomposition of the other phase and the roughness is carried through the split. |
| `manifold-remap` | MDB | `MDB/manifold-remap` | A manifold (501) payload survives the split: renumbered to the piece that inherits the whole source face, both pieces on one rank. |
| `manifold-split-ranks` | MDB | `MDB/manifold-split-ranks` | A 501 pair that the solvers' LPT would put on two ranks: MDB stops with the decomposition instead of writing files MOSE would refuse. |
| `manifold-face-cut` | MDB | `MDB/manifold-face-cut` | A cut through the source face of a manifold is refused, naming the direction that keeps the face whole. |
| `gsi-melting` | MDB | `MDB/gsi-melting` | A gas-surface record (503) keeps its property line through the split. |
| `coupled-same-cut` | MDB | `MDB/coupled-same-cut` | `same-cut = true`: a gas and a dispersed phase on the same blocks get one decomposition, their maps identical byte for byte. |
| `same-cut-mismatch` | MDB | `MDB/same-cut-mismatch` | `same-cut = true` on two different meshes stops MDB, naming the block and the two extents. |
| `sweep` | MDB | `MDB/sweep` | `ATLAS MDB -- --sweep 4,7,12`: one table of the `objective = halo` decomposition at every rank count, nothing written. |
| `tutorial-mdb-split` | MDB | `tutorials/mdb-split` | GPB, BCB, ICB and MDB from the one INI of [A Case for MPI](../tutorials/mdb/index.md): the split field carries ICB's cell by cell, the map and the split BC file as in the reference. |
| `KAnT-equilibrium` | KAnT | `KAnT/equilibrium` | The HP equilibrium of three mechanisms at 20 chamber pressures ([Checking a Mechanism](../tutorials/kant/index.md)). |
| `tutorial-kant-ignition` | KAnT | `tutorials/kant-ignition` | The ignition delays of FFCM-2 and WD at 10 initial temperatures ([Checking a Mechanism](../tutorials/kant/index.md)), to a relative 5e-2. |
| `KAnT-ignition-JLR` | KAnT | `KAnT/ignition_delay_jlr` | The ignition delays of the two JLR mechanisms (run in their Cantera form `JLR-*-ct.yaml`) at 10 initial temperatures, to a relative 5e-2: every case ignites, and an integrator that stops after the ignition is one WARNING per mechanism. |
| `KAnT-ignition-gri30` | KAnT | `KAnT/ignition_delay_gri30` | The ignition delay of GRI-Mech 3.0, read by name from the Cantera that ATLAS employs, at 3 initial temperatures, to a relative 5e-2. |
| `GUI-icmodel` | GUI | `GUI/tests` | The ICB model of the GUI: every deck of the suite goes through the case document and back with its ICB sections unchanged, an ICB zone section is never read as a BC, the keys the GUI names are ICB's, and the checks of the Initial stage flag no ICB deck the tool accepts while catching the refusals they can see from the deck (standard library, no Qt). |
| `GUI-icgeom` | GUI | `GUI/tests` | Where the GUI puts the zones of an ICB block on the mesh: on random zone decks over a pure 2-D, an extruded 2-D and a 3-D mesh, along every direction letter, the cells written after each zone, the count of cells no zone writes and the first of them are those ICB reports, and so are the plenum rows of the nozzle decks of the suite and the cells of a zone that a random profile table misses; the state the 3-D view gives every cell is the one ICB writes there, on random decks whose zones each have a pressure of their own, nozzle zones and their plenums at rest included; an interpolated zone takes the turbulence model of its source, and the cells of the other zones without turbulence are those ICB warns about (Spalart-Allmaras) or stops on (k-omega) (numpy, no Qt; skipped without numpy). |
| `GUI-runner` | GUI | `GUI/tests` | How the GUI runs the tools: the checks before a run (the mesh and the phase files BCB and ICB read, `filelist.txt`, a tool not built, the GUI's errors by stage); `ATLAS ICB` from a shell leaving out the phase file an earlier deck left in `fromATLAStoSolver/`; with PyQt6 the chain, Stop, ICB run as from a shell, GPB then ICB; where each message of a run lands. |
| `GUI-icfield` | GUI | `GUI/tests` | The initial field read back from ICB, ASCII Tecplot and VTK: the colour scales, every zone on its block, the quantities derived from the bands. |
| `GUI-outputs` | GUI | `GUI/tests` | What the GUI reads back of GPB and BCB: the tables of every kind of phase, the real-fluid grid, the reactions, the BC id of every face cell, the multigrid levels. |
| `GUI-layout` | GUI | `GUI/tests` | The window on simulated laptop screens at three text sizes, offscreen: no widget squeezed below its minimum, no label narrower than its text, no text over text. |
| `IG-total-conditions` | ICB, BCB | `ICB/IG-total-conditions` | A zone given by `p0`, `T0` and `mach` carries the static T and p of the supersonic inlet (BC 405) given by the same keys, on a variable-cp N2 table; the zones that reach the same flow from `T0` or `T`, by `mach` or by `u`, `v`, `w`, carry the same state to 1e-12, and the speed is `mach` times the speed of sound of the table's cp; `mach` next to `u`, `v`, `w` stops ICB. |
| `grid-p3d-3D` | BCB + MDB | `MDB/grid-p3d-3D` | A 3D grid given to MDB as a PLOT3D file is split as the same grid in Tecplot. |
| `coupled-phases` | BCB + MDB | `MDB/coupled-phases` | Two-phase interface: type-`103` donors remapped against the other phase's decomposition. |
| `dispersed-populations` | BCB + MDB | `MDB/dispersed-populations` | A dispersed phase with two materials, one of them in two populations, on two multigrid levels: the per-(material, population) tables are split block by block. |
| `coupled-phases-ks` | BCB + MDB | `MDB/coupled-phases-ks` | `coupled-phases` with a uniform roughness `ks` on the gas connection: MDB carries it through the split; the solid files are unchanged. |
| `coupled-phases-ksfile` | BCB + MDB | `MDB/coupled-phases-ksfile` | The same interface with a real-fluid gas and `ks` read from a file along x: each 103 record gets the value at its own centre. |

## Test Families And Their Intent

### BCB Cases (`test/BCB/`)

BCB tests check that boundary-condition definitions are translated into correct solver-ready BC files.

- `IG-basic`, `IG-2D`: validate baseline ideal-gas BC setup in different dimensional layouts.
- `IG-periodic`: validate periodic-face pairing logic.
- `IG-multipatch-*`: validate patch indexing, file-driven patches, and multi-face mapping behavior; a cell in two
  ranges takes the first patch (`-overlap`), and ranges that leave cells of the face out stop BCB (`-gap`).
- `IG-inflow-*`: validate inflow models, including nozzle and CEA-coupled inflow definitions.
- `IG-chimera`: validate overset/chimera boundary metadata preparation; `IG-chimera-off`: the refusal of `chimera`
  faces with `BC-chimera = false`.
- `mesh-p3d-3D`: validate the search of a PLOT3D mesh alone and its 3D reading (the product of the same grid in Tecplot).
- `IG+CD`, `IG+SP`, `DP-*`, `SP-basic`: validate mixed boundary models (ideal gas, condensed, dispersed, solid).
- `IG-nozzle-arearatio`: validate the BC 420 injector nozzle (thresholds from `Ae_At`).
- `IG-borda-2D`: validate the BC 421 Borda injector (a Q2D-only record on a 2D mesh).
- `mesh-p3d-fallback`: validate the mesh search (`mesh.tec` -> `mesh.p3d` -> `mesh.szplt`) when `mesh.p3d` cannot be read.
- `IG-table-not-monotone`: validate the refusal of a table whose coordinate column turns back (the message says the file is refused, not missing).
- `IG-table-decreasing`, `IG-table-no-data`: validate a table with decreasing coordinates (read in increasing order) and the refusal of a table file without data rows (not reported as missing).
- `IG-duplicate-section-lenient`: validate the lenient key check of a section written twice (the options of the next sections are all read).
- `IG-duplicate-section-identical`, `IG-duplicate-section-conflict`: validate the rule for a section written twice: two copies with the same keys and values only warn, copies that differ stop the tool unless `strict-keys = false`.
- `mesh-p3d-single-plane`: validate a PLOT3D mesh written with one node plane (read as the pure-2D mesh of its x-y plane).
- `mesh-p3d-plane-perpendicular`: validate the refusal of a single node plane perpendicular to x-y.
- `mesh-tec-single-plane`: validate the same rule for a Tecplot mesh with x y z on one node plane (`K = 1`).
- `IG-multigrid-2D`: validate the coarse levels of a pure-2D mesh (pure 2D on every level).
- `IG-force-connect-plate`, `IG-plate-keys`, `IG-keys-documented`, `IG-renamed-keys-lenient`, `IG-time-file-long-name`, `IG-table-header-skipped`: validate `BC-force-connect` on a declared inlet, the documented keys and defaults that must not stop BCB, the keys of older decks, the series file names and the tables with a non-numeric row.
- `SP-wall-305`: validate the choice between the solid-wall records 304 and 305 and the order of the 305 payload.
- `IG-melting`, `IG-pyrolysis`, `IG-ablation`: validate the gas-surface variants `503` (melting), `504` (pyrolysis,
  `pyrolysis-model = HTPB`) and `505` (surface reactions, `surface-reactions = bradley`).
- `IG-chimera+connection`, `IG-force-chimera`: validate chimera next to standard connections on a distorted 3-block
  layout, and `BC-force-chimera` on a partial interface (only the facelets that see the other block become chimera).
- `IG-extrapolated-time-file`, `IG-xtheta-variable-T`, `IG-y-variable-massflux`: validate time tables interpolated and
  extrapolated, a wall temperature table in x and θ, and a mass flux that varies along y.
- `NO_IG-1D`: validate a 1-D case without an ideal-gas phase.

### GPB Cases (`test/GPB/`)

GPB tests check that phase-property builders generate physically consistent tables for different thermodynamic models.

- `IG-fixgas`, `IG-party`: validate fixed ideal-gas workflows.
- `IG-reactive`, `IG-ceafile-reactive-*`: validate reactive chemistry table generation from CEA/case inputs.
- `IG-ceafile-frozen-mixing-HG`, `IG-mixture-HG`: validate heavy-gas and mixing assumptions.
- `IG-ct-equilibrium`, `IG-ct-equilibrium-inerts`, `*-cantera`: validate Cantera-backed equilibrium/property paths (the equilibrium phase with inert mixing and added species).
- `RF-*`: validate real-fluid table generation (e.g., water, CO2).
- `CP-*`, `SP-*`: validate condensed and solid phase-property workflows.

#### The FLINT contract (`database-flint-contract`)

The test keeps `database/chemistry` consistent with the mechanism contract that FLINT publishes, without needing FLINT:
it reads a byte-for-byte copy of FLINT's `src/lib/Lib_ChemMech/mechanism_contract.json`,
`test/tools/flint_mechanism_contract.json`; the FLINT commit it comes from is in
`test/tools/flint_mechanism_contract.source`. Every yaml whose phase name FLINT hooks to a compiled routine must match
that routine (species by composition and name, reaction counts per table type, and for a generated routine the
reactions one by one); one phase name has one content; names with blanks are flagged; a file whose description starts
with `BROKEN:` is skipped. For `Frolov`, whose routine ignores the tables, the yaml rate at seven (T, p) points must equal
the routine's law (`test/tools/flint_rate_points.json`); the Chebyshev backward step of `Nassini_Montanari_Grossi.yaml`
must equal the thesis closure within 1.1e-4 on 200–6000 K. The hooks are pinned with `--expect FILE=ROUTINE` in
`test/CMakeLists.txt`, so a renamed file fails.

At every update of the FLINT version, copy `mechanism_contract.json` of the new FLINT commit over
`test/tools/flint_mechanism_contract.json`, write that commit in `flint_mechanism_contract.source` and re-run the test;
when a hook changes, update the `--expect` list.

### ICB Cases (`test/ICB/`)

ICB tests check that initial-condition fields are built correctly on different grids and initialization strategies.

- `IG-1D`, `IG-2D`: validate baseline dimensional initialization.
- `IG-nozzle2D`, `IG-nozzle3D`: validate nozzle-specific initialization workflows.
- `IG-interp-*`: validate interpolation-based field initialization: `IG-interp-mindist` (distance law on a real MOSE dump),
  the `index` law from a pure-2D source onto pure-2D and revolved 3D targets, from a 3D source and from a source with a
  turbulence band (`IG-interp-2D`, `IG-interp-2Dto3D`, `IG-interp-3D`, `IG-interp-rans-src`), and the revolved source of
  `interpolation-law = extrude` (`IG-interp-extrude`); the species/decomposition folders are not registered.
- `IG-multizone`: validate multi-zone initialization logic.
- `IG-interp-species`, `IG-interp-species-decomposition`: interpolation of a multi-species field, with and without
  the decomposition of the species (not registered).
- `IG+CD`, `IG+SP`, `SP-basic`, `RF-basic`: validate coupled gas/condensed/solid/real-fluid IC outputs.

### KAnT Cases (`test/KAnT/`)

KAnT tests check chemistry-analysis workflows produce expected trends and outputs for canonical kinetics studies.
`equilibrium` is registered (`KAnT-equilibrium`), and so is the ignition deck of the tutorial
(`tutorial-kant-ignition`) and the JLR ignition deck (`KAnT-ignition-JLR`); the others are run by hand with `ATLAS KAnT` in a copy of their folder. Cantera
integrates them, so `KAnT-out.dat` is compared to a tolerance: `1e-5` for the flame temperatures, a relative `5e-2`
for the ignition delays (`numdiff.awk -v rel=1`: an absolute tolerance would let any delay of a few microseconds
through). A delay is the first state past T0 + 300 K of those KAnT stores, one every ten steps of the integrator, and
another Cantera build takes other steps: storing every step moves the delays by up to 1.2 %. Both tests need Cantera,
and the CI jobs without the conda environment leave out the labels `GPB` and `KAnT`.

- `equilibrium`: validate equilibrium-state computations.
- `ignition_delay`, `ignition_delay_exp`: validate ignition-delay predictions and experiment-style setup handling.
- `time_evolution`: validate transient 0D species/temperature evolution workflows.
- `counterflow`: validate counterflow chemistry/flame workflow setup.

### MDB Cases (`test/MDB/`)

MDB tests check that a mesh and its BC data are split consistently across parallel partitions.

- `split-longest`, `block-directions`: validate the choice of split direction.
- `grid-p3d-3D`: validate a 3D grid given to MDB as a PLOT3D file (read as 3D: the products of the same grid in Tecplot).
- `balance-only`: validate load balancing when no split is required.
- `halo-trade`: validate halo/ghost bookkeeping between partitions.
- `mg3-granularity`: validate partition sizing under multigrid constraints.
- `split-solution`: validate splitting a case that also carries a solution field.
- `coupled-phases`: validate cross-phase (`103`) donor remapping when two phases are cut at different indices.
- `dispersed-populations`: validate the dispersed-phase BC file: the boundary table repeated once per (material,
  population) pair, and no property line under a dispersed wall or symmetry.

Every MDB case checks three things:

- **`scripts/check-split.py`**: the split grid against the grid it came from: block dimensions match the map, cells
  are conserved and claimed exactly once, and every nodal and cell-centred value equals its parent's;
- **`scripts/check-bc.py`**: the split BC file on its own terms: every boundary cell present the same number of
  times, every connection record reciprocal (a dispersed-phase file needs `--dispersed`, which selects the
  property-line convention BCB wrote it with);
- **`diff` against `reference/`**: the decomposition map and the BC files, which pin the cut placement, the block
  numbering and the canonical record order.

The meshes are small uniform boxes: what is under test is the decomposition, not the geometry. The binary
(`.szplt`) grid path is not covered: it shares all of its splitting code with the ASCII path and differs only in the
ORION reader and writer.

### STB Cases (`test/STB/`)

STB tests check source-term field generation.

- `uniform`: validate constant source-term generation.
- `x-variable`: validate spatially varying source terms.
- `qvol-direction-combined`: validate a combined `direction` of a qvol profile (read along its first letter, with a warning).
- `qvol-3D-conservative`: validate the conservative remap of a 3D field (`qvol-file` without `direction`), its density form, the `fraction` rule, and the refusals.
- `area-any-order`: validate an area profile given in any row order.

### Tutorial Cases (`test/tutorials/`)

Every page of the [Tutorials](../tutorials/index.md) copies the files of a case of the suite and runs a tool on
them. A page that runs a case as it is relies on that case's test; a page that writes an INI of its own finds it in
`test/tutorials/<page>/`, and shows it from there (a snippet include), so the INI on the page is the one the test
runs. Those tests copy the files of the case the page names into `_run-tutorial/` and run the tool there, as the
reader does. All of them carry the label `tutorial`.

Large tables and fields are compared on a sample: `test/sample_rows.awk` keeps the header lines (with the zone sizes)
and one numeric line in 250 (a temperature step of 250 K in the GPB tables), or in 97 for a field, a step that cannot
follow the mesh. The reference holds the same sample of the reference run, a few kB where the whole would be several MB.

## Running The Registered Regression Set

```bash
cd build
ctest --output-on-failure
```

The cases of the tutorials only:

```bash
cd build
ctest -L tutorial
```

To run one specific test objective only:

```bash
cd build
ctest -R IG-nozzle3D --output-on-failure
```

---

See also [Project Structure](./structure.md) and [Build Instructions](./build.md).

## The standard of a registered test

Each registered test is one case folder under `test/<TOOL>/` and one `add_test` in `test/CMakeLists.txt`, of one
of two kinds:

1. **Golden**: the tool runs on a fixture and the product is compared with `reference/` (`diff` for exact
   products, `test/numdiff.awk` at `tol = 1e-12` for interpolated fields and computed records, `1e-6` for
   the chimera cases). The reference is either an independent oracle (a closed form, a hand-written record,
   the product of another tool or of another deck by symmetry) or, when no oracle exists, the tool's own
   product pinned as a regression witness; the registration comment says which.
2. **Negative**: the tool must stop with a non-zero status, print a named diagnostic and write no product.

A test is added for a corrected defect (it fails before the correction), for an added or repaired function
(one positive case) and for a kept refusal (one representative case per kind of refusal). Fixtures are
small (a few cells, a few KB). The upstream tests are kept as they are.
