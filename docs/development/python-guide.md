# Python Development Guide

ATLAS Python tools (GPB, KAnT) are regular Python packages invoked as `python -m <Package>`.

## Prerequisites

- Python ≥ 3.9
- Required packages: `cantera`, `coolprop`, `numpy`, `pyyaml`
- `PiNeR` library (bundled in `lib/PiNeR/`)
- `ATLASDIR` environment variable set to the ATLAS root

## Environment Setup

```bash
# Using the bundled conda environment file
conda env create -f ct-env.yaml
conda activate atlas

# Or manually
pip install cantera coolprop numpy pyyaml
```

## Running

```bash
export ATLASDIR=/path/to/ATLAS

python -m GPB --input-file input.ini
python -m KAnT --input-file input.ini
```

## Source Layout

```
src/hydra-tools/
└── GPB/                   — General Phase Builder
    ├── __main__.py        — CLI entry point
    ├── config.py          — global constants (ATLASDIR, OUTPATH, ...)
    ├── input_registry.py  — INI section dispatcher
    ├── mixing_rules.py    — mixture property combinators
    ├── reactants.py       — reactants data structures
    ├── ini/               — INI parsing subpackage
    │   ├── common.py      — shared parameter parsing
    │   ├── ideal_gas.py   — ideal-gas / heavy-gas parser
    │   ├── condensed.py   — condensed / dispersed parser
    │   ├── equilibrium.py — equilibrium section parser
    │   └── real_fluid.py  — real-fluid parser
    ├── ideal_gas/         — ideal-gas builders
    │   ├── builder.py     — top-level ideal-gas build()
    │   ├── chemistry.py   — reaction mechanism helpers
    │   ├── thermo.py      — NASA-9 / CEA thermo tables
    │   ├── transport.py   — transport property tables
    │   └── io.py          — output writers
    ├── condensed/         — condensed / solid builders
    └── real_fluid/        — real-fluid builders

src/KAnT/
├── config/                — INI configuration parsing
├── data/                  — thermo / kinetics data helpers
├── output/                — result writers
├── simulations/           — simulation drivers
└── utils/                 — shared utilities
```

## PiNeR Library

GPB's INI parsing relies on the `PiNeR` library (`lib/PiNeR/`). The key helpers are:

```python
from PiNeR import get, check_section

value = get(section, "key", default="value")
check_section(section, required=["fluid"])
```

## Adding a New Phase Type

1. Add a new parser in `GPB/ini/<type>.py` following the pattern of `ideal_gas.py`.
2. Register the new `type` string in `GPB/input_registry.py`.
3. Implement `build(phase_cfg)` in `GPB/<type>/builder.py`.
4. Add a test case to `test/GPB/`.

## Code Style

- PEP 8; line length ≤ 100
- Type hints encouraged (not yet enforced project-wide)
- Module-level docstrings required for all new modules

See [Code Style](./code-style) for the full conventions.
