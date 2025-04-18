import numpy as np
import matplotlib.pyplot as plt

#
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

  elif case == "huang-40-stoich":
    x = np.array([1024, 1047, 1061, 1096, 1116, 1152, 1153, 1171, 1174, 1175, 1177, 1213, 1295])
    y = 1e-6*np.array([2712, 2217, 1212, 1080, 978, 714, 696, 660, 651, 612, 624, 612, 395])

    # Error values
    lower_err = y-y
    upper_err = y-y

    # Combine lower and upper errors into a tuple
    y_err = [lower_err, upper_err]
    plt.errorbar(x, y, yerr=y_err, fmt='o', capsize=5, color='k', label='Huang et al.')

  elif case == "huang-40-rich":
    x = np.array([1068, 1128, 1193, 1229, 1266, 1290])
    y = 1e-6*np.array([2028, 972, 930, 708, 612, 506])

    # Error values
    lower_err = y-y
    upper_err = y-y

    # Combine lower and upper errors into a tuple
    y_err = [lower_err, upper_err]
    plt.errorbar(x, y, yerr=y_err, fmt='o', capsize=5, color='k', label='Huang et al.')

  elif case == "lifshitz-4.6":

    x = 1000*np.array([0.8732151217228465,  0.8768287687265919,  0.9132066362359552,  0.9374268492509366,  0.9531981507490639,  0.996651890215356,  1.0017848782771537,  1.0117772705992512,  1.034870962078652,  1.046136177434457,  1.069229868913858,  1.1121044373244386,  1.1551446109030383,  1.1585176732209739,  1.2190572331460678,  1.232012230805244,  1.2810159176029967])
    y = 1e-6*np.array([44.74135138818417,  35.34976537256961,  54.462720223097676,  63.70932522604362,  102.89932500679282,  200.1726050344875,  190.3010382797039,  118.45750079675777,  253.68724588925582,  251.0614276904837,  241.14438324721164,  721.6612946002815,  743.3536821098346,  795.7333439493281,  1406.085303254658,  2008.7036561099735,  2089.087689931577])
    y = y[::-1]

    # Error values
    lower_err = y-y
    upper_err = y-y

    # Combine lower and upper errors into a tuple
    y_err = [lower_err, upper_err]
    plt.errorbar(x, y, yerr=y_err, fmt='o', capsize=5, color='k', label='Lifshitz et al.')

#
def setup_case(case):

  if case == "pierro":
    of = [0.0]
    T = np.linspace(1050, 1350, 20)
    pressure = [100]
    fuel_entry = "{CH4:1.672995}"
    oxi_entry = "{O2:6.673626} {AR:91.653379}"

  elif case == "huang-40-stoich":
    of = [0.0]
    T = np.linspace(1024, 1295, 20)
    pressure = [40]
    fuel_entry = "{CH4:0.05502567}"
    oxi_entry = "{O2:0.22180952} {N2:0.72316481}"

  elif case == "huang-40-rich":
    of = [0.0]
    T = np.linspace(1068, 1290, 20)
    pressure = [40]
    fuel_entry = "{CH4:0.07048119}"
    oxi_entry = "{O2:0.216721} {N2:0.71279781}"
  
  elif case == "lifshitz-4.6":
    of = [0.0]
    T = np.linspace(800, 1300, 10)
    pressure = [4.6]
    fuel_entry = "{H2:0.00534534}"
    oxi_entry = "{CL2:0.18798856} {Ar:0.8066661}"

  return fuel_entry, oxi_entry, pressure, of, T