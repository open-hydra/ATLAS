##################################################
"""
GPB.py - General Phase Builder

This script is part of the ATLAS project and is responsible for building different phases based on the input file 'input.ini'. 
It imports necessary modules and checks the phases defined in the input file, then builds the corresponding phases using the 
appropriate module functions.

Modules:
    - Ideal_Gas: Handles the building of ideal and heavy gas phases.
    - Condensed_Phase: Handles the building of condensed and solid phases.
    - Read_INI: Contains the function to check phases from the input file.

Functions:
    - check_phases(inifile): Reads the input file and returns a list of phase types.

Execution:
    - Defines the input file 'input.ini'.
    - Checks the phases defined in the input file.
    - Iterates through the list of phase types and builds the corresponding phases using the appropriate module functions.
"""
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