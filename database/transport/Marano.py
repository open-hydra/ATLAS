import numpy as np

def Marano_f(temperature):
    """
    Compute dynamic viscosity (mu) and thermal conductivity (k) Marano formula.
    Reference for these numbers: Leccese PhD Thesis 
    https://iris.uniroma1.it/retrieve/e3835319-f75c-15e8-e053-a505fe0a3de9/Tesi%20dottorato%20Leccese

    Returns:
        mu : Viscosity in Pa·s
        k  : Thermal conductivity in W/m·K
    """

    # Viscosity coefficients
    Am = 104.67374020
    Bm = -14186.44194
    Cm = -13.54367495
    Dm = -0.000003161
    Em = 2129422.1620

    # Thermal conductivity coefficients
    Ak = 0.2083972160
    Bk = -0.000142555

    # Limit the range
    T = np.clip(temperature, 273.0, 573.0)

    mu = 0.001 * np.exp(Am + Bm / T + Cm * np.log(T) + Dm * T**2 + Em / T**2)
    k = Ak + Bk * T

    return mu, k
