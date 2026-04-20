# ICB — Initial Condition Builder

ICB is a Fortran executable that writes the initial solution field for one or more Hydra blocks at $t = 0$.

## Usage

```bash
./ICB -input icb.ini
```

## Sections

- [Input Reference](./input-reference) — INI keys and their meaning
- [IC Strategies](./ic-strategies) — Direct assignment, interpolation, and restart strategies
- [Output Files](./output) — Binary format written for Hydra

## Overview

ICB supports a range of strategies for setting initial conditions:

- **Ideal gas** — uniform or profile-based primitive variables
- **Real fluid** — initial state for real-fluid EOS phases
- **Condensed / solid particles** — dispersed-phase initial fields
- **Interpolation** — map a solution from a different grid
- **Import / restart** — read a previous Hydra solution

See the [tutorials](/tutorials/icb/) for worked examples.
