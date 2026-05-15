# Python Development Guide

ATLAS Python tools (GPB, KAnT) are regular Python packages invoked as `python -m <Package>`.

## Prerequisites

- Python ≥ 3.9
- Required packages: `cantera`, `coolprop`, `numpy<2`, `pyyaml`
- `PiNeR` library (bundled in `lib/PiNeR/`)
- `ATLASDIR` environment variable set to the ATLAS root
- Bundled conda environment: `ct-env`

## Environment Setup

```bash
# Using the bundled conda environment file
conda env create -f ct-env.yaml
conda activate ct-env

# Or install requirements manually with pip
pip install cantera coolprop 'numpy<2' pyyaml

# Set ATLAS environment variable (required by GPB)
export ATLASDIR=/path/to/ATLAS
```

## Running Tools

### General Phase Builder (GPB)

```bash
export ATLASDIR=/path/to/ATLAS
python -m GPB --input-file input.ini

# View configuration template
python -m GPB --write-config-doc > template.ini
```

### KAnT (Future)
Once implemented:
```bash
python -m KAnT --input-file input.ini
```

## Source Layout

```
src/
├── GPB/                       # General Phase Builder
│   ├── __main__.py            # CLI entry point: argparse setup
│   ├── __init__.py            # Package initialization
│   ├── config.py              # Global constants: ATLASDIR, OUTPATH
│   ├── input_registry.py      # INI section dispatcher
│   ├── mixing_rules.py        # Mixture property combinators
│   ├── reactants.py           # Reactant species data structures
│   ├── ini/                   # INI parsing subpackage
│   │   ├── common.py          # Shared parameter parsing
│   │   ├── ideal_gas.py       # Ideal-gas / heavy-gas parser
│   │   ├── condensed.py       # Condensed / dispersed parser
│   │   ├── equilibrium.py     # Equilibrium section parser
│   │   └── real_fluid.py      # Real-fluid parser
│   ├── ideal_gas/             # Ideal-gas builders
│   │   ├── builder.py         # Top-level build(phase_cfg) dispatcher
│   │   ├── chemistry.py       # Reaction mechanism helpers
│   │   ├── thermo.py          # NASA-9 / CEA thermo tables
│   │   ├── transport.py       # Transport property tables
│   │   └── io.py              # Output file writers (CEA format, CSV, etc.)
│   ├── condensed/             # Condensed / solid phase builders
│   └── real_fluid/            # Real-fluid builders
└── common/                    # Shared Python utilities (if any)
```

## PiNeR Library

GPB's INI parsing relies on the `PiNeR` library (`lib/PiNeR/`). The key helpers are:

```python
from PiNeR import get, check_section

value = get(section, "key", default="value")
check_section(section, required=["fluid"])
```

## Adding a New Phase Type

To add support for a new thermodynamic phase (e.g., multiphase mixtures):

1. **Create INI parser** in `GPB/ini/<type>.py`:
   ```python
   from PiNeR import get, check_section
   
   def parse_multiphase(section):
       """Parse [MultiphasePhase] INI section."""
       check_section(section, required=['fluid1', 'fluid2'])
       return {
           'fluid1': get(section, 'fluid1'),
           'fluid2': get(section, 'fluid2'),
           'ratio': float(get(section, 'ratio', '0.5'))
       }
   ```

2. **Register in dispatcher** (`GPB/input_registry.py`):
   ```python
   elif phase_type == 'MultiphasePhase':
       phase_cfg = ini.multiphase.parse_multiphase(section)
   ```

3. **Implement builder** in `GPB/multiphase/builder.py`:
   ```python
   def build(phase_cfg):
       """Build multiphase mixture."""
       # Implementation...
       return result
   ```

4. **Add tests** in `test/GPB/test_multiphase.py` using `pytest`

5. **Document** in docstrings and update [Python Package Reference](./python-packages)

## Code Style

ATLAS Python code follows **PEP 8** with additional conventions:

- **Line length**: ≤ 100 characters
- **Type hints**: Encouraged for public APIs (not yet fully enforced project-wide)
- **Docstrings**: Required for all module-level and public function definitions
- **Imports**: Organize as standard library, third-party, then local imports
- **Configuration**: Use `config.py` for global constants (`ATLASDIR`, `OUTPATH`, etc.)

### Example Module with Docstrings

```python
"""Phase builder for ideal gas mixtures.

This module provides the build() function to construct ideal gas phase
configurations from INI specifications.
"""

from typing import Dict, List
import numpy as np
from cantera import Solution

def build(phase_cfg: Dict) -> Solution:
    """Build Cantera ideal gas solution object.
    
    Args:
        phase_cfg: Dictionary with 'fuel', 'oxidizer', 'temperature' keys
    
    Returns:
        Initialized Cantera Solution object
    """
    # Implementation...
    pass
```
