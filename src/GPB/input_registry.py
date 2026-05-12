"""Centralized GPB input registry and markdown documentation writer.

This module defines a compact registry of input parameters used by the
GPB tools and a helper to write a markdown reference table.
"""

from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class RegistryEntry:
    section: str
    name: str
    default: str
    allowed: str
    required: bool
    description: str


REGISTRY_ENTRIES: List[RegistryEntry] = [
    RegistryEntry(
        'GPB',
        'input-file',
        'input.ini',
        '',
        False,
        'Input INI file consumed by GPB.',
    ),
    RegistryEntry(
        'GPB-Phase*',
        'type',
        'ideal-gas',
        'ideal-gas,heavy-gas,condensed-dispersed,solid,real-fluid',
        False,
        'Phase model selector for the current section.',
    ),
    RegistryEntry(
        'GPB-Phase*', 'name', '', '', False, 'Prefix for generated output files.'
    ),
    RegistryEntry(
        'GPB-Phase*', 'Tmin', '1', '>0', False, 'Minimum tabulation temperature [K].'
    ),
    RegistryEntry(
        'GPB-Phase*', 'Tmax', '5000', '>0', False, 'Maximum tabulation temperature [K].'
    ),

    RegistryEntry(
        'GPB-IdealGas', 'phase', '', '', False,
        'Existing Cantera phase file stem (without .yaml).'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'thermo', '', 'NASA7,NASA9,Burcat', False,
        'Thermodynamic species database selector.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'transport', '', 'CEA,cantera', False,
        'Transport model source.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'reactions', '', '', False,
        'Reaction mechanism file stem (without .yaml).'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'inerts-mixing', 'False', 'True,False', False,
        'Mix equilibrium species into a single mixture phase.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'species', '', '', False, 'Manual inert species list.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'add-species', '', '', False,
        'Alternative key for manual inert species list.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'mixture', '', '', False,
        'Custom mixture composition string/dictionary.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'mixture-name', 'mix', '', False,
        'Output name for custom mixture.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'cp', '', '', False,
        'Constant-pressure specific heat array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'cv', '', '', False,
        'Constant-volume specific heat array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'gamma', '', '', False,
        'Specific-heat ratio array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'R', '', '', False,
        'Specific gas constant array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'mw', '', '', False,
        'Molecular weight array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'mil', '', '', False,
        'Dynamic viscosity array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'kl', '', '', False,
        'Thermal conductivity array for fixed-gas species.'
    ),
    RegistryEntry(
        'GPB-IdealGas', 'Pr', '', '', False,
        'Prandtl number array for fixed-gas species.'
    ),

    RegistryEntry(
        'GPB-Equilibrium', 'CEA-file', '', '', False,
        'CEA input file stem (.inp extension optional).'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'CEA-section', '1', '>=1', False,
        'Section index inside CEA output.'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-pressure', '', '', False,
        'Cantera equilibrium pressure as [value, unit].'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-fuel', '', '', False,
        'Cantera equilibrium fuel composition entry.'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-oxidizer', '', '', False,
        'Cantera equilibrium oxidizer composition entry.'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-of', '', '>0', False,
        'Cantera equilibrium oxidizer-to-fuel ratio.'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-fuel-T', '100.0', '', False,
        'Fuel inlet temperature for equilibrium setup [K].'
    ),
    RegistryEntry(
        'GPB-Equilibrium', 'eq-oxidizer-T', '90.170', '', False,
        'Oxidizer inlet temperature for equilibrium setup [K].'
    ),

    RegistryEntry(
        'GPB-Condensed', 'thermo', 'NASA9',
        'NASA7,NASA9,Burcat,SP-database', False,
        'Condensed-phase thermodynamic model selector.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'material', 'ATLAS', '', False,
        'Condensed-phase material names.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'groups', '1', '', False,
        'Group index per condensed material.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'cp', '', '', False,
        'Fixed specific heat values for condensed materials.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'k', '', '', False,
        'Fixed thermal conductivity values for condensed materials.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'rho', '', '', False,
        'Density values for condensed materials.'
    ),

    RegistryEntry(
        'GPB-RealFluid', 'fluid', '', '', True,
        'Fluid name accepted by selected real-fluid model.'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'pmin', '', '>0', True, 'Minimum pressure bound [Pa].'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'pmax', '', '>0', True, 'Maximum pressure bound [Pa].'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'Tmin', '', '>0', True, 'Minimum temperature bound [K].'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'Tmax', '', '>0', True, 'Maximum temperature bound [K].'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'NP', '200', '>=2', False, 'Number of pressure grid points.'
    ),
    RegistryEntry(
        'GPB-RealFluid', 'NH', '200', '>=2', False, 'Number of enthalpy grid points.'
    ),
    RegistryEntry(
        'GPB-RealFluid',
        'model',
        'coolprop',
        'coolprop,redlich-kwong,peng-robinson',
        False,
        'Equation-of-state model used for table generation.',
    ),
]

# For readability we also expose grouped lists per logical section so the
# registry is easy to scan at a glance. Consumers can still use
# `REGISTRY_ENTRIES` which concatenates all groups in a stable order.

GPB_GENERAL = [
    RegistryEntry('GPB', 'input-file', 'input.ini', '', False, 'Input INI file consumed by GPB.'),
]

GPB_PHASE = [
    RegistryEntry(
        'GPB-Phase*',
        'type',
        'ideal-gas',
        'ideal-gas,heavy-gas,condensed-dispersed,solid,real-fluid',
        False,
        'Phase model selector for the current section.',
    ),
    RegistryEntry('GPB-Phase*', 'name', '', '', False, 'Prefix for generated output files.'),
    RegistryEntry('GPB-Phase*', 'Tmin', '1', '>0', False, 'Minimum tabulation temperature [K].'),
    RegistryEntry('GPB-Phase*', 'Tmax', '5000', '>0', False, 'Maximum tabulation temperature [K].'),
]

GPB_IDEALGAS = [
    RegistryEntry('GPB-IdealGas', 'phase', '', '', False, 'Existing Cantera phase file stem (without .yaml).'),
    RegistryEntry('GPB-IdealGas', 'thermo', '', 'NASA7,NASA9,Burcat', False, 'Thermodynamic species database selector.'),
    RegistryEntry('GPB-IdealGas', 'transport', '', 'CEA,cantera', False, 'Transport model source.'),
    RegistryEntry('GPB-IdealGas', 'reactions', '', '', False, 'Reaction mechanism file stem (without .yaml).'),
    RegistryEntry('GPB-IdealGas', 'inerts-mixing', 'False', 'True,False', False, 'Mix equilibrium species into a single mixture phase.'),
    RegistryEntry('GPB-IdealGas', 'species', '', '', False, 'Manual inert species list.'),
    RegistryEntry('GPB-IdealGas', 'add-species', '', '', False, 'Alternative key for manual inert species list.'),
    RegistryEntry('GPB-IdealGas', 'mixture', '', '', False, 'Custom mixture composition string/dictionary.'),
    RegistryEntry('GPB-IdealGas', 'mixture-name', 'mix', '', False, 'Output name for custom mixture.'),
    RegistryEntry('GPB-IdealGas', 'cp', '', '', False, 'Constant-pressure specific heat array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'cv', '', '', False, 'Constant-volume specific heat array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'gamma', '', '', False, 'Specific-heat ratio array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'R', '', '', False, 'Specific gas constant array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'mw', '', '', False, 'Molecular weight array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'mil', '', '', False, 'Dynamic viscosity array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'kl', '', '', False, 'Thermal conductivity array for fixed-gas species.'),
    RegistryEntry('GPB-IdealGas', 'Pr', '', '', False, 'Prandtl number array for fixed-gas species.'),
]

GPB_EQUILIBRIUM = [
    RegistryEntry('GPB-Equilibrium', 'CEA-file', '', '', False, 'CEA input file stem (.inp extension optional).'),
    RegistryEntry('GPB-Equilibrium', 'CEA-section', '1', '>=1', False, 'Section index inside CEA output.'),
    RegistryEntry('GPB-Equilibrium', 'eq-pressure', '', '', False, 'Cantera equilibrium pressure as [value, unit].'),
    RegistryEntry('GPB-Equilibrium', 'eq-fuel', '', '', False, 'Cantera equilibrium fuel composition entry.'),
    RegistryEntry('GPB-Equilibrium', 'eq-oxidizer', '', '', False, 'Cantera equilibrium oxidizer composition entry.'),
    RegistryEntry('GPB-Equilibrium', 'eq-of', '', '>0', False, 'Cantera equilibrium oxidizer-to-fuel ratio.'),
    RegistryEntry('GPB-Equilibrium', 'eq-fuel-T', '100.0', '', False, 'Fuel inlet temperature for equilibrium setup [K].'),
    RegistryEntry('GPB-Equilibrium', 'eq-oxidizer-T', '90.170', '', False, 'Oxidizer inlet temperature for equilibrium setup [K].'),
]

GPB_CONDENSED = [
    RegistryEntry('GPB-Condensed', 'thermo', 'NASA9', 'NASA7,NASA9,Burcat,SP-database', False, 'Condensed-phase thermodynamic model selector.'),
    RegistryEntry('GPB-Condensed', 'material', 'ATLAS', '', False, 'Condensed-phase material names.'),
    RegistryEntry('GPB-Condensed', 'groups', '1', '', False, 'Group index per condensed material.'),
    RegistryEntry('GPB-Condensed', 'cp', '', '', False, 'Fixed specific heat values for condensed materials.'),
    RegistryEntry('GPB-Condensed', 'k', '', '', False, 'Fixed thermal conductivity values for condensed materials.'),
    RegistryEntry('GPB-Condensed', 'rho', '', '', False, 'Density values for condensed materials.'),
]

GPB_REALFLUID = [
    RegistryEntry('GPB-RealFluid', 'fluid', '', '', True, 'Fluid name accepted by selected real-fluid model.'),
    RegistryEntry('GPB-RealFluid', 'pmin', '', '>0', True, 'Minimum pressure bound [Pa].'),
    RegistryEntry('GPB-RealFluid', 'pmax', '', '>0', True, 'Maximum pressure bound [Pa].'),
    RegistryEntry('GPB-RealFluid', 'Tmin', '', '>0', True, 'Minimum temperature bound [K].'),
    RegistryEntry('GPB-RealFluid', 'Tmax', '', '>0', True, 'Maximum temperature bound [K].'),
    RegistryEntry('GPB-RealFluid', 'NP', '200', '>=2', False, 'Number of pressure grid points.'),
    RegistryEntry('GPB-RealFluid', 'NH', '200', '>=2', False, 'Number of enthalpy grid points.'),
    RegistryEntry('GPB-RealFluid', 'model', 'coolprop', 'coolprop,redlich-kwong,peng-robinson', False, 'Equation-of-state model used for table generation.'),
]


# Combined, stable registry used by existing consumers
REGISTRY_ENTRIES = (
    GPB_GENERAL
    + GPB_PHASE
    + GPB_IDEALGAS
    + GPB_EQUILIBRIUM
    + GPB_CONDENSED
    + GPB_REALFLUID
)


def write_gpb_registry_markdown(
    filename: str = 'gpb-input.md', title: str = 'ATLAS GPB Input Parameters'
) -> None:
    """Write a markdown file documenting the GPB registry entries.

    The generated file contains section headers and a table listing
    parameter names, defaults, allowed values, whether they are required,
    and a short description.
    """

    with open(filename, 'w', encoding='utf-8') as file_handle:
        file_handle.write(f'# {title}\n\n')

        current_section = None
        for entry in REGISTRY_ENTRIES:
            if entry.section != current_section:
                current_section = entry.section
                file_handle.write(f'\n## {current_section}\n\n')
                file_handle.write('| Parameter | Default | Allowed | Required | Description |\n')
                file_handle.write('|-----------|---------|---------|----------|-------------|\n')

            required_value = 'yes' if entry.required else 'no'
            file_handle.write(
                f'| {entry.name} | {entry.default} | {entry.allowed} | '
                f'{required_value} | {entry.description} |\n'
            )

