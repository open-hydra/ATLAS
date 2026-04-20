"""GPB entry point for `python -m GPB` invocation."""
import argparse

from input_registry import write_gpb_registry_markdown

print()
print(' ATLAS - General Phase Builder ')
print()

parser = argparse.ArgumentParser(add_help=True)
parser.add_argument('--input-file', dest='input_file', default='input.ini',
                    help='Input INI file path (default: input.ini).')
parser.add_argument('--write-config-doc', action='store_true',
                    help='Generate GPB input documentation and exit.')

args = parser.parse_args()

if args.write_config_doc:
    write_gpb_registry_markdown('gpb-input.md')
    print(' GPB input documentation written to gpb-input.md')
    raise SystemExit(0)

import ideal_gas
import condensed
import real_fluid
from ini import load_phase_definitions

inifile = args.input_file
phase_definitions = load_phase_definitions(inifile)

for phase in phase_definitions:
    phase_type = phase.phase_type.lower()
    if ('ideal' in phase_type or 'heavy' in phase_type):
        ideal_gas.build(inifile, phase.section)
    if ('condensed' in phase_type):
        condensed.build(phase_type, inifile, phase.section)
    if ('solid' in phase_type):
        condensed.build(phase_type, inifile, phase.section)
    if ('real' in phase_type):
        real_fluid.build(inifile, phase.section)
