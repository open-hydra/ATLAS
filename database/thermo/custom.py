"""Substances of `thermo = custom`: the ones that ship with ATLAS.

Each substance is an instance of a class of custom_classes.py, made with its own data: a CondensedMaterial is given
cp, rho and k (and optionally h, psat) as numbers or as functions of the temperature T [K], as the contract of the class
declares. GPB finds a substance by its name, the value of `material` in input.ini. To add a substance, make one here,
or in a custom.py of the case directory, which GPB executes after this one (and which keeps data out of the ATLAS tree).

The thermal conductivities k(T) are correlations from the literature. The specific heat and the density are NOT: no
source for them has been entered yet, so every material below gives the placeholders CP_PLACEHOLDER = 300 J/kg/K and
RHO_PLACEHOLDER = 1000 kg/m3. Replace both with the data of your material before using it for anything but the layout
of the files.
"""
import numpy as np

from custom_classes import CondensedMaterial

CP_PLACEHOLDER = 300.0       # [J/kg/K]  no source entered: replace with the data of the material
RHO_PLACEHOLDER = 1000.0     # [kg/m3]   no source entered: replace with the data of the material


# ---------------------------------------------------------------------------------------------------------------
# Conductivity correlations [W/m/K], T in K
# ---------------------------------------------------------------------------------------------------------------
def _k_tungsten(T):
    t = T / 1e3
    return np.where(T < 890, 165.4 - 85.57 * t + 33.51 * t**2, 133.82 - 15.57 * t)


def _k_molybdenum(T):
    return np.where(T < 50, -4.545 + 16.186 * T - 0.0605 * T**2 - 0.00298 * T**3,
                    np.where(T < 150, 522.44 - 5.4776 * T + 0.02 * T**2,
                             153.29 - 0.0513 * T + 9e-6 * T**2))


def _k_uranium_nitride(T):
    return np.where(T < 1910, 1.43 * T**0.39, 27.0)


def _k_mo30w(T):
    """Molybdenum with 30 wt % tungsten: the mass-weighted mean of the two metals."""
    return 0.7 * _k_molybdenum(T) + 0.3 * _k_tungsten(T)


def _k_mo30w_60un(T, vp=0.6):
    """The Mo30W matrix with a volume fraction 1 - vp of matrix and vp of uranium nitride (a cermet)."""
    k_matrix = _k_mo30w(T)
    k_un = _k_uranium_nitride(T)
    return k_un + (1 - vp) * (k_matrix - k_un) * (k_un / k_matrix) ** (1 / 3)


# uranium carbide: measured k(T), interpolated linearly
_T_UC = np.array([
    98.84678747940691, 164.7446457990115, 234.7611202635914, 329.4892915980230, 415.9802306425040,
    506.5897858319604, 564.2504118616145, 638.3855024711696, 720.7578253706754, 790.7742998352553,
    869.0280065897858, 943.1630971993410, 1033.772652388797, 1112.026359143327, 1206.754530477759,
    1276.771004942339, 1367.380560131795, 1453.871499176276, 1528.006589785832, 1610.378912685337,
    1684.514003294892, 1766.886326194398, 1865.733113673805, 1952.224052718286, 2038.714991762767,
    2121.087314662273, 2191.103789126853, 2277.594728171334, 2351.729818780889, 2438.220757825370,
    2528.830313014827, 2800.0])
_K_UC = np.array([
    12.564570095017498, 12.500550704393461, 12.3734888419193, 12.436857507371341, 12.564570095017498,
    12.628917349787105, 12.758602176758451, 12.955630656184326, 13.155701806050665, 13.42727769909136,
    13.774644790939321, 13.987363808288592, 14.349220470345522, 14.720438456356666, 15.101259946155567,
    15.651018177675914, 16.13814156551242, 16.6404262158485, 17.1583440088819, 17.692381511642754,
    18.33646898552934, 19.004004330113535, 19.898095374310625, 20.728095845618903, 21.59271776030721,
    22.378796165152266, 23.075315387091496, 23.915367450575868, 25.040525890071685, 26.3528943217433,
    28.01884123810662, 30.0])


# ---------------------------------------------------------------------------------------------------------------
# The materials
# ---------------------------------------------------------------------------------------------------------------
Mo30W = CondensedMaterial("Mo30W", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER, k=_k_mo30w)

Mo30W_60UN = CondensedMaterial("Mo30W-60UN", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER, k=_k_mo30w_60un)

UC = CondensedMaterial("UC", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER,
                       k=lambda T: np.interp(T, _T_UC, _K_UC))     # constant beyond the first and the last point

ZrC = CondensedMaterial("ZrC", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER,
                        k=lambda T: 0.5209 + 9.812e-4 * T + 1.045e-7 * T**2)

ZrHx = CondensedMaterial("ZrHx", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER, k=16.0)

Zircaloy = CondensedMaterial("Zircaloy", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER,
                             k=lambda T: 131.2 - 0.08432 * T + 1.96e-5 * T**2)

Graphite = CondensedMaterial("Graphite", cp=CP_PLACEHOLDER, rho=RHO_PLACEHOLDER,
                             k=lambda T: 134.0 - 0.1074 * T + 3.719e-5 * T**2)
