# Chemistry Databases

ATLAS bundles a large number of reaction mechanisms for combustion and reacting flows, all stored as Cantera-compatible YAML files. The collection spans hydrogen/oxygen, methane/oxygen (detailed, skeletal, and global), kerosene/RP-1, hybrid-rocket fuels, and SRM plume chemistry.

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

    TSR Family (on request) · Zhukov-Kong · CORIA-CNRS · Smooke

-   **CH₄/O₂ — Global**

    ---

    Jones-Lindsted (with/without Recombinations) · Westbrook-Dryer · Andersen

-   **C₁–C₄ Hydrocarbons**

    ---

    Aramco 2.0/3.0 · USC Mech II · San Diego · GRI-Mech 3.0 · ZhukovC1C4 · FFCM-1/2

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

All the mechanisms are files of `database/chemistry/`, except **GRI-Mech 3.0**: the Cantera that ATLAS employs ships it as `gri30.yaml`, so ATLAS does not carry a copy. It is used like the others, by name (`reactions = gri30`).

---

## Using a mechanism

`reactions =` (or `phase =`) in a GPB gas section takes the **name of the yaml file**, without `.yaml`; it may differ from
the phase name inside the file (`WD-andersen.yaml` holds the phase `WD-Andersen`). KAnT takes the same names.

!!! note "FLINT"
    GPB builds from a mechanism the input files of [FLINT](https://MarcoGrossi92.github.io/FLINT/), the
    thermochemistry library of the solvers: `chemistry-info.txt` and the rate tables, described in
    [GPB output files](../../user-guide/gpb/output.md).

---
