# Introduction

ATLAS (**A**dvanced **T**ooling for hydra **L**aunch and **A**nalysi**S**) is a pre-processing toolchain for the Hydra multi-physics solver. It prepares every data file that Hydra reads at startup: phase thermodynamics, boundary conditions, initial conditions, and solver geometry.

## Architecture

ATLAS is split into independent tools that are called in sequence before a Hydra run:

```
  [ GPB ]  →  phase property tables
  [ BCB ]  →  boundary condition blocks
  [ ICB ]  →  initial condition blocks
  [ STB ]  →  geometry / area schedule
               ↓
           Hydra solver
```

Each tool reads a dedicated INI (Fortran-based tools) or `.ini` / YAML (Python-based tools) configuration file and writes binary/ASCII output consumed by Hydra. Tools are **independent**: you can run them in any order once their inputs are ready.

## Language Stack

ATLAS maintains two language tracks in the same repository and build system:

- **Fortran 2008** — BCB, ICB, STB; Fortran libraries (ORION, NewCEA, …)
- **Python 3** — GPB, KAnT; installed as importable packages

See [System Requirements](./requirements) for compiler and interpreter versions.

## Next Steps

1. [Check Requirements](./requirements)
2. [Install ATLAS](./installation)
3. [Run your first case](./quick-start)

