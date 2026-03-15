"""GPB entry point for `python -m GPB` invocation."""
import ideal_gas
import condensed
import real_gas
from ini import check_phases

print()
print(' ATLAS - General Phase Builder ')
print()

# Input file definition
inifile = 'input.ini'

types = check_phases(inifile)

for i in range(len(types)):
    if ('ideal' in types[i] or 'heavy' in types[i]): ideal_gas.build(inifile, 'GPB-Phase'+str(i+1))
    if ('condensed' in types[i]): condensed.build(types[i], inifile, 'GPB-Phase'+str(i+1))
    if ('solid' in types[i]): condensed.build(types[i], inifile, 'GPB-Phase'+str(i+1))
    if ('real' in types[i]): real_gas.build(inifile, 'GPB-Phase'+str(i+1))
