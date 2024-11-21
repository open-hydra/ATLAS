##################################################
#          GPB.py - General Phase Builder        #
##################################################
import ideal_gas
from Read_INI import check_phases

print()
print( ' ATLAS - General Phase Builder ' )
print()

# Input file definition
inifile = 'input.ini'

types = check_phases(inifile)

for i in range(len(types)):
    if ('ideal' in types[i] or 'heavy' in types[i]): ideal_gas.build(inifile, 'GPB-Phase'+str(i+1))