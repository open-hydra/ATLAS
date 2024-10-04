import numpy as np
import matplotlib.pyplot as plt

def plot_cases(case):

  if case == "pierro":
    x = 1000/np.array([0.7406904577191622, 0.7756012412723041, 0.8815748642358417, 0.9247090768037238, 0.9341737781225756])
    y = 1e-6*np.array([260.14614849280986, 559.8155917577525, 1682.4682720036885, 2194.209804005066, 3557.475368774399])

    # Error values
    lower_err = y-1e-6*np.array([209.13335550431765, 450.03977128329353, 1347.7172486843685, 1757.6405150084709, 2859.879976336889])
    upper_err = 1e-6*np.array([312.22773584580284, 671.8913799737911, 2019.2949386088894, 2642.9261403100336, 4269.686428781933])-y

    # Combine lower and upper errors into a tuple
    y_err = [lower_err, upper_err]
    plt.errorbar(x, y, yerr=y_err, fmt='o', capsize=5, color='k', label='Pierro et al.')

#
def setup_case(case):

  if case == "pierro":
    of = [0.0]
    T = np.linspace(1050, 1350, 20)
    pressure = [100]
    fuel_entry = "{CH4:1.672995}"
    oxi_entry = "{O2:6.673626} {AR:91.653379}"

  return fuel_entry, oxi_entry, pressure, of, T