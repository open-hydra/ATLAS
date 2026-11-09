# Mechanism Catalog

<figure>
  --8<-- "docs/databases/chemistry/mechs.svg"
  <figcaption>Species and reactions of every mechanism of the database.</figcaption>
</figure>

Every mechanism is a Cantera YAML file of `database/chemistry/`: Cantera and KAnT read it directly, and GPB builds from it the chemistry tables of a gas phase, which are also the input files of the [FLINT](https://MarcoGrossi92.github.io/FLINT/) library.

---

## H₂/O₂ Mechanisms

### Mevel 2017

A detailed H₂/O₂/N₂ reaction mechanism with 14 species and 42 reactions, valid from 200 to 6000 K. Includes NO formation chemistry and a sub-mechanism for excited hydroxyl radicals (OH\*), enabling OH\* chemiluminescence predictions. Developed at the Explosion Dynamics Laboratory for high-temperature hydrogen-air ignition and detonation studies.

- **Developer**: R. Mével, J.E. Shepherd — California Institute of Technology (Caltech)
- **File**: `Mevel2017.yaml`
- **Species / Reactions**: 14 / 42
- **Primary fuels**: H₂/air

> J. Melguizo-Gavilanes, L.R. Boeck, R. Mével, J.E. Shepherd, "Hot surface ignition of stoichiometric hydrogen-air mixtures," *Int. J. Hydrogen Energy*, 42(11):7393–7403, 2017. DOI: [10.1016/j.ijhydene.2016.05.095](https://doi.org/10.1016/j.ijhydene.2016.05.095).

### Jachimowski-7

A reduced H₂/O₂ mechanism with 7 species (H₂, O₂, H₂O, H, O, OH, N₂) derived from the full Jachimowski hydrogen-air mechanism originally developed for scramjet and hypersonic combustion applications at NASA Langley.

- **Developer**: C.J. Jachimowski — NASA Langley Research Center
- **File**: `Jachimowski-7.yaml`
- **Species / Reactions**: 7 / 7
- **Primary fuels**: H₂/air (scramjet/hypersonic)

> C.J. Jachimowski, "An Analytical Study of the Hydrogen-Air Reaction Mechanism with Application to Scramjet Combustion," NASA TP-2791, 1988.

### ONERA-7

A reduced H₂/O₂ mechanism with 7 species developed for supersonic combustion applications. Two variants are provided: an irreversible formulation with 14 unidirectional reactions (`ONERA-7.yaml`) and a reversible formulation with 7 bidirectional reactions (`ONERA-7_rev.yaml`).

- **Developer**: ONERA (Office National d'Études et de Recherches Aérospatiales), France
- **Files**: `ONERA-7.yaml` (14 irreversible, phase `ONERA-7`), `ONERA-7_rev.yaml` (7 reversible, phase `ONERA-7-rev`)
- **Thermodynamics**: `ONERA-7.yaml` = the records of the Burcat database (2016 edition); with `thermo = NASA7` GPB replaces OH (dHf 39.35 instead of 37.30 kJ/mol): use `Burcat` or `NASA9`
- **Species / Reactions**: 7 / 14 (`ONERA-7.yaml`), 7 / 7 (`ONERA-7_rev.yaml`)
- **Primary fuels**: H₂/air (scramjet)

> Davidenko, Gökalp, Dufour, Magre, AIAA Paper 2006-7913, 2006, Table A.1. DOI: [10.2514/6.2006-7913](https://doi.org/10.2514/6.2006-7913).
>
> Davidenko, Gökalp, Kudryavtsev, West-East High Speed Flow Field Conference, 2007 (the same model for H₂–O₂ rotating detonation).

### Gerlinger-9

A reduced H₂/air mechanism (a modified Jachimowski 1988 model) with 9 species and 19 reactions.

- **File**: `Gerlinger-9.yaml` (phase `Gerlinger-9`)
- **Species / Reactions**: 9 / 19
- **Primary fuels**: H₂/air

> Gerlinger, Möbus, Brüggemann, *J. Comput. Phys.*, 167:247–276, 2001. DOI: [10.1006/jcph.2000.6671](https://doi.org/10.1006/jcph.2000.6671).

### Nassini

A global single-step mechanism for H₂/air detonation with 4 species (O₂, H₂ONassini, H₂, N₂; the water is named `H₂ONassini` because its enthalpy of formation is the thesis value, −230.66 kJ/mol, and must not be replaced by the thermo database: deck composition keys are `yH2ONassini`). Calibrated to match the Chapman-Jouguet (CJ) speed, von Neumann state, and half-reaction thickness across a wide equivalence ratio range (φ = 0–5) at atmospheric preshock conditions. The H₂O formation enthalpy is modified to reproduce CJ detonation speed. The **Original** version is from Nassini's PhD thesis; the **Montanari-Grossi** version features adjusted parameters.

- **Developer**: P.C. Nassini — University of Florence; A. Montanari, M. Grossi (modified variant)
- **Files**: `Nassini_Original.yaml`, `Nassini_Montanari_Grossi.yaml`
- **Thermodynamics**: of both files = the NASA9 records of `database/thermo/nasa9.yaml` (Glenn base + Δa7 = 1343 K for the water), the same records GPB uses with `thermo = NASA9`
- **Montanari-Grossi backward step**: the exact thesis closure k_b = k_f·sqrt(p0/RT)/K_c (p0 = 1 bar) with K_c in Cantera's convention (species reference pressure 1 atm, no `reference-pressure` key in the yaml; a K_c referred to 1 bar would lower k_b by 0.66 %), written as a single-pressure-column Chebyshev rate (the first Chebyshev reaction of the database; tabulated by GPB as an Arrhenius zone, error ≤ 1.1e-4 on 200–6000 K): valid with `thermo = NASA9` only
- **Species / Reactions**: 4 / 2
- **Primary fuels**: H₂/air (detonation)

> P.C. Nassini, "High-fidelity Numerical Investigations of a Hydrogen Rotating Detonation Combustor," PhD thesis, University of Florence (DIEF), XXXIV cycle, 2018–2021. The Original model: Chapter 2 (Eqs. 2.36–2.39, Table 2.7).

> P.C. Nassini, A. Andreini, M.D. Bohon, "Characterization of refill region and mixing state immediately ahead of a hydrogen-air rotating detonation using LES," *Combust. Flame*, 258:113050, 2023. DOI: [10.1016/j.combustflame.2023.113050](https://doi.org/10.1016/j.combustflame.2023.113050).

### Frolov

A global single-step mechanism for H₂/air combustion with 4 species (H₂, O₂, H₂O, N₂) and 1 reversible reaction (backward rate from the equilibrium constant), in the variant of the CFD++ reaction panel: no pressure factor, A = 8·10¹¹ on the reaction progress rate. Designed for detonation simulations requiring a computationally efficient chemical model.

- **Developer**: S.M. Frolov — Semenov Federal Research Center for Chemical Physics, Moscow
- **File**: `Frolov_nopressure.yaml` (phase `Frolov_nopressure`)
- **Note**: as a consequence of its source, `Frolov_nopressure` runs twice the rate of the published Frolov formula at 1 atm, with the standard H₂O (no calibrated heat effect)
- **File**: `Frolov.yaml` (phase `Frolov`): the formula published by Frolov et al. (irreversible, p^−1.15 pressure factor), written as a two-point PLOG for Cantera/KAnT; the species `H2OFrolov` carries the heat release calibrated on the CJ speed (1970 m/s, frozen products)
- **Species / Reactions**: 4 / 1
- **Primary fuels**: H₂/air (detonation)

> Frolov, Dubrovskii, Ivanov, *Progress in Propulsion Physics*, 4:467–488, 2013, Eq. (11), p. 474. DOI: [10.1051/eucass/201304467](https://doi.org/10.1051/eucass/201304467).

---

## CH₄/O₂ Mechanisms — Detailed

### ZhukovC1C4

A detailed C₁–C₄ chemical kinetic mechanism with 207 species and 2176 reactions for the oxidation of light alkanes at high pressures and temperatures. Originally developed for methane/oxygen combustion under rocket engine conditions. Serves as the parent detailed mechanism from which the ZK skeletal model and the TSR-derived mechanisms have been generated.

- **Developer**: V.P. Zhukov — German Aerospace Center (DLR), Institute of Space Propulsion, Lampoldshausen
- **File**: `ZhukovC1C4.yaml`
- **Species / Reactions**: 207 / 2176
- **Primary fuels**: CH₄/O₂ and C₁–C₄ hydrocarbons (high-pressure rocket propulsion)

> V.P. Zhukov, A.F. Kong, "A compact reaction mechanism of methane oxidation at high pressures," *Prog. React. Kinet. Mech.*, 43(1):62–78, 2018. DOI: [10.3184/146867818X15066862094914](https://doi.org/10.3184/146867818X15066862094914).

### Foundational Fuel Chemistry Models (FFCM)

Detailed chemical kinetic reaction models developed through a collaboration between Hai Wang's research group at Stanford University and Gregory Smith of SRI International, employing up-to-date kinetic knowledge with well-defined predictive uncertainties. FFCM-2 extends FFCM-1 to cover a wider range of C₀–C₄ fuels.

- **FFCM-1**
  - **File**: `FFCM1.yaml`
  - **Species / Reactions**: 38 / 291
  - **Pressure range**: Atmospheric to 50 atm
  - **Primary fuels**: H₂, H₂/CO, CH₂O, CH₄

- **FFCM-2**
  - **File**: `FFCM2.yaml`
  - **Species / Reactions**: 96 / 1054
  - **Pressure range**: Atmospheric to 50 atm
  - **Primary fuels**: C₀–C₄ fuels
- **GPB**: both files contain falloff-SRI reactions, which the GPB tables cannot carry: GPB refuses them; usable in Cantera and KAnT

- **FFCMy-12**
  - **File**: `FFCMy_12.yaml` (phase `FFCMy-12`, from the previous ATLAS repository)
  - **Species / Reactions**: 13 / 38 (no falloff-SRI)
  - **Reference**: Xu et al., *Combust. Flame*, 263:113380, 2024 (derived from an early version, FFCMy, of FFCM-2). DOI: [10.1016/j.combustflame.2024.113380](https://doi.org/10.1016/j.combustflame.2024.113380)

> https://web.stanford.edu/group/haiwanglab/FFCM1/
>
> https://web.stanford.edu/group/haiwanglab/FFCM2/

### DTU Mechanism

A detailed chemical kinetic model for methane oxidation under high-pressure conditions (up to 100 atm), developed at the Technical University of Denmark.

- **Developer**: Technical University of Denmark
- **File**: `dtu.yaml`
- **Species / Reactions**: 68 / 631
- **Primary fuels**: CH₄

> H. Hashemi, J.M. Christensen, S. Gersen, H. Levinsky, S.J. Klippenstein, P. Glarborg, "High-Pressure Oxidation of Methane," *Combust. Flame*, 172:349–364, 2016. DOI: [10.1016/j.combustflame.2016.07.016](https://doi.org/10.1016/j.combustflame.2016.07.016).

---

## CH₄/O₂ Mechanisms — Reduced / Skeletal

### TSR Mechanisms (Family)

A family of skeletal mechanisms for methane–oxygen combustion at high pressure, generated via Tangential Stretching Rate (TSR) analysis combined with CSP-based reduction. Starting from the detailed ZhukovC1C4 mechanism (207 species), the reduction targets specific canonical configurations.

!!! warning "Available on request"
    The TSR mechanisms are not distributed with ATLAS. Request them from the authors of the paper cited below
    (J. Liberatori, R. Malpica Galassi, D. Bianchi, F. Nasuti, M. Valorani, P.P. Ciottoli). Once obtained, put their
    YAML files in `database/chemistry/external/`, whose content git ignores: GPB, KAnT and the GUI then find them like
    the other mechanisms (`reactions = TSR-GP-24`). Without the files, GPB cannot find the mechanism.

| Mechanism | File | Species | Reactions | Canonical Target |
|---|---|---:|---:|---|
| TSR-Rich-39 | `TSR-Rich-39.yaml` | 39 | 398 | Rich conditions (extended C₃–C₄) |
| TSR-Rich-31 | `TSR-Rich-31.yaml` | 31 | 197 | Rich conditions (C₃–C₄) |
| TSR-GP-24 | `TSR-GP-24.yaml` | 24 | 110 | General Purpose |
| TSR-CDF-13 | `TSR-CDF-13.yaml` | 13 | 46 | Counterflow Diffusion Flame |
| TSR-PSR-11 | `TSR-PSR-11.yaml` | 11 | 22 | Perfectly Stirred Reactor |

- **Developer**: M. Valorani, R. Malpica Galassi, P.P. Ciottoli, P.E. Lapenna, F. Creta — Sapienza University of Rome

> J. Liberatori, R. Malpica Galassi, D. Bianchi, F. Nasuti, M. Valorani, P.P. Ciottoli, "Family of Skeletal Reaction Mechanisms for Methane–Oxygen Combustion in Rocket Propulsion," *J. Propul. Power*, 40(2):303–319, 2024. DOI: [10.2514/1.B39283](https://doi.org/10.2514/1.B39283).

### Zhukov-Kong (ZK) Mechanism

A skeletal methane kinetic mechanism for undiluted methane–oxygen mixtures at high pressures. Obtained by eliminating unimportant species and reactions from the detailed Zhukov (2009) alkane oxidation mechanism.

- **Developer**: V.P. Zhukov, A.F. Kong — DLR, Institute of Space Propulsion
- **File**: `ZK.yaml`
- **Species / Reactions**: 25 / 51
- **Primary fuels**: CH₄ (rocket engine conditions)

> V.P. Zhukov, A.F. Kong, "A compact reaction mechanism of methane oxidation at high pressures," *Prog. React. Kinet. Mech.*, 43(1):62–78, 2018.

### CORIA-CNRS Mechanism

A RAMEC-based reduced mechanism validated for auto-ignition delay, laminar premixed flame, and counterflow diffusion flame over a very large range of pressure (1 atm to 100 bar) and equivalence ratio (0.2 to 14).

- **Developer**: CORIA – CNRS, Normandie Université
- **File**: `coria.yaml`
- **Species / Reactions**: 17 / 44
- **Primary fuels**: CH₄

> F. Monnier, G. Ribert, "Simulation of high-pressure methane-oxygen combustion with a new reduced chemical mechanism," *Combust. Flame*, 235:111735, 2022.

### Smooke Mechanism

A reduced kinetic mechanism for methane-air flames.

- **File**: `smooke.yaml`
- **Species / Reactions**: 16 / 35
- **Primary fuels**: CH₄

> M.D. Smooke, ed., *Reduced Kinetic Mechanisms and Asymptotic Approximations for Methane-Air Flames: A Topical Volume*. Berlin: Springer-Verlag, 1991.

---

## CH₄/O₂ Mechanisms — Global

### Jones-Lindstedt (JL) Mechanism

A classic global reaction mechanism for methane-air combustion. The four global steps represent: (1) fuel breakdown to CO and H₂, (2) H₂ oxidation, (3) CO oxidation via the water-gas shift, and (4) CO₂ dissociation.

- **Developer**: W.P. Jones, R.P. Lindstedt — Imperial College London
- **File**: `JL.yaml`
- **Species / Reactions**: 6 / 4
- **Primary fuels**: CH₄

> W.P. Jones, R.P. Lindstedt, "Global reaction schemes for hydrocarbon combustion," *Combust. Flame*, 73(3):233–249, 1988. DOI: [10.1016/0010-2180(88)90021-1](https://doi.org/10.1016/0010-2180(88)90021-1).

### JLR (Jones-Lindstedt with Recombinations) Mechanisms

The Jones-Lindstedt scheme extended with the radicals H, O, OH and their recombination and dissociation steps, for the high temperatures of rocket chambers: 9 species and 6–7 reactions. Two variants: **Frassoldati** (rates from the CRECK Modeling Group, Politecnico di Milano) and **Nasuti** (rates adapted for rocket propulsion at Sapienza).

- **Files**: `JLR-frassoldati.yaml`, `JLR-nasuti.yaml`, and their Cantera forms for KAnT, `JLR-frassoldati-ct.yaml` and `JLR-nasuti-ct.yaml` (KAnT reads them for `reactions = JLR-…`; their description says how they are built)
- **Species / Reactions**: 9 / 6–7 (7–8 in the Cantera forms)
- **Primary fuels**: CH₄/O₂ (rocket propulsion)

> W.P. Jones, R.P. Lindstedt, "Global reaction schemes for hydrocarbon combustion," *Combust. Flame*, 73(3):233–249, 1988.
>
> B. Betti, D. Bianchi, F. Nasuti, E. Martelli, "Chemical reaction effects on heat loads of CH₄/O₂ and H₂/O₂ rockets," *AIAA J.*, 54(5):1693–1703, 2016. DOI: [10.2514/1.J054606](https://doi.org/10.2514/1.J054606).

### Westbrook-Dryer (WD) Global Mechanism

A simplified global kinetic model for hydrocarbon combustion with 5 species and 3 reactions. The **WD-Andersen** variant (Andersen, Rasmussen, Giselsson, Glarborg, *Energy & Fuels* 23 (2009) 1379) uses modified rate parameters and writes the CO2 dissociation step as the explicit inverse of the CO oxidation step, rate = k3 [CO2] [H2O]^0.5 [O2]^-0.25 (yaml `orders` with `negative-orders` and `nonreactant-orders`), so that the two steps reach the CO + 0.5 O2 <=> CO2 equilibrium; at zero O2 concentration the rate of that step is zero (Cantera's convention).

- **Developer**: C.K. Westbrook, F.L. Dryer — Lawrence Livermore National Lab / Princeton University
- **Files**: `WD.yaml`, `WD-andersen.yaml`
- **Species / Reactions**: 5 / 3
- **Primary fuels**: CH₄

> C.K. Westbrook, F.L. Dryer, "Chemical Kinetic Modeling of Hydrocarbon Combustion," *Prog. Energy Combust. Sci.*, 10(1):1–57, 1984.

> J. Andersen, C.L. Rasmussen, T. Giselsson, P. Glarborg, "Global Combustion Mechanisms for Use in CFD Modeling under Oxy-Fuel Conditions," *Energy & Fuels*, 23(3):1379–1389, 2009. DOI: [10.1021/ef8003619](https://doi.org/10.1021/ef8003619) (the WD-Andersen variant).

---

## C₁–C₄ Hydrocarbon Mechanisms

### Aramco Mechanisms

Detailed chemical kinetic mechanisms developed at NUI Galway for modeling the combustion of C₁–C₄ hydrocarbon fuels.

- **Aramco 2.0**
  - **File**: `aramco20.yaml`
  - **Species / Reactions**: 493 / 2716
  - **Pressure range**: 1 to 100 atm

- **Aramco 3.0**
  - **File**: `aramco30.yaml`
  - **Species / Reactions**: 581 / 3037
  - **Pressure range**: 1 to 100 atm

> Y. Li, C-W. Zhou, K.P. Somers, K. Zhang, H.J. Curran, "The Oxidation of 2-Butene: A High Pressure Ignition Delay, Kinetic Modeling Study and Reactivity Comparison with Isobutene and 1-Butene," *Proc. Combust. Inst.*, 36(1):403–411, 2017.
>
> C-W. Zhou, Y. Li, U. Burke, C. Banyon, K.P. Somers, S. Khan, J.W. Hargis, T. Sikes, E.L. Petersen, M. AlAbbad, A. Farooq, Y. Pan, Y. Zhang, Z. Huang, J. Lopez, Z. Loparo, S.S. Vasu, H.J. Curran, "An experimental and chemical kinetic modeling study of 1,3-butadiene combustion: Ignition delay time and laminar flame speed measurements," *Combust. Flame*, 197:423–438, 2018.

### USC Mech II

A detailed chemical kinetic mechanism for the combustion of H₂/CO/C₁–C₄ compounds.

- **Developer**: University of Southern California
- **File**: `USCII.yaml`
- **Species / Reactions**: 111 / 784
- **Pressure range**: 1–50 atm
- **Primary fuels**: H₂, CO, CH₄, C₂H₆, C₃H₈, C₄H₁₀

> H. Wang, X. You, A.V. Joshi, S.G. Davis, A. Laskin, F. Egolfopoulos, C.K. Law, "USC Mech Version II. High-Temperature Combustion Reaction Model of H₂/CO/C₁-C₄ Compounds," http://ignis.usc.edu/USC_Mech_II.htm, May 2007.

### UCSD Mechanism

A detailed reaction model for the combustion of hydrocarbon fuels, developed at the Combustion Research Group of UC San Diego.

- **Developer**: University of California San Diego
- **File**: `UCSD.yaml`
- **Species / Reactions**: 57 / 268
- **Primary fuels**: H₂, CO, CH₄, C₂H₆, C₃H₈, C₄H₁₀

> "Chemical-Kinetic Mechanisms for Combustion Applications," San Diego Mechanism web page, University of California at San Diego. http://combustion.ucsd.edu

### GRI-Mech 3.0

A widely used optimized mechanism for natural gas combustion, including NO formation and reburn chemistry. Valid for 1000–2500 K, 10 Torr to 10 atm and equivalence ratios 0.1–5 in premixed systems.

- **Developer**: Gas Research Institute (GRI-Mech project: Smith, Golden, Frenklach and others)
- **File**: `gri30.yaml`, **not in `database/chemistry/`**: Cantera ships it, and ATLAS uses that Cantera, so it is read by name like any other mechanism of the database (`reactions = gri30`, `phase = gri30` in GPB; `reactions = gri30` in KAnT)
- **Species / Reactions**: 53 / 325
- **Primary fuels**: CH₄, with C₂H₆ and C₃H₈ as minor components

> G.P. Smith, D.M. Golden, M. Frenklach, N.W. Moriarty, B. Eiteneer, M. Goldenberg, C.T. Bowman, R.K. Hanson, S. Song, W.C. Gardiner Jr., V.V. Lissianski, Z. Qin, GRI-Mech 3.0, http://combustion.berkeley.edu/gri-mech/version30/text30.html, 1999.

---

## Kerosene / RP-1 Mechanisms

### Zettervall

A reduced chemical kinetic mechanism for kerosene-air combustion using C₁₂H₂₃ as a surrogate fuel. Developed with a modular approach, it reproduces key flame parameters (laminar flame speed, ignition delay time, flame structure) while remaining compact enough for LES and DNS.

- **Developer**: N. Zettervall, C. Fureby (FOI / Lund University), E.J.K. Nilsson (Lund University)
- **File**: `Zettervall.yaml`
- **Species / Reactions**: 33 / 77
- **Primary fuels**: Kerosene (C₁₂H₂₃ surrogate)

> N. Zettervall, C. Fureby, E.J.K. Nilsson, "A reduced chemical kinetic reaction mechanism for kerosene-air combustion," *Fuel*, 269:117446, 2020. DOI: [10.1016/j.fuel.2020.117446](https://doi.org/10.1016/j.fuel.2020.117446).

### CKJLR-10sp

A 10-species global mechanism for RP-1 (kerosene surrogate, modeled as C₂H₄) with 8 reactions. Extends the JLR framework by introducing RP-1 as a surrogate fuel species, with ethylene as the primary cracking product. Uses NASA-9 polynomial thermodynamics.

- **Developer**: G. Passarani — Sapienza University of Rome
- **File**: `CKJLR-10sp.yaml`
- **Species / Reactions**: 10 / 8
- **Primary fuels**: RP-1/LOX

> Based on the JLR framework. See: B. Betti, D. Bianchi, F. Nasuti, E. Martelli, "Chemical reaction effects on heat loads of CH₄/O₂ and H₂/O₂ rockets," *AIAA J.*, 54(5):1693–1703, 2016. DOI: [10.2514/1.J054606](https://doi.org/10.2514/1.J054606).

---

## Hybrid Rocket Mechanisms (HTPB / Paraffin)

### Ciottoli20

A 20-species skeletal mechanism with 104 reactions for GOX/HTPB hybrid rocket propulsion. Derived from the detailed n-heptane mechanism of Curran, Pitz, and Westbrook (LLNL) using Computational Singular Perturbation (CSP) analysis. Retains key species necessary to describe butadiene oxidation pathways in non-premixed configurations.

- **Developer**: P.P. Ciottoli, R. Malpica Galassi, P.E. Lapenna, G. Leccese, D. Bianchi, F. Nasuti, F. Creta, M. Valorani — Sapienza University of Rome
- **File**: `ciottoli20.yaml`
- **Species / Reactions**: 20 / 104
- **Primary fuels**: C₄H₆/GOX (HTPB hybrid rocket)

> P.P. Ciottoli, R. Malpica Galassi, P.E. Lapenna, G. Leccese, D. Bianchi, F. Nasuti, F. Creta, M. Valorani, "CSP-based chemical kinetics mechanisms simplification strategy for non-premixed combustion: An application to hybrid rocket propulsion," *Combust. Flame*, 186:83–93, 2017. DOI: [10.1016/j.combustflame.2017.07.035](https://doi.org/10.1016/j.combustflame.2017.07.035).

### CoronettiC4H6

A global mechanism for 1,3-butadiene (C₄H₆) combustion with 9 species and 6 reactions. C₄H₆ is the primary pyrolysis product of HTPB, the most common solid fuel in hybrid rocket motors.

- **Developer**: A. Coronetti, W.A. Sirignano — University of California, Irvine
- **File**: `CoronettiC4H6.yaml`
- **Species / Reactions**: 9 / 6
- **Primary fuels**: C₄H₆ (HTPB pyrolysis product)

> A. Coronetti, W.A. Sirignano, "Numerical Analysis of Hybrid Rocket Combustion," *J. Propul. Power*, 29(2):371–384, 2013. DOI: [10.2514/1.B34760](https://doi.org/10.2514/1.B34760).

### Singh-WC32

A global mechanism for dotriacontane (C₃₂H₆₆) combustion with 10 species and 11 reactions. C₃₂H₆₆ is used as a surrogate for paraffin wax, a liquefying solid fuel for hybrid rocket motors. Models wax cracking to ethylene followed by oxidation through the JLR-type pathway.

- **Developer**: D. Bianchi, F. Nasuti, M.T. Migliorino — Sapienza University of Rome
- **File**: `Singh-WC32.yaml`
- **Species / Reactions**: 10 / 11
- **Primary fuels**: C₃₂H₆₆/GOX (paraffin wax hybrid rocket)

> M.T. Migliorino, D. Bianchi, F. Nasuti, "Numerical Analysis of Paraffin-Wax/Oxygen Hybrid Rocket Engines," *J. Propul. Power*, 36(6):806–819, 2020. DOI: [10.2514/1.B37914](https://doi.org/10.2514/1.B37914).

---

## Chlorine / SRM Plume Mechanisms

### Pelucchi

A detailed chlorine chemistry mechanism covering the high-temperature chemistry of HCl and Cl₂. Thermochemistry obtained using the Active Thermochemical Tables (ATcT) approach. The reaction subset is coupled with the POLIMI syngas/CO mechanism.

- **Developer**: M. Pelucchi, A. Frassoldati, T. Faravelli (Politecnico di Milano); B. Ruscic (Argonne National Lab); P. Glarborg (DTU)
- **File**: `pelucchi.yaml`
- **Species / Reactions**: 25 / 103
- **Primary fuels**: HCl/Cl₂ (chlorine inhibition chemistry)

> M. Pelucchi, A. Frassoldati, T. Faravelli, B. Ruscic, P. Glarborg, "High-temperature chemistry of HCl and Cl₂," *Combust. Flame*, 162(6):2693–2704, 2015. DOI: [10.1016/j.combustflame.2015.04.002](https://doi.org/10.1016/j.combustflame.2015.04.002).

### Cross

A mechanism for SRM plume afterburning with 19 species and 33 reactions. Includes hydrocarbons (C₂H₂, CH₂O, CH₃, CH₄), chlorine species (Cl, Cl₂, ClO, HCl), and nitrogen species (HCN, N₂). Uses NASA-9 polynomial thermodynamics.

- **File**: `cross.yaml`
- **Species / Reactions**: 19 / 33
- **Reference**: to be confirmed
- **Primary fuels**: SRM exhaust plume (H₂/CO/HCl/HCN afterburning)

### Ecker

A reduced mechanism for SRM plume afterburning with 14 species and 28 reactions. Includes hydrogen/oxygen combustion chemistry and chlorine species relevant to SRM exhaust containing HCl from ammonium perchlorate decomposition. Thermodynamic data for H/O/C/N from GRI-Mech 3.0; chlorine data from Pelucchi.

- **Developer**: T. Ecker, S. Karl, K. Hannemann — DLR, Göttingen
- **File**: `ecker.yaml`
- **Species / Reactions**: 14 / 28
- **Primary fuels**: SRM exhaust plume

> T. Ecker, S. Karl, K. Hannemann, "Combustion Modeling in Solid Rocket Motor Plumes," *8th European Conference for Aeronautics and Space Sciences (EUCASS)*, Madrid, 2019.

### Troyes

A reduced mechanism for SRM exhaust plume afterburning with 12 species and 17 reactions. Models secondary combustion of H₂, CO, and HCl in the plume region. Thermodynamic data for H/O/C/N from GRI-Mech 3.0; chlorine data from Pelucchi.

- **Developer**: J. Troyes et al. — ONERA, France
- **File**: `troyes.yaml`
- **Species / Reactions**: 12 / 17
- **Primary fuels**: SRM exhaust plume

> J. Troyes, I. Dubois, V. Borie, A. Boischot, "Multi-Phase Reactive Numerical Simulations of a Model Solid Rocket Exhaust Jet," *42nd AIAA/ASME/SAE/ASEE Joint Propulsion Conference & Exhibit*, AIAA 2006-4414, 2006. DOI: [10.2514/6.2006-4414](https://doi.org/10.2514/6.2006-4414).
