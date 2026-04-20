# ATLAS Tools — User Guide

This section documents the purpose, configuration, and output of each ATLAS pre-processing tool.

## Tool Summary

| Tool | Language | Role |
|------|----------|------|
| [GPB](/user-guide/gpb/) | Python | Build thermodynamic / transport property tables for each phase |
| [BCB](/user-guide/bcb/) | Fortran | Build boundary-condition blocks |
| [ICB](/user-guide/icb/) | Fortran | Build initial-condition fields |
| [STB](/user-guide/stb/) | Fortran | Pre-process geometry (area schedules, cross-sections) |
| [KAnT](/user-guide/kant/) | Python | 0-D kinetics & thermodynamics post-processing |

## Common Workflow

```bash
export ATLASDIR=/path/to/ATLAS

# 1 — build phase property tables
python -m GPB --input-file gpb.ini

# 2 — build boundary condition blocks
./BCB -input bcb.ini

# 3 — build initial condition fields
./ICB -input icb.ini

# 4 — (optional) geometry pre-processing
./STB -input stb.ini
```

Each tool is self-contained; the order shown above is typical for a cold-start Hydra simulation case.
