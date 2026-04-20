# BCB — Boundary Condition Builder

BCB is a Fortran executable that reads mesh and BC specification files and produces the binary boundary-condition block files required by Hydra.

## Usage

```bash
./BCB -input bcb.ini
```

## Sections

- [Input Reference](./input-reference) — INI keys and their meaning
- [BC Types](./bc-types) — Available boundary condition types (inlet, outlet, wall, periodic, chimera, …)
- [Output Files](./output) — Binary format written for Hydra

## Overview

BCB processes each boundary face group defined in the mesh and assigns conditions based on the user-supplied INI file. It supports:

- Standard single-patch connections
- Multi-patch configurations
- Chimera (overset) connections
- Periodic conditions

See the [tutorials](/tutorials/bcb/) for worked examples.
