##################################################################
#          KAnT.py - chemical Kinetic Analyzer and Tester        #
##################################################################
from equilibrium import *
import ignition_delay
from Read_INI import *
from plot import *
import cases
import sys
import matplotlib.pyplot as plt
#plt.ion()

# Create a figure and axes object
fig, ax = plt.subplots()

# Input file definition
inifile = 'input.ini'

analyses = check_analyses(inifile)

for analysis in analyses:

    if 'Equilibrium' in analysis:
        fuel, oxi, pressure, of = read_Xequilibrium(inifile,'KAnT-Equilibrium')
        models = read_reactions(inifile,'KAnT-Equilibrium')
        Ta = run_all_equilibria(models,fuel,oxi,pressure,of)

        if '--plot' in sys.argv:
            if len(of)>1 and len(pressure)==1: 
                plot_1D(models, of, Ta, 'Mixture Ratio', 'Adiabatic Flame Temperature, K',False)
            elif len(pressure)>1 and len(of)==1:
                plot_1D(models, pressure, Ta, 'Pressure Chamber, bar', 'Adiabatic Flame Temperature, K',False)
            else:
                plot_2D(of, pressure, Ta)

    if 'Ignition' in analysis:
        case, fuel, oxi, pressure, of, temperatures = read_Xignition_delay(inifile,'KAnT-Ignition')
        models = read_reactions(inifile,'KAnT-Ignition')
        tau = ignition_delay.run_all(models,fuel,oxi,pressure,of,temperatures)

        if '--plot' in sys.argv:
            if len(pressure)==1 and len(of)>1 and len(temperatures)==1: 
                plot_1D(models, of, tau, 'Mixture Ratio', 'Ignition Delay, s',True)
            elif len(pressure)>1 and len(of)==1 and len(temperatures)==1:
                plot_1D(models, pressure, tau, 'Chamber Pressure, bar', 'Ignition Delay, s',True)
            elif len(pressure)==1 and len(of)==1 and len(temperatures)>1:
                plot_1D(models, temperatures, tau, 'Initial Temperature, K', 'Ignition Delay, s',True)
            else:
                plot_2D(of, pressure, Ta)

            if case is not None: cases.plot_cases(case)

if '--plot' in sys.argv: plt.show()
