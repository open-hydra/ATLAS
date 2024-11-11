##################################################################
#          KAnT.py - chemical Kinetic Analyzer and Tester        #
##################################################################
import equilibrium
import ignition_delay
import counterflow_diffusion_flame
from Parse_output import *
from Read_INI import *
from Write_TEC import *
from plot import *
import KAnT.reference as reference
import sys
import matplotlib.pyplot as plt
from pathlib import Path

inifile = Path("kant.ini")
if not inifile.is_file():
    inifile = Path("input.ini")
    if not inifile.is_file():
        exit('Missing input file')

analyses = check_analyses(inifile)

for analysis in analyses:

    if 'Equilibrium' in analysis:
        fuel, oxi, pressure, of = read_Xequilibrium(inifile,'KAnT-Equilibrium')
        models = read_reactions(inifile,'KAnT-Equilibrium')
        solutions = equilibrium.run_all(models,fuel,oxi,pressure,of)
        Ta = extract(models,solutions)

        # Write output
        if len(of)>1 and len(pressure)==1:
            write_1D(models, of, Ta, 'Mixture Ratio', 'Adiabatic Flame Temperature, K')
        elif len(pressure)>1 and len(of)==1:
            write_1D(models, pressure, Ta, 'Chamber Pressure, bar', 'Adiabatic Flame Temperature, K')

        # Plot output (if requested)
        if '--plot' in sys.argv:
            if len(of)>1 and len(pressure)==1: 
                plot_1D(models, of, Ta, 'Mixture Ratio', 'Adiabatic Flame Temperature, K',False)
            elif len(pressure)>1 and len(of)==1:
                plot_1D(models, pressure, Ta, 'Pressure Chamber, bar', 'Adiabatic Flame Temperature, K',False)
            elif len(pressure)>1 and len(of)>1:
                plot_2D(of, pressure, Ta)

    if 'Ignition' in analysis:
        case, fuel, oxi, pressure, of, temperatures = read_Xignition_delay(inifile,'KAnT-Ignition')
        models = read_reactions(inifile,'KAnT-Ignition')
        tau = ignition_delay.run_all(models,fuel,oxi,pressure,of,temperatures)

        # Write output
        if len(pressure)==1 and len(of)>1 and len(temperatures)==1:
            write_1D(models, of, tau, 'Mixture Ratio', 'Ignition Delay, s')
        elif len(pressure)>1 and len(of)==1 and len(temperatures)==1:
            write_1D(models, pressure, tau, 'Chamber Pressure, bar', 'Ignition Delay, s')
        elif len(pressure)==1 and len(of)==1 and len(temperatures)>1:
            write_1D(models, temperatures, tau, 'Initial Temperature, K', 'Ignition Delay, s')

        # Plot output (if requested)
        if '--plot' in sys.argv:
            if len(pressure)==1 and len(of)>1 and len(temperatures)==1: 
                plot_1D(models, of, tau, 'Mixture Ratio', 'Ignition Delay, s',True)
            elif len(pressure)>1 and len(of)==1 and len(temperatures)==1:
                plot_1D(models, pressure, tau, 'Chamber Pressure, bar', 'Ignition Delay, s',True)
            elif len(pressure)==1 and len(of)==1 and len(temperatures)>1:
                plot_1D(models, temperatures, tau, 'Initial Temperature, K', 'Ignition Delay, s',True)

            if case is not None: reference.plot_cases(case)

    if 'Counterflow' in analysis:
        fuel, oxi, pressure, of, mdot, width = read_Xcounterflow(inifile,'KAnT-Counterflow')
        models = read_reactions(inifile,'KAnT-Counterflow')
        x, T = counterflow_diffusion_flame.run_all(models, fuel, oxi, pressure, of, mdot, width)

        # Write output
        write_1D(models, x, T, 'x', 'Temperature, K')

        # Plot output (if requested)
        if '--plot' in sys.argv:
            plot_1D(models, x, T, 'x', 'Temperature, K', False)

if '--plot' in sys.argv: plt.show()
