# Acknowledgements

ATLAS is built upon several open-source libraries and tools.

## Core Libraries

### FiNeR

**Fortran INI ParseR and generator**

- **Repository:** [github.com/szaghi/FiNeR](https://github.com/szaghi/FiNeR)
- **License:** GPL v3.0

FiNeR is a pure Fortran 2003+ OOP library for reading and writing INI configuration files. ATLAS uses FiNeR in its Fortran solvers to parse structured input files.

### ORION

**I/O Library for Fortran**

- **Repository:** [github.com/MarcoGrossi92/ORION](https://github.com/MarcoGrossi92/ORION)
- **License:** GPL v3.0

ORION provides built-in functions to read files in different formats. ATLAS uses ORION in its Fortran-based tools to import thermodynamic, transport, and chemistry tabulated data.

### NASA CEA

**Python/Fortran interface to NASA CEA**

- **Repository:** [github.com/nasa/cea](https://github.com/nasa/cea)
- **License:** Apache License v2.0

NASA CEA (Chemical Equilibrium with Applications) Fortran solver with a Python interface. ATLAS uses it in different tools to compute chemical equilibrium compositions from propellant definitions.

### PiNeR

**Python INI parseR**

- **Repository:** [github.com/MarcoGrossi92/PiNeR](https://github.com/MarcoGrossi92/PiNeR)
- **License:** MIT

PiNeR is a lightweight Python package for reading INI configuration files. GPB and KAnT use PiNeR to parse `input.ini` files at runtime.

---

## Python Scientific Stack

### Cantera

**Chemical Kinetics and Thermodynamics**

- **Website:** [cantera.org](https://cantera.org)
- **License:** BSD-3-Clause

Cantera is an open-source suite of tools for problems involving chemical kinetics, thermodynamics, and transport. ATLAS relies on Cantera in KAnT for 0D/1D reactive-flow simulations (ignition delay, flame speed, equilibrium) and in GPB for ideal-gas thermodynamic and transport property evaluation.

### NumPy

**Numerical Computing**

- **Website:** [numpy.org](https://numpy.org)
- **License:** BSD-3-Clause

NumPy provides the fundamental array operations used throughout GPB and KAnT for property calculations and data handling.

### Matplotlib

**Plotting and Visualization**

- **Website:** [matplotlib.org](https://matplotlib.org)
- **License:** PSF-based

Matplotlib is used in KAnT to generate plots of simulation results such as ignition delay curves, temperature profiles, and flame structures.

### CoolProp

**Real-Fluid Thermodynamic Properties**

- **Website:** [coolprop.org](http://www.coolprop.org)
- **License:** MIT

CoolProp provides accurate thermodynamic and transport properties for a wide range of real fluids via equations of state. ATLAS uses CoolProp in GPB's real-fluid phase to evaluate properties beyond the ideal-gas limit.

### Pint

**Physical Units**

- **Website:** [pint.readthedocs.io](https://pint.readthedocs.io)
- **License:** BSD-3-Clause

Pint handles physical unit parsing and conversion in the GPB input system, allowing users to specify quantities in natural engineering units.

---

## Documentation Tools

### MkDocs

**Static Site Generator**

- **Website:** [mkdocs.org](https://www.mkdocs.org)
- **License:** BSD-2-Clause

MkDocs transforms ATLAS's documentation into a searchable static website.

### Material for MkDocs

**Modern Documentation Theme**

- **Website:** [squidfunk.github.io/mkdocs-material](https://squidfunk.github.io/mkdocs-material/)
- **License:** MIT

Material for MkDocs provides the theme used by this documentation site.

---

## License Compliance

ATLAS respects all licenses of its dependencies:

- **GPL v3.0** — FiNeR, ORION
- **Apache License v2.0** — NASA CEA
- **MIT** — PiNeR, CoolProp, Material for MkDocs
- **BSD-3-Clause** — Cantera, NumPy, Pint
- **BSD-2-Clause** — MkDocs

See the [License](license.md) page for ATLAS's own license text.

---