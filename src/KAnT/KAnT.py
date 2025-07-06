##################################################################
#              KAnT.py - Kinetic Analyzer and Tester             #
##################################################################
import equilibrium
import ignition_delay
import counterflow_diffusion_flame
import zeroD_time_evolution
from read_INI import *
from write_TEC import *
from plot import *
from reference import *
from phase_tools import extract
import sys
import matplotlib.pyplot as plt
from pathlib import Path

print()
print( ' ATLAS - Kinetic Analyzer and Tester  ' )
print()

inifile = Path("kant.ini")
if not inifile.is_file():
    inifile = Path("input.ini")
    if not inifile.is_file():
        exit('Missing input file')

analyses = check_analyses(inifile)

for analysis in analyses:

    if '0D' in analysis:
        print( ' - 0D simulation ' )
        print()
        zeroDopt, (case, fuel, oxi, pressure, of, T) = read_0D(inifile,analysis)
        models = read_reactions(inifile,analysis)

        if zeroDopt.eq:
            print( ' - Steady-state equilibrium @',zeroDopt.type )
            solutions = equilibrium.run_all(models,zeroDopt.type,fuel,oxi,pressure,of)
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

        if zeroDopt.id:
            print( ' - Ignition delay @',zeroDopt.type )
            print()
            tau = ignition_delay.run_all(models,zeroDopt.type,fuel,oxi,pressure,of,T)

            # Write output
            if len(pressure)==1 and len(of)>1 and len(T)==1:
                write_1D(models, of, tau, 'Mixture Ratio', 'Ignition Delay, s')
            elif len(pressure)>1 and len(of)==1 and len(T)==1:
                write_1D(models, pressure, tau, 'Chamber Pressure, bar', 'Ignition Delay, s')
            elif len(pressure)==1 and len(of)==1 and len(T)>1:
                write_1D(models, T, tau, 'Initial Temperature, K', 'Ignition Delay, s')

            # Plot output (if requested)
            if '--plot' in sys.argv:
                if len(pressure)==1 and len(of)>1 and len(T)==1: 
                    plot_1D(models, of, tau, 'Mixture Ratio', 'Ignition Delay, s',True)
                elif len(pressure)>1 and len(of)==1 and len(T)==1:
                    plot_1D(models, pressure, tau, 'Chamber Pressure, bar', 'Ignition Delay, s',True)
                elif len(pressure)==1 and len(of)==1 and len(T)>1:
                    plot_1D(models, T, tau, 'Initial Temperature, K', 'Ignition Delay, s',True)

                if case is not None: plot_cases(case)

        if zeroDopt.te:
            print( ' - Time-accurate evolution @',zeroDopt.type )
            print()
            tend, nstep = read_0D_te(inifile,analysis)
            time, pout, Tout = zeroD_time_evolution.run_all(models,zeroDopt.type,fuel,oxi,pressure,of,T,tend,nstep)

            # Write output
            write_1D(models, time, Tout, 'Time, s', 'Temperature, K')

            # Plot output (if requested)
            if '--plot' in sys.argv:
                plot_1D(models, time, Tout, 'Time, s', 'Temperature, K', False)


    if '1D' in analysis:
        print( ' - 1D simulation ' )
        print()
        print( ' - Counterflow diffusion flame ' )
        print()
        fuel, oxi, pressure, of, mdot, width = read_1D(inifile,analysis)
        models = read_reactions(inifile,analysis)
        x, T = counterflow_diffusion_flame.run_all(models, fuel, oxi, pressure, of, mdot, width)

        # Write output
        write_1D(models, x, T, 'x', 'Temperature, K')

        # Plot output (if requested)
        if '--plot' in sys.argv:
            plot_1D(models, x, T, 'x', 'Temperature, K', False)

if '--plot' in sys.argv: plt.show()
