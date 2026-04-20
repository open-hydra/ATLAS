# ATLAS Chemistry Database

This directory contains chemical kinetic mechanisms in Cantera YAML format for use with ATLAS.
All mechanisms include thermodynamic and transport properties.

The Python script `resume.py` generates the species-vs-reactions overview plot (`resume.png`).

---

## Summary Table

| File | Phase Name | Species | Reactions | Fuel / Application |
|---|---|---:|---:|---|
| **H₂/O₂ Mechanisms** | | | | |
| `Mevel2017.yaml` | Mevel | 14 | 42 | H₂/air (detailed, includes OH\*) |
| `Jachimowski-7.yaml` | Jachimowski-7 | 7 | 7 | H₂/air (reduced, scramjet) |
| `ONERA-7.yaml` | ONERA-7 | 7 | 14 | H₂/air (irreversible, scramjet) |
| `ONERA-7_rev.yaml` | ONERA-7 | 7 | 7 | H₂/air (reversible, scramjet) |
| `Nassini_Original.yaml` | Nassini | 4 | 2 | H₂/air (global, detonation) |
| `Nassini_Montanari_Grossi.yaml` | Nassini | 4 | 2 | H₂/air (global, detonation, modified) |
| `Frolov_nopressure.yaml` | Frolov-nopressure | 4 | 1 | H₂/air (global, detonation) |
| **CH₄/O₂ Mechanisms — Detailed** | | | | |
| `ZhukovC1C4.yaml` | ZhukovC1C4 | 207 | 2176 | C₁–C₄ (detailed, high-pressure) |
| `FFCM2.yaml` | FFCM-2 | 96 | 1054 | C₀–C₄ (detailed) |
| `DTU.yaml` | DTU | 68 | 631 | CH₄ (detailed, high-pressure) |
| `FFCM1.yaml` | FFCM-1 | 38 | 291 | CH₄ (detailed) |
| **CH₄/O₂ Mechanisms — Reduced / Skeletal** | | | | |
| `ZK.yaml` | ZK | 25 | 51 | CH₄ (skeletal, rocket) |
| `TSR-Rich-39.yaml` | TSR-Rich-39 | 39 | 398 | CH₄ (skeletal, rich) |
| `TSR-Rich-31.yaml` | TSR-Rich-31 | 31 | 197 | CH₄ (skeletal, rich) |
| `TSR-GP-24.yaml` | TSR-GP-24 | 24 | 110 | CH₄ (skeletal, general purpose) |
| `TSR-CDF-13.yaml` | TSR-CDF-13 | 13 | 46 | CH₄ (skeletal, diffusion flame) |
| `TSR-PSR-11.yaml` | TSR-PSR-11 | 11 | 22 | CH₄ (skeletal, PSR) |
| `coria.yaml` | CORIA-CNRS | 18 | 44 | CH₄ (reduced, high-pressure) |
| `smooke.yaml` | Smooke | 16 | 35 | CH₄ (reduced) |
| **CH₄/O₂ Mechanisms — Global** | | | | |
| `JLR-nasuti.yaml` | JLR-Nasuti | 9 | 7 | CH₄ (global, rocket) |
| `JLR-nasuti-ct.yaml` | JLR-Nasuti | 9 | 8 | CH₄ (global, rocket, Cantera) |
| `JLR-frassoldati.yaml` | JLR-Frassoldati | 9 | 6 | CH₄ (global, rocket) |
| `JLR-frassoldati-ct.yaml` | JLR-Frassoldati | 9 | 7 | CH₄ (global, rocket, Cantera) |
| `JL.yaml` | JL | 6 | 4 | CH₄ (global) |
| `WD.yaml` | WD | 5 | 3 | CH₄ (global) |
| `WD-andersen.yaml` | WD-Andersen | 5 | 3 | CH₄ (global, modified) |
| **C₁–C₄ Hydrocarbon Mechanisms** | | | | |
| `aramco30.yaml` | Aramco 3.0 | 623 | 3037 | C₁–C₄ (detailed) |
| `aramco20.yaml` | Aramco 2.0 | 532 | 2716 | C₁–C₄ (detailed) |
| `USCII.yaml` | USC Mech II | 113 | 784 | H₂/CO/C₁–C₄ (detailed) |
| `UCSD.yaml` | UCSD | 57 | 268 | C₁–C₄ (detailed) |
| **Kerosene / RP-1 Mechanisms** | | | | |
| `Zettervall.yaml` | Zettervall | 33 | 77 | Kerosene C₁₂H₂₃ (reduced) |
| `CKJLR-10sp.yaml` | CKJLR-10sp | 10 | 8 | RP-1 (global, rocket) |
| **Hybrid Rocket Mechanisms (HTPB / Paraffin)** | | | | |
| `ciottoli20.yaml` | Ciottoli20 | 20 | 104 | C₄H₆/GOX (skeletal, HTPB) |
| `CoronettiC4H6.yaml` | CoronettiC4H6 | 9 | 6 | C₄H₆ (global, HTPB) |
| `Singh-WC32.yaml` | Singh-WC32 | 10 | 11 | C₃₂H₆₆ (global, paraffin wax) |
| **Chlorine / SRM Plume Mechanisms** | | | | |
| `pelucchi.yaml` | Pelucchi | 25 | 103 | HCl/Cl₂ (detailed, chlorine) |
| `cross.yaml` | Cross | 20 | 33 | SRM plume (HCl/HCN) |
| `ecker.yaml` | Ecker | 14 | 28 | SRM plume (HCl) |
| `troyes.yaml` | Troyes | 12 | 17 | SRM plume (HCl) |

> **Note:** The `-ct` variants of JLR mechanisms include N₂ in the element list for native Cantera compatibility without altering the chemistry.

---

# H₂/O₂ Mechanisms

## Mevel 2017

A detailed H₂/O₂/N₂ reaction mechanism with 14 species and 42 reactions, valid from 200 to 6000 K. Includes NO formation chemistry and a sub-mechanism for excited hydroxyl radicals (OH\*), enabling OH\* chemiluminescence predictions. Developed at the Explosion Dynamics Laboratory for high-temperature hydrogen-air ignition and detonation studies.

- **Developer**: R. Mével, J.E. Shepherd — California Institute of Technology (Caltech)
- **File**: `Mevel2017.yaml`
- **Species / Reactions**: 14 / 42
- **Primary fuels**: H₂/air

> J. Melguizo-Gavilanes, L.R. Boeck, R. Mével, J.E. Shepherd, "Hot surface ignition of stoichiometric hydrogen-air mixtures," *Int. J. Hydrogen Energy*, 42(11):7393–7403, 2017. DOI: [10.1016/j.ijhydene.2016.05.095](https://doi.org/10.1016/j.ijhydene.2016.05.095).

## Jachimowski-7

A reduced H₂/O₂ mechanism with 7 species (H₂, O₂, H₂O, H, O, OH, N₂) derived from the full Jachimowski hydrogen-air mechanism originally developed for scramjet and hypersonic combustion applications at NASA Langley.

- **Developer**: C.J. Jachimowski — NASA Langley Research Center
- **File**: `Jachimowski-7.yaml`
- **Species / Reactions**: 7 / 7
- **Primary fuels**: H₂/air (scramjet/hypersonic)

> C.J. Jachimowski, "An Analytical Study of the Hydrogen-Air Reaction Mechanism with Application to Scramjet Combustion," NASA TP-2791, 1988.

## ONERA-7

A reduced H₂/O₂ mechanism with 7 species developed for supersonic combustion applications. Two variants are provided: an irreversible formulation with 14 unidirectional reactions (`ONERA-7.yaml`) and a reversible formulation with 7 bidirectional reactions (`ONERA-7_rev.yaml`).

- **Developer**: ONERA (Office National d'Études et de Recherches Aérospatiales), France
- **Files**: `ONERA-7.yaml` (14 irreversible), `ONERA-7_rev.yaml` (7 reversible)
- **Species / Reactions**: 7 / 7–14
- **Primary fuels**: H₂/air (scramjet)

> D. Scherrer, O. Dessornes, M. Ferrier, et al., "Research on supersonic combustion and scramjet combustors at ONERA," *Aerospace Lab*, Issue 11, 2016.

## Nassini

A global single-step mechanism for H₂/air detonation with 4 species (H₂, O₂, H₂O, N₂). Calibrated to match the Chapman-Jouguet (CJ) speed, von Neumann state, and half-reaction thickness across a wide equivalence ratio range (φ = 0–5) at atmospheric preshock conditions. The H₂O formation enthalpy is modified to reproduce CJ detonation speed. The **Original** version is from Nassini's PhD thesis; the **Montanari-Grossi** version features adjusted parameters.

- **Developer**: P.C. Nassini — University of Florence; A. Montanari, M. Grossi (modified variant)
- **Files**: `Nassini_Original.yaml`, `Nassini_Montanari_Grossi.yaml`
- **Species / Reactions**: 4 / 2
- **Primary fuels**: H₂/air (detonation)

> P.C. Nassini, A. Andreini, M.D. Bohon, "Characterization of refill region and mixing state immediately ahead of a hydrogen-air rotating detonation using LES," *Combust. Flame*, 258:113073, 2023. DOI: [10.1016/j.combustflame.2023.113073](https://doi.org/10.1016/j.combustflame.2023.113073).

## Frolov

A global single-step mechanism for H₂/air combustion with 4 species (H₂, O₂, H₂O, N₂) and 1 irreversible reaction. This variant omits pressure dependence in the rate expression. Designed for detonation simulations requiring a computationally efficient chemical model.

- **Developer**: S.M. Frolov — Semenov Federal Research Center for Chemical Physics, Moscow
- **File**: `Frolov_nopressure.yaml`
- **Species / Reactions**: 4 / 1
- **Primary fuels**: H₂/air (detonation)

> S.M. Frolov, V.S. Aksenov, V.S. Ivanov, "Large-scale hydrogen–air continuous detonation combustor," *Int. J. Hydrogen Energy*, 40(3):1616–1623, 2015. DOI: [10.1016/j.ijhydene.2014.11.112](https://doi.org/10.1016/j.ijhydene.2014.11.112).

---

# CH₄/O₂ Mechanisms — Detailed

## ZhukovC1C4

A detailed C₁–C₄ chemical kinetic mechanism with 207 species and 2176 reactions for the oxidation of light alkanes at high pressures and temperatures. Originally developed for methane/oxygen combustion under rocket engine conditions. Serves as the parent detailed mechanism from which the ZK skeletal model and the TSR-derived mechanisms have been generated.

- **Developer**: V.P. Zhukov — German Aerospace Center (DLR), Institute of Space Propulsion, Lampoldshausen
- **File**: `ZhukovC1C4.yaml`
- **Species / Reactions**: 207 / 2176
- **Primary fuels**: CH₄/O₂ and C₁–C₄ hydrocarbons (high-pressure rocket propulsion)

> V.P. Zhukov, A.F. Kong, "A compact reaction mechanism of methane oxidation at high pressures," *Prog. React. Kinet. Mech.*, 43(1):62–78, 2018. DOI: [10.3184/146867818X15066862094914](https://doi.org/10.3184/146867818X15066862094914).

## Foundational Fuel Chemistry Models (FFCM)

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

> https://web.stanford.edu/group/haiwanglab/FFCM1/
>
> https://web.stanford.edu/group/haiwanglab/FFCM2/

## DTU Mechanism

A detailed chemical kinetic model for methane oxidation under high-pressure conditions (up to 100 atm), developed at the Technical University of Denmark.

- **Developer**: Technical University of Denmark
- **File**: `DTU.yaml`
- **Species / Reactions**: 68 / 631
- **Primary fuels**: CH₄

> H. Hashemi, J.M. Christensen, S. Gersen, H. Levinsky, S.J. Klippenstein, P. Glarborg, "High-Pressure Oxidation of Methane," *Combust. Flame*, 2016. DOI: [10.1016/j.combustflame.2016.07.016](https://doi.org/10.1016/j.combustflame.2016.07.016).

---

# CH₄/O₂ Mechanisms — Reduced / Skeletal

## TSR Mechanisms (Family)

A family of skeletal mechanisms for methane–oxygen combustion at high pressure, generated via Tangential Stretching Rate (TSR) analysis combined with CSP-based reduction. Starting from the detailed ZhukovC1C4 mechanism (207 species), the reduction targets specific canonical configurations.

| Mechanism | File | Species | Reactions | Canonical Target |
|---|---|---:|---:|---|
| TSR-Rich-39 | `TSR-Rich-39.yaml` | 39 | 398 | Rich conditions (extended C₃–C₄) |
| TSR-Rich-31 | `TSR-Rich-31.yaml` | 31 | 197 | Rich conditions (C₃–C₄) |
| TSR-GP-24 | `TSR-GP-24.yaml` | 24 | 110 | General Purpose |
| TSR-CDF-13 | `TSR-CDF-13.yaml` | 13 | 46 | Counterflow Diffusion Flame |
| TSR-PSR-11 | `TSR-PSR-11.yaml` | 11 | 22 | Perfectly Stirred Reactor |

- **Developer**: M. Valorani, R. Malpica Galassi, P.P. Ciottoli, P.E. Lapenna, F. Creta — Sapienza University of Rome

> J. Liberatori, R. Malpica Galassi, D. Bianchi, F. Nasuti, F. Creta, M. Valorani, "Family of Skeletal Reaction Mechanisms for Methane–Oxygen Combustion in Rocket Propulsion," *J. Propul. Power*, 40(2):232–248, 2024. DOI: [10.2514/1.B39283](https://doi.org/10.2514/1.B39283).

## Zhukov-Kong (ZK) Mechanism

A skeletal methane kinetic mechanism for undiluted methane–oxygen mixtures at high pressures. Obtained by eliminating unimportant species and reactions from the detailed Zhukov (2009) alkane oxidation mechanism.

- **Developer**: V.P. Zhukov, A.F. Kong — DLR, Institute of Space Propulsion
- **File**: `ZK.yaml`
- **Species / Reactions**: 25 / 51
- **Primary fuels**: CH₄ (rocket engine conditions)

> V.P. Zhukov, A.F. Kong, "A compact reaction mechanism of methane oxidation at high pressures," *Prog. React. Kinet. Mech.*, 43(1):62–78, 2018.

## CORIA-CNRS Mechanism

A RAMEC-based reduced mechanism validated for auto-ignition delay, laminar premixed flame, and counterflow diffusion flame over a very large range of pressure (1 atm to 100 bar) and equivalence ratio (0.2 to 14).

- **Developer**: CORIA – CNRS, Normandie Université
- **File**: `coria.yaml`
- **Species / Reactions**: 18 / 44
- **Primary fuels**: CH₄

> F. Monnier, G. Ribert, "Simulation of high-pressure methane-oxygen combustion with a new reduced chemical mechanism," *Combust. Flame*, 235:111735, 2022.

## Smooke Mechanism

A reduced kinetic mechanism for methane-air flames.

- **File**: `smooke.yaml`
- **Species / Reactions**: 16 / 35
- **Primary fuels**: CH₄

> M.D. Smooke, ed., *Reduced Kinetic Mechanisms and Asymptotic Approximations for Methane-Air Flames: A Topical Volume*. Berlin: Springer-Verlag, 1991.

---

# CH₄/O₂ Mechanisms — Global

## Jones-Lindstedt (JL) Mechanism

A classic global reaction mechanism for methane-air combustion. The four global steps represent: (1) fuel breakdown to CO and H₂, (2) H₂ oxidation, (3) CO oxidation via the water-gas shift, and (4) CO₂ dissociation.

- **Developer**: W.P. Jones, R.P. Lindstedt — Imperial College London
- **File**: `JL.yaml`
- **Species / Reactions**: 6 / 4
- **Primary fuels**: CH₄

> W.P. Jones, R.P. Lindstedt, "Global reaction schemes for hydrocarbon combustion," *Combust. Flame*, 73(3):233–249, 1988. DOI: [10.1016/0010-2180(88)90021-1](https://doi.org/10.1016/0010-2180(88)90021-1).

## JLR (Jones-Lindstedt-Rodi) Mechanisms

Extended variants of the Jones-Lindstedt mechanism, augmented with radical species (H, O, OH), yielding 9 species and 6–8 reactions. Two sub-variants are available: **Frassoldati** (rates from CRECK Modeling Group, Politecnico di Milano) and **Nasuti** (rates adapted for rocket propulsion at Sapienza). The `-ct` files add N₂ to the element list for native Cantera compatibility without altering the chemistry.

- **Files**: `JLR-frassoldati.yaml`, `JLR-frassoldati-ct.yaml`, `JLR-nasuti.yaml`, `JLR-nasuti-ct.yaml`
- **Species / Reactions**: 9 / 6–8
- **Primary fuels**: CH₄/O₂ (rocket propulsion)

> W.P. Jones, R.P. Lindstedt, "Global reaction schemes for hydrocarbon combustion," *Combust. Flame*, 73(3):233–249, 1988.
>
> B. Betti, D. Bianchi, F. Nasuti, E. Martelli, "Chemical reaction effects on heat loads of CH₄/O₂ and H₂/O₂ rockets," *AIAA J.*, 54(5):1693–1703, 2016. DOI: [10.2514/1.J054606](https://doi.org/10.2514/1.J054606).

## Westbrook-Dryer (WD) Global Mechanism

A simplified global kinetic model for hydrocarbon combustion with 5 species and 3 reactions. The **WD-Andersen** variant uses modified rate parameters.

- **Developer**: C.K. Westbrook, F.L. Dryer — Lawrence Livermore National Lab / Princeton University
- **Files**: `WD.yaml`, `WD-andersen.yaml`
- **Species / Reactions**: 5 / 3
- **Primary fuels**: CH₄

> C.K. Westbrook, F.L. Dryer, "Chemical Kinetic Modeling of Hydrocarbon Combustion," *Prog. Energy Combust. Sci.*, 10(1):1–57, 1984.

---

# C₁–C₄ Hydrocarbon Mechanisms

## Aramco Mechanisms

Detailed chemical kinetic mechanisms developed at NUI Galway for modeling the combustion of C₁–C₄ hydrocarbon fuels.

- **Aramco 2.0**
  - **File**: `aramco20.yaml`
  - **Species / Reactions**: 532 / 2716
  - **Pressure range**: 1 to 100 atm

- **Aramco 3.0**
  - **File**: `aramco30.yaml`
  - **Species / Reactions**: 623 / 3037
  - **Pressure range**: 1 to 100 atm

> Y. Li, C-W. Zhou, K.P. Somers, K. Zhang, H.J. Curran, "The Oxidation of 2-Butene: A High Pressure Ignition Delay, Kinetic Modeling Study and Reactivity Comparison with Isobutene and 1-Butene," *Proc. Combust. Inst.*, 36(1):403–411, 2017.
>
> C-W. Zhou, Y. Li, U. Burke, C. Banyon, K.P. Somers, S. Khan, J.W. Hargis, T. Sikes, E.L. Petersen, M. AlAbbad, A. Farooq, Y. Pan, Y. Zhang, Z. Huang, J. Lopez, Z. Loparo, S.S. Vasu, H.J. Curran, "An experimental and chemical kinetic modeling study of 1,3-butadiene combustion: Ignition delay time and laminar flame speed measurements," *Combust. Flame*, 197:423–438, 2018.

## USC Mech II

A detailed chemical kinetic mechanism for the combustion of H₂/CO/C₁–C₄ compounds.

- **Developer**: University of Southern California
- **File**: `USCII.yaml`
- **Species / Reactions**: 113 / 784
- **Pressure range**: 1–50 atm
- **Primary fuels**: H₂, CO, CH₄, C₂H₆, C₃H₈, C₄H₁₀

> H. Wang, X. You, A.V. Joshi, S.G. Davis, A. Laskin, F. Egolfopoulos, C.K. Law, "USC Mech Version II. High-Temperature Combustion Reaction Model of H₂/CO/C₁-C₄ Compounds," http://ignis.usc.edu/USC_Mech_II.htm, May 2007.

## UCSD Mechanism

A detailed reaction model for the combustion of hydrocarbon fuels, developed at the Combustion Research Group of UC San Diego.

- **Developer**: University of California San Diego
- **File**: `UCSD.yaml`
- **Species / Reactions**: 57 / 268
- **Primary fuels**: H₂, CO, CH₄, C₂H₆, C₃H₈, C₄H₁₀

> "Chemical-Kinetic Mechanisms for Combustion Applications," San Diego Mechanism web page, University of California at San Diego. http://combustion.ucsd.edu

---

# Kerosene / RP-1 Mechanisms

## Zettervall

A reduced chemical kinetic mechanism for kerosene-air combustion using C₁₂H₂₃ as a surrogate fuel. Developed with a modular approach, it reproduces key flame parameters (laminar flame speed, ignition delay time, flame structure) while remaining compact enough for LES and DNS.

- **Developer**: N. Zettervall, C. Fureby (FOI / Lund University), E.J.K. Nilsson (Lund University)
- **File**: `Zettervall.yaml`
- **Species / Reactions**: 33 / 77
- **Primary fuels**: Kerosene (C₁₂H₂₃ surrogate)

> N. Zettervall, C. Fureby, E.J.K. Nilsson, "A reduced chemical kinetic reaction mechanism for kerosene-air combustion," *Fuel*, 269:117446, 2020. DOI: [10.1016/j.fuel.2020.117446](https://doi.org/10.1016/j.fuel.2020.117446).

## CKJLR-10sp

A 10-species global mechanism for RP-1 (kerosene surrogate, modeled as C₂H₄) with 8 reactions. Extends the JLR framework by introducing RP-1 as a surrogate fuel species, with ethylene as the primary cracking product. Uses NASA-9 polynomial thermodynamics.

- **Developer**: G. Passarani — Sapienza University of Rome
- **File**: `CKJLR-10sp.yaml`
- **Species / Reactions**: 10 / 8
- **Primary fuels**: RP-1/LOX

> Based on the JLR framework. See: B. Betti, D. Bianchi, F. Nasuti, E. Martelli, "Chemical reaction effects on heat loads of CH₄/O₂ and H₂/O₂ rockets," *AIAA J.*, 54(5):1693–1703, 2016. DOI: [10.2514/1.J054606](https://doi.org/10.2514/1.J054606).

---

# Hybrid Rocket Mechanisms (HTPB / Paraffin)

## Ciottoli20

A 20-species skeletal mechanism with 104 reactions for GOX/HTPB hybrid rocket propulsion. Derived from the detailed n-heptane mechanism of Curran, Pitz, and Westbrook (LLNL) using Computational Singular Perturbation (CSP) analysis. Retains key species necessary to describe butadiene oxidation pathways in non-premixed configurations.

- **Developer**: P.P. Ciottoli, R. Malpica Galassi, P.E. Lapenna, G. Leccese, D. Bianchi, F. Nasuti, F. Creta, M. Valorani — Sapienza University of Rome
- **File**: `ciottoli20.yaml`
- **Species / Reactions**: 20 / 104
- **Primary fuels**: C₄H₆/GOX (HTPB hybrid rocket)

> P.P. Ciottoli, R. Malpica Galassi, P.E. Lapenna, G. Leccese, D. Bianchi, F. Nasuti, F. Creta, M. Valorani, "CSP-based chemical kinetics mechanisms simplification strategy for non-premixed combustion: An application to hybrid rocket propulsion," *Combust. Flame*, 186:83–93, 2017. DOI: [10.1016/j.combustflame.2017.07.035](https://doi.org/10.1016/j.combustflame.2017.07.035).

## CoronettiC4H6

A global mechanism for 1,3-butadiene (C₄H₆) combustion with 9 species and 6 reactions. C₄H₆ is the primary pyrolysis product of HTPB, the most common solid fuel in hybrid rocket motors.

- **Developer**: A. Coronetti, W.A. Sirignano — University of California, Irvine
- **File**: `CoronettiC4H6.yaml`
- **Species / Reactions**: 9 / 6
- **Primary fuels**: C₄H₆ (HTPB pyrolysis product)

> A. Coronetti, W.A. Sirignano, "Numerical Analysis of Hybrid Rocket Combustion," *J. Propul. Power*, 29(5):1059–1069, 2013. DOI: [10.2514/1.B34760](https://doi.org/10.2514/1.B34760).

## Singh-WC32

A global mechanism for dotriacontane (C₃₂H₆₆) combustion with 10 species and 11 reactions. C₃₂H₆₆ is used as a surrogate for paraffin wax, a liquefying solid fuel for hybrid rocket motors. Models wax cracking to ethylene followed by oxidation through the JLR-type pathway.

- **Developer**: D. Bianchi, F. Nasuti, M.T. Migliorino — Sapienza University of Rome
- **File**: `Singh-WC32.yaml`
- **Species / Reactions**: 10 / 11
- **Primary fuels**: C₃₂H₆₆/GOX (paraffin wax hybrid rocket)

> M.T. Migliorino, D. Bianchi, F. Nasuti, "Numerical Analysis of Paraffin-Wax/Oxygen Hybrid Rocket Engines," *J. Propul. Power*, 36(5):806–819, 2020. DOI: [10.2514/1.B37914](https://doi.org/10.2514/1.B37914).

---

# Chlorine / SRM Plume Mechanisms

## Pelucchi

A detailed chlorine chemistry mechanism covering the high-temperature chemistry of HCl and Cl₂. Thermochemistry obtained using the Active Thermochemical Tables (ATcT) approach. The reaction subset is coupled with the POLIMI syngas/CO mechanism.

- **Developer**: M. Pelucchi, A. Frassoldati, T. Faravelli (Politecnico di Milano); B. Ruscic (Argonne National Lab); P. Glarborg (DTU)
- **File**: `pelucchi.yaml`
- **Species / Reactions**: 25 / 103
- **Primary fuels**: HCl/Cl₂ (chlorine inhibition chemistry)

> M. Pelucchi, A. Frassoldati, T. Faravelli, B. Ruscic, P. Glarborg, "High-temperature chemistry of HCl and Cl₂," *Combust. Flame*, 162(6):2539–2554, 2015. DOI: [10.1016/j.combustflame.2015.03.011](https://doi.org/10.1016/j.combustflame.2015.03.011).

## Cross

A mechanism for SRM plume afterburning with 20 species and 33 reactions. Includes hydrocarbons (C₂H₂, CH₂O, CH₃, CH₄), chlorine species (Cl, Cl₂, ClO, HCl), and nitrogen species (HCN, N₂). Uses NASA-9 polynomial thermodynamics.

- **File**: `cross.yaml`
- **Species / Reactions**: 20 / 33
- **Primary fuels**: SRM exhaust plume (H₂/CO/HCl/HCN afterburning)

## Ecker

A reduced mechanism for SRM plume afterburning with 14 species and 28 reactions. Includes hydrogen/oxygen combustion chemistry and chlorine species relevant to SRM exhaust containing HCl from ammonium perchlorate decomposition. Thermodynamic data for H/O/C/N from GRI-Mech 3.0; chlorine data from Pelucchi.

- **Developer**: T. Ecker, S. Karl, K. Hannemann — DLR, Göttingen
- **File**: `ecker.yaml`
- **Species / Reactions**: 14 / 28
- **Primary fuels**: SRM exhaust plume

> T. Ecker, S. Karl, K. Hannemann, "Combustion Modeling in Solid Rocket Motor Plumes," *8th European Conference for Aeronautics and Space Sciences (EUCASS)*, Madrid, 2019.

## Troyes

A reduced mechanism for SRM exhaust plume afterburning with 12 species and 17 reactions. Models secondary combustion of H₂, CO, and HCl in the plume region. Thermodynamic data for H/O/C/N from GRI-Mech 3.0; chlorine data from Pelucchi.

- **Developer**: J. Troyes et al. — ONERA, France
- **File**: `troyes.yaml`
- **Species / Reactions**: 12 / 17
- **Primary fuels**: SRM exhaust plume

> J. Troyes, I. Dubois, V. Borie, A. Boischot, "Multi-Phase Reactive Numerical Simulations of a Model Solid Rocket Exhaust Jet," *42nd AIAA/ASME/SAE/ASEE Joint Propulsion Conference & Exhibit*, AIAA 2006-4414, 2006. DOI: [10.2514/6.2006-4414](https://doi.org/10.2514/6.2006-4414).

---

# Reference Mechanisms (Not Included)

## GRI-Mech 3.0

A widely-used detailed mechanism for natural gas combustion (53 species, 325 reactions, valid 1000–2500 K, 10 Torr–10 atm). Not included in this database but commonly used as a reference and as a source of thermodynamic/transport data for other mechanisms.

- **Developer**: Gas Research Institute
- **Primary fuels**: CH₄, C₂H₆, C₃H₈

> GRI-Mech 3.0, http://combustion.berkeley.edu/gri-mech/version30/text30.html, 1999.
