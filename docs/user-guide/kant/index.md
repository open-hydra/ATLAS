# KAnT — Kinetics and Thermodynamics

KAnT is a Python package that runs zero-dimensional reactor simulations and thermochemical analyses. It is designed as a post-processing and validation companion to the ATLAS pre-processing suite.

## Usage

```bash
python -m KAnT --input-file kant.ini
```

## Capabilities

| Simulation type | Description |
|----------------|-------------|
| Counterflow | Counterflow diffusion flame configuration |
| Equilibrium | Chemical equilibrium composition at given $T$, $P$ |
| Ignition delay | Ignition delay time from auto-ignition |
| Ignition delay (experimental) | Compare against experimental data |
| Time evolution | Transient 0-D reactor time integration |

## Package Structure

```
src/KAnT/
├── config/       — configuration parsing
├── data/         — thermodynamic / kinetics data helpers
├── output/       — result writers
├── simulations/  — simulation drivers (one module per type)
└── utils/        — shared utilities
```

## Test Cases

Five reference cases are provided in `test/KAnT/`:

- `counterflow/`
- `equilibrium/`
- `ignition_delay/`
- `ignition_delay_exp/`
- `time_evolution/`

See the [tutorials](/tutorials/kant/) for step-by-step walkthroughs.
