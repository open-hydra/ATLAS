import cantera as ct
import numpy as np
import math
from . import io as IG_IO


def compute_properties (name, T_low, T_max, phase, further_sp):

    print(' -- Build chemistry properties')

    # Define temperature range
    temperatures = np.linspace(T_low, T_max, T_max - T_low + 1)

    n_arr = 0; n_troe = 0; n_lind = 0

    for i in range(phase.n_reactions):
        if 'falloff' not in phase.reaction(i).reaction_type: n_arr += 1
        if phase.reaction(i).reaction_type == 'falloff-Troe': n_troe += 1
        if phase.reaction(i).reaction_type == 'falloff-Lindemann': n_lind += 1

    if n_arr > 0:
        kf = np.zeros((n_arr, len(temperatures)))
        kb = np.zeros_like(kf)
        ii = 0
        for i in range(phase.n_reactions):
            if 'falloff' not in phase.reaction(i).reaction_type:
                for t, T in enumerate(temperatures):
                    phase.TP = T, ct.one_atm
                    kf[ii, t] = phase.forward_rate_constants[i]
                    kb[ii, t] = phase.reverse_rate_constants[i]
                ii += 1
        IG_IO.write_chemistry_Arrhenius(name, temperatures, kf, kb)

    # Compute fall-off Troe
    if n_troe > 0:
        k_0_t = np.zeros((n_troe, len(temperatures)))
        k_inf_t = np.zeros_like(k_0_t)
        kc_t = np.zeros_like(k_0_t)
        Fcent = np.zeros_like(k_0_t)
        ii = 0
        for i in range(phase.n_reactions):
            if phase.reaction(i).reaction_type == 'falloff-Troe':
                rxn = phase.reaction(i)
                alpha, T3, T1, *T2 = rxn.rate.falloff_coeffs
                for t, T in enumerate(temperatures):
                    phase.TP = T, ct.one_atm
                    Fcent[ii, t] = ((1 - alpha) * math.exp(-T / T3) +
                                    alpha * math.exp(-T / T1))
                    if T2:
                        Fcent[ii, t] += math.exp(-T2[0] / T)
                    k_inf_t[ii, t] = rxn.rate.high_rate(T)
                    k_0_t[ii, t] = rxn.rate.low_rate(T)
                    kc_t[ii, t] = phase.equilibrium_constants[i]
                ii += 1
        IG_IO.write_chemistry_Troe(name, temperatures, k_0_t, k_inf_t, kc_t, Fcent)

    # Compute falloff Lindemann
    if n_lind > 0:
        k_0_l = np.zeros((n_lind, len(temperatures)))
        k_inf_l = np.zeros_like(k_0_l)
        kc_l = np.zeros_like(k_0_l)
        ii = 0
        for i in range(phase.n_reactions):
            if phase.reaction(i).reaction_type == 'falloff-Lindemann':
                rxn = phase.reaction(i)
                for t, T in enumerate(temperatures):
                    phase.TP = T, 300*ct.one_atm
                    k_inf_l[ii,t] = rxn.rate.high_rate(T)
                    k_0_l[ii,t] = rxn.rate.low_rate(T)
                    kc_l[ii,t] = phase.equilibrium_constants[i]
                ii += 1
        IG_IO.write_chemistry_Lindemann(name, temperatures, k_0_l, k_inf_l, kc_l)

    IG_IO.write_chemistry_info(name, phase, further_sp)
