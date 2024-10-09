# Detailed mechanisms for C1-C4

## Aramco Mechanisms

**Aramco 2.0** and **Aramco 3.0** are detailed chemical kinetic mechanisms developed for modeling the combustion of hydrocarbon fuels, particularly relevant to aviation and engine applications. These mechanisms provide comprehensive reaction sets for a wide range of fuel compositions, including Jet A, kerosene, and other alkanes.

### Key Features

- **Aramco 2.0**:
  - **Number of species**: 111
  - **Number of reactions**: 578 reactions
  - **Pressure range**: Valid from 1 to 100 atm
  - **Primary fuels**: Jet A, alkanes, and other hydrocarbons

- **Aramco 3.0**:
  - **Number of species**: 147
  - **Number of reactions**: 763 reactions
  - **Pressure range**: Valid from 1 to 100 atm
  - **Primary fuels**: Jet A, alkanes, and other hydrocarbons

+ Aramco 2.0: Y. Li, C-W. Zhou, K.P. Somers, K. Zhang, H.J. Curran The Oxidation of 2-Butene: A High Pressure Ignition Delay, Kinetic Modeling Study and Reactivity Comparison with Isobutene and 1-Butene Proceedings of the Combustion Institute (2017) 36(1) 403–411.

+ Aramco 3.0: C-W. Zhou, Y. Li, U. Burke, C. Banyon, K.P. Somers, S. Khan, J.W. Hargis, T. Sikes, E.L. Petersen, M. AlAbbad, A. Farooq, Y. Pan, Y. Zhang, Z. Huang, J. Lopez, Z. Loparo, S.S. Vasu, H.J. Curran. "An experimental and chemical kinetic modeling study of 1,3-butadiene combustion: Ignition delay time and laminar flame speed measurements" Combustion and Flame 197 (2018) 423–438.

## USC Mech II Mechanism

**USC Mech II** is a detailed chemical kinetic mechanism developed by the University of Southern California for the simulation of the combustion of small hydrocarbon fuels such as methane, ethane, propane, and butane. It provides accurate predictions of combustion properties for a wide range of applications, including ignition delay times, flame speed, and pollutant formation.

### Key Features

- **Developer**: University of Southern California
- **Number of species**: 111
- **Number of reactions**: 784 reversible reactions
- **Pressure range**: 1–50 atm
- **Primary fuels**: Methane (CH₄), ethane (C₂H₆), propane (C₃H₈), butane (C₄H₁₀), and hydrogen (H₂)

+ Hai Wang, Xiaoqing You, Ameya V. Joshi, Scott G. Davis, Alexander Laskin, Fokion Egolfopoulos & Chung K. Law,  USC Mech Version II. High-Temperature Combustion Reaction Model of H2/CO/C1-C4 Compounds. http://ignis.usc.edu/USC_Mech_II.htm, May 2007.

## UCSD Chemical Kinetic Mechanism

The **UC San Diego (UCSD) Chemical Kinetic Mechanism** is a detailed reaction model for the combustion of hydrocarbon fuels. This mechanism, developed by researchers at the Combustion Research Group at UC San Diego, is widely used in combustion simulations, especially for understanding combustion behavior of various fuels.

### Key Features

- **Developer**: University of California San Diego
- **Number of species**: 57
- **Number of reactions**: 268
- **Pressure range**: Suitable for a wide range of pressures, including high-pressure combustion
- **Primary fuels**: Methane, Ethane, Propane, Butane, Hydrogen, Syngas, and other hydrocarbons

+ "Chemical-Kinetic Mechanisms for Combustion Applications", San Diego Mechanism web page, Mechanical and Aerospace Engineering (Combustion Research), University of California at San Diego (http://combustion.ucsd.edu).


## GRI-Mech 3.0 Mechanism

**GRI-Mech 3.0** is a detailed chemical kinetic mechanism developed by the **Gas Research Institute** to simulate natural gas combustion. It is specifically designed to model the combustion of methane and its derivatives, providing accurate predictions for various combustion characteristics such as flame speed, ignition delay times, and pollutant formation (e.g., NOx, CO).

### Key Features

- **Developer**: Gas Research Institute
- **Number of species**: 53
- **Number of reactions**: 325 reactions
- **Temperature range**: 1000 to 2500 K
- **Pressure range**: 10 Torr to 10 atm
- **Equivalence ratio**: 0.1 to 5
- **Primary fuels**: Methane (CH₄), ethane (C₂H₆), propane (C₃H₈), and other natural gas components

+ GRI (1999). GRI-Mech 3.0: A Detailed Chemical Kinetic Mechanism for the Combustion of Natural Gas http://combustion.berkeley.edu/gri-mech/version30/text30.html



# Detailed mechanisms for CH4

## Foundational Fuel Chemistry Models

The Foundational Fuel Chemistry Model is a detailed chemical kinetic reaction model developed through a collaboration between Hai Wang's research group at Stanford University and Gregory Smith of SRI International. This model aims to advance the understanding of combustion processes for small hydrocarbon fuels by employing up-to-date kinetic knowledge with well-defined predictive uncertainties. The FFCM Version 2 (FFCM-2) extends from the previous FFCM Version 1 (FFCM-1) effort to cover a wider range of relevant C0-C4 fuels.

### Key Features

- **FFCM-1**
  - **Developer**: Stanford University and SRI International
  - **Number of species**: 53
  - **Number of reactions**: 300+
  - **Pressure range**: Valid from atmospheric pressure up to 50 atm
  - **Primary fuels**: C0-2 species and combustion targets of H2, H2O2, CO, CH2O, CH4, and a limited set of C2H6 data.  The release should only be used for predicting H2, H2/CO, CH2O and CH4 combustion.

- **FFCM-2**
  - **Developer**: Stanford University and SRI International
  - **Number of species**: 96
  - **Number of reactions**: 1054
  - **Pressure range**: Valid from atmospheric pressure up to 50 atm
  - **Primary fuels**:  C0-C4 fuels

+ https://web.stanford.edu/group/haiwanglab/FFCM1/

+ https://web.stanford.edu/group/haiwanglab/FFCM2/

## DTU Mechanism

The DTU mechanism is a comprehensive chemical kinetic model developed to accurately simulate the oxidation of methane under high-pressure conditions. This mechanism has been formulated to capture critical reactions and pathways that govern the combustion processes of methane, particularly in environments relevant to advanced combustion systems.

## Key Features

- **Developer**: Technical University of Denmark
- **Number of species**: 68
- **Number of reactions**: 631
- **Pressure range**: Suitable for high-pressure applications (up to 100 atm)
- **Primary fuels**: Methane (CH₄)

+ H. Hashemi, J. M. Christensen, S. Gersen, H. Levinskyb, S.J. Klippenstein, P. Glarborg, "High-Pressure Oxidation of Methane", Combust. Flame (2016), in Press (doi: 10.1016/j.combustflame.2016.07.016)



# Reduced mechanisms for CH4

## Smooke Mechanism

A reduced kinetic mechanisms for methane-air flames

### Key Features

- **Developer**:
- **Number of species**: 16
- **Number of reactions**: 35
- **Primary fuels**: methane

+ Smooke, Mitchell D., ed. Reduced kinetic mechanisms and asymptotic approximations for methane-air flames: a topical volume. Berlin: Springer-Verlag, 1991.

## CORIA Mechanism

A RAMEC-based reduced chemical mechanism to encompass a very large range of pressure and equivalence ratio. Validations are performed for a set of canonical test-cases: auto-ignition delay simulation, one-dimensional laminar premixed ﬂame freely propagating, and one-dimensional counterﬂow diffusion ﬂame. A very good agreement is obtained by comparison with the RAMEC detailed mechanism.

### Key Features

- **Developer**: CORIA - CNRS, Normandie Université
- **Number of species**: 17
- **Number of reactions**: 44
- **Equivalence ratio**: 0.2 to 14
- **Pressure range**: Valid from atmospheric pressure up to 100 bar
- **Primary fuels**: methane

+ Monnier, F., & Ribert, G. (2022). Simulation of high-pressure methane-oxygen combustion with a new reduced chemical mechanism. Combustion and Flame, 235, 111735.

## TSR mechanisms

# Global mechanisms for CH4

## Westbrook-Dryer Global Mechanism

The **Westbrook-Dryer Global Mechanism** is a simplified kinetic model designed for the combustion of hydrocarbon fuels. This global mechanism is widely utilized in combustion modeling due to its computational efficiency while still providing a reasonable representation of combustion phenomena.

### Key Features

- **Developer**: Lawrence Livermore National Lab, Princeton University
- **Number of species**: 5
- **Number of reactions**: 3
- **Pressure range**: Suitable for low to moderate pressure environments (1 atm to 30 atm)
- **Primary fuels**: Typically includes Methane (CH₄), Ethane (C₂H₆), and Propane (C₃H₈)

+ Westbrook, C. K., & Dryer, F. L. (1984). Chemical Kinetic Modeling of Hydrocarbon Combustion. Progress in Energy and Combustion Science, 10(1), 1-57.
