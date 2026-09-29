# Chemistry Databases

ATLAS bundles a great number of reaction mechanisms for combustion and reacting flows, all stored as Cantera-compatible YAML files. The collection spans hydrogen/oxygen, methane/oxygen (detailed, skeletal, and global), kerosene/RP-1, hybrid-rocket fuels, and SRM plume chemistry.

---

## Mechanism Groups

<div class="grid cards" markdown>

-   **H₂/O₂**

    ---

    Mevel 2017 · Jachimowski-7 · ONERA-7 · Nassini · Frolov

-   **CH₄/O₂ — Detailed**

    ---

    DTU

-   **CH₄/O₂ — Skeletal**

    ---

    TSR Family · Zhukov-Kong · CORIA-CNRS · Smooke

-   **CH₄/O₂ — Global**

    ---

    Jones-Lindsted (with/without Recombinations) · Westbrook-Dryer · Andersen

-   **C₁–C₄ Hydrocarbons**

    ---

    Aramco 2.0/3.0 · USC Mech II · San Diego · ZhukovC1C4 · FFCM-1/2

-   **Kerosene / RP-1**

    ---

    Zettervall C₁₂H₂₃ · CKJLR-10sp

-   **Hybrid Rocket**

    ---

    Ciottoli20 (HTPB) · Coronetti C₄H₆ · Singh C₃₂H₆₆ (paraffin)

-   **Chlorine / SRM Plume**

    ---

    Pelucchi · Cross · Ecker · Troyes

</div>

---

## Full Mechanism Catalog

See [Mechanisms](list.md) for detailed documentation of every mechanism: developer, file name, species/reaction counts, primary fuel, and bibliographic reference.

---

## Phase names and FLINT

GPB writes the phase name of the yaml on line 1 of `<name>chemistry-info.txt` and the species in the order of the yaml. A solver that evaluates finite-rate chemistry through FLINT uses that name to select a compiled routine; which names FLINT hooks, the species order each routine expects and what it does with names it does not hook are documented by FLINT (`docs/user/chemistry_routines.md` and `src/lib/Lib_ChemMech/mechanism_contract.json` in the FLINT repository). GPB does not depend on that list: it writes the same files whatever the name.

`phase =` and `reactions =` in a GPB section take the **name of the yaml file** (without `.yaml`), which may differ from the phase name inside it: `WD-andersen.yaml` holds the phase `WD-Andersen`, the name the solver sees.

The ctest `database-flint-contract` keeps the database consistent with the contract file that FLINT publishes, without needing FLINT: it reads a byte-for-byte copy of that file, `test/tools/flint_mechanism_contract.json` (the FLINT commit it comes from is in `test/tools/flint_mechanism_contract.source`). Every yaml whose phase name is hooked must match the routine's species slots by composition and name, the number of species and the reaction counts per table type; for a generated routine also its reaction structure, reaction by reaction; one phase name = one structural content; names with blanks are flagged; files whose description starts with `BROKEN:` are skipped. For the one routine that ignores the tables, `Frolov`, the yaml rate constant at seven (T, p) points must equal the routine's law (ATLAS test data, `test/tools/flint_rate_points.json`), and the Chebyshev backward step of `Nassini_Montanari_Grossi.yaml` must equal the thesis closure k_f sqrt(p0/RT)/K_c of its own thermo within 1.1e-4 on 200-6000 K. The hooks are pinned in the ctest registration with `--expect FILE=ROUTINE`, so a renamed file fails. The test needs Cantera and resolves the interpreter as `ATLAS.sh` does: `ATLAS_PYTHON`, else the conda environment `ATLAS_CONDA_ENV` (default `ct-env`), else `python3`.

**At every update of the FLINT version** copy `src/lib/Lib_ChemMech/mechanism_contract.json` of the new FLINT commit over `test/tools/flint_mechanism_contract.json`, write that commit in `flint_mechanism_contract.source` and re-run the test; when a hook changes, update the `--expect` list in `test/CMakeLists.txt`.

### Table conventions read by FLINT

- **Temperature grid**: every table runs from `Tmin` to `Tmax` with a 1 K step (integer kelvin; defaults 1 K and 5000 K). FLINT reads each table at the temperature of its rows.
- **Irreversible falloff reactions**: in `chemistry-Troe.dat` / `chemistry-Lindemann.dat` the column `k_c` is 0 on every row of an irreversible (`=>`) reaction and > 0 on a reversible one; FLINT computes no backward rate when `k_c = 0`. Arrhenius tables carry `k_b = 0` for `=>` reactions as before. FLINT versions older than the one released with this ATLAS version divide by `k_c` (infinite reverse rate): release FLINT first.
- **Reaction orders**: for a phase that FLINT tabulates with its `general` procedure, the explicit `orders:` of the yaml end `chemistry-info.txt` as the optional block `Reaction orders` / `<n>` / `<ir> <species> <order>` (`ir` = index in the `Reaction type` list); older FLINT versions stop reading before it; compiled routines do not read it.
- **Products**: a GPB run stages its files in a new directory `.gpb-tmp-<random>/` and moves them into `fromATLAStoSolver/` only when every phase succeeded; pre-existing files are never removed.

---
