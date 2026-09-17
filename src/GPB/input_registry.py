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
        'ideal-gas,heavy-gas,condensed-dispersed,liquid-dispersed,solid-dispersed,solid,solid-bulk,real-fluid',
        False,
        'Phase model selector for the current section.',
    ),
    RegistryEntry(
        'GPB-Phase*',
        'modeling',
        '',
        'lagrangian,eulerian',
        False,
        'Dispersed phase treatment the solver will use; written on line 1 of <name>phase.txt as modeling=<value>.',
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
        'GPB-Condensed', 'h0', '', '', False,
        'Optional enthalpy at 298.15 K [J/kg], one per fixed-cp material; makes the Enthalpy column absolute (`h = cp*T + h0 - cp*298.15`, header Enthalpy_abs).'
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
        'GPB-Condensed', 'evaporation', '', 'd2-law,CEM,CEM-B,ASM,TC', False,
        'Per-material override of the global evaporation model.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'liquid-conduction', '', 'ITC,P2T', False,
        'Per-material override of the liquid-side conduction model.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'interface', '', 'VLE,LK', False,
        'Per-material override of the interface model.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'boiling', '', 'clamp,ZGR', False,
        'Per-material override of the boiling branch.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'combustion', '', 'Beckstead', False,
        'Metal combustion model; presence switches this material to the metal track (mutually exclusive with evaporation and breakup).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'solidification', '', 'on,off', False,
        'Solidification with supercooling/recalescence; not implemented yet (phase M3).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'alpha-e', '', '', False,
        'Langmuir-Knudsen evaporation accommodation coefficient (interface=LK).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'k-liq', '', '', False,
        'Liquid thermal conductivity [W/m/K] (required if liquid-conduction=P2T).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'mu-liq', '', '', False,
        'Liquid viscosity [Pa s] (liquid-conduction=P2T).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'K-burn', '', '', False,
        'Beckstead d^n burn-rate coefficient K at X-eff=1 [m^n-burn/s]; required > 0 with combustion=Beckstead.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'n-burn', '', '', False,
        'Beckstead burn-law diameter exponent (nominal 1.8, range 1.5-1.8).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'X-eff', '', '', False,
        'Effective oxidizer mole fraction C_O2 + 0.6 C_H2O + 0.22 C_CO2; weights K as X-eff (linear) [Beck05].'
    ),
    RegistryEntry(
        'GPB-Condensed', 'beta-part', '', '', False,
        'Heat-partition fraction of q-comb released to the particle (weakly constrained; see theory/combustion).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'xi-cap', '', '', False,
        'Oxide-cap mass fraction retained on the burning particle.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'T-ign', '', '', False,
        'Ignition temperature [K]; the particle is inert (mdot=0) below it.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'q-comb', '', '', False,
        'Heat of combustion per unit Al mass [J/kg]; particle heating term = beta-part*q-comb*abs(mdot).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'T-melt', '', '', False,
        'Melt temperature [K] (default: alumina).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'h-fus', '', '', False,
        'Heat of fusion [J/kg] (solidification).'
    ),
    RegistryEntry(
        'GPB-Condensed', 'T-nuc', '', '', False,
        'Nucleation (supercooling) temperature [K]; absent or 0 = 0.8*T-melt.'
    ),
    RegistryEntry(
        'GPB-Condensed', 'cp-solid', '', '', False,
        'Solid-phase specific heat [J/kg/K] (solidification).'
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
        'ideal-gas,heavy-gas,condensed-dispersed,liquid-dispersed,solid-dispersed,solid,solid-bulk,real-fluid',
        False,
        'Phase model selector for the current section.',
    ),
    RegistryEntry('GPB-Phase*', 'modeling', '', 'lagrangian,eulerian', False, 'Dispersed phase treatment the solver will use; written on line 1 of <name>phase.txt as modeling=<value>.'),
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
    RegistryEntry('GPB-Condensed', 'h0', '', '', False, 'Optional enthalpy at 298.15 K [J/kg], one per fixed-cp material; makes the Enthalpy column absolute (`h = cp*T + h0 - cp*298.15`, header Enthalpy_abs).'),
    RegistryEntry('GPB-Condensed', 'cp', '', '', False, 'Fixed specific heat values for condensed materials.'),
    RegistryEntry('GPB-Condensed', 'k', '', '', False, 'Fixed thermal conductivity values for condensed materials.'),
    RegistryEntry('GPB-Condensed', 'rho', '', '', False, 'Density values for condensed materials.'),
    RegistryEntry('GPB-Condensed', 'evaporation', '', 'd2-law,CEM,CEM-B,ASM,TC', False, 'Per-material override of the global evaporation model.'),
    RegistryEntry('GPB-Condensed', 'liquid-conduction', '', 'ITC,P2T', False, 'Per-material override of the liquid-side conduction model.'),
    RegistryEntry('GPB-Condensed', 'interface', '', 'VLE,LK', False, 'Per-material override of the interface model.'),
    RegistryEntry('GPB-Condensed', 'boiling', '', 'clamp,ZGR', False, 'Per-material override of the boiling branch.'),
    RegistryEntry('GPB-Condensed', 'combustion', '', 'Beckstead', False, 'Metal combustion model; presence switches this material to the metal track (mutually exclusive with evaporation and breakup).'),
    RegistryEntry('GPB-Condensed', 'solidification', '', 'on,off', False, 'Solidification with supercooling/recalescence; not implemented yet (phase M3).'),
    RegistryEntry('GPB-Condensed', 'alpha-e', '', '', False, 'Langmuir-Knudsen evaporation accommodation coefficient (interface=LK).'),
    RegistryEntry('GPB-Condensed', 'k-liq', '', '', False, 'Liquid thermal conductivity [W/m/K] (required if liquid-conduction=P2T).'),
    RegistryEntry('GPB-Condensed', 'mu-liq', '', '', False, 'Liquid viscosity [Pa s] (liquid-conduction=P2T).'),
    RegistryEntry('GPB-Condensed', 'K-burn', '', '', False, 'Beckstead d^n burn-rate coefficient K at X-eff=1 [m^n-burn/s]; required > 0 with combustion=Beckstead.'),
    RegistryEntry('GPB-Condensed', 'n-burn', '', '', False, 'Beckstead burn-law diameter exponent (nominal 1.8, range 1.5-1.8).'),
    RegistryEntry('GPB-Condensed', 'X-eff', '', '', False, 'Effective oxidizer mole fraction C_O2 + 0.6 C_H2O + 0.22 C_CO2; weights K as X-eff (linear) [Beck05].'),
    RegistryEntry('GPB-Condensed', 'beta-part', '', '', False, 'Heat-partition fraction of q-comb released to the particle (weakly constrained; see theory/combustion).'),
    RegistryEntry('GPB-Condensed', 'xi-cap', '', '', False, 'Oxide-cap mass fraction retained on the burning particle.'),
    RegistryEntry('GPB-Condensed', 'T-ign', '', '', False, 'Ignition temperature [K]; the particle is inert (mdot=0) below it.'),
    RegistryEntry('GPB-Condensed', 'q-comb', '', '', False, 'Heat of combustion per unit Al mass [J/kg]; particle heating term = beta-part*q-comb*abs(mdot).'),
    RegistryEntry('GPB-Condensed', 'T-melt', '', '', False, 'Melt temperature [K] (default: alumina).'),
    RegistryEntry('GPB-Condensed', 'h-fus', '', '', False, 'Heat of fusion [J/kg] (solidification).'),
    RegistryEntry('GPB-Condensed', 'T-nuc', '', '', False, 'Nucleation (supercooling) temperature [K]; absent or 0 = 0.8*T-melt.'),
    RegistryEntry('GPB-Condensed', 'cp-solid', '', '', False, 'Solid-phase specific heat [J/kg/K] (solidification).'),
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

