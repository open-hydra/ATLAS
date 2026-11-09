"""Case-directory custom.py of the test RF-custom: a calorically perfect gas as a RealFluid, whose tables have a closed
form (h = cp T, rho = p / (R T), ...), so that GPB's tables can be checked against the formulas.

The relations are a class derived from RealFluid, with the parameters of the gas; the fluids are its instances."""
import numpy as np

from custom_classes import RealFluid


class PerfectGas(RealFluid):
    """A calorically perfect gas: the equation of state, for any R, cp, mu, k."""

    def __init__(self, name, R, cp, mu, k, sound=True, T_ref=298.15, p_ref=1.0e5):
        super().__init__(name)
        self.R, self.cp, self.mu, self.k = R, cp, mu, k
        self.sound, self.T_ref, self.p_ref = sound, T_ref, p_ref

    def entropy(self, T, p):
        return self.cp * np.log(T / self.T_ref) - self.R * np.log(p / self.p_ref)

    def reference(self, T, p):
        return self.cp * T, self.entropy(T, p)

    def state(self, h, p):
        T = h / self.cp
        rho = p / (self.R * T)
        gamma = self.cp / (self.cp - self.R)
        state = {"T": T, "rho": rho,
                 "drho_dT": -rho / T,                   # at constant p
                 "drho_dh": -rho / (self.cp * T),       # at constant p
                 "drho_dp": 1.0 / (self.R * T),         # at constant h
                 "cp": self.cp, "s": self.entropy(T, p), "mu": self.mu, "k": self.k}
        if self.sound:
            state["a"] = np.sqrt(gamma * self.R * T)
        return state


PerfectAir = PerfectGas("PerfectAir", R=287.0, cp=1005.0, mu=1.8e-5, k=0.026)

# the same gas without a speed of sound: GPB writes 500 m/s and says so
PerfectAirNoSound = PerfectGas("PerfectAirNoSound", R=287.0, cp=1005.0, mu=1.8e-5, k=0.026, sound=False)
