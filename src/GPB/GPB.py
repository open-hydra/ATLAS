##################################################
#          GPB.py - General Phase Builder        #
##################################################
import Ideal_Gas
import Condensed_Phase
from Read_INI import check_phases

print()
print( ' ATLAS - General Phase Builder ' )
print()

# Input file definition
inifile = 'input.ini'

types = check_phases(inifile)

for i in range(len(types)):
    if ('ideal' in types[i] or 'heavy' in types[i]): Ideal_Gas.build(inifile, 'GPB-Phase'+str(i+1))
    if ('condensed' in types[i]): Condensed_Phase.build(types[i], inifile, 'GPB-Phase'+str(i+1))
    if ('solid' in types[i]): Condensed_Phase.build(types[i], inifile, 'GPB-Phase'+str(i+1))