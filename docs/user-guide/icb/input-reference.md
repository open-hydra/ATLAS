# ATLAS ICB Input Parameters


## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| ICB-file | input.ini |  |  no | INI file containing ICB block definitions. |
| IC-format | tec | tec<br>tec-binary<br>vtk<br>vtk-binary<br>vtk-ascii<br>vtk-raw |  no | Output format used when writing initial conditions: a family (tec, tecplot, vtk) with an optional mode (binary, ascii, raw) joined by -, blank or _ (tecplot binary, vtk binary, tecplot-ascii are accepted); a binary Tecplot file (.szplt) needs a TecIO build. |
| strict-keys | T |  |  no | F turns the error on a key the tool does not read (or not honoured by the resolved BC type, or y of an undeclared species) into a WARNING; wrong values are always errors (keys with the prefix ignore- are never read). |

## ICB-Block*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| phase |  |  |  no | Space-separated phase names. Blank means all phases. |
| type | homogeneous | homogeneous<br>variable<br>interpolation<br>nozzle<br>multizone |  no | Initialisation type of the block or zone (multizone: the block takes its state from its zone<n> sections; the key direction alone makes a block multizone). |
| direction |  |  |  no | Range directions using x,y,z,r,t,i,j,k. |
| range | 0.0 |  |  no | Range limits for the selected directions. |
| zone<n> |  |  |  no | Referenced auxiliary zone section for multizone setup. |
| range<n> | 0.0 |  |  no | Range associated with zone<n>. |

## ICB-Composition

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| eq-OG | F |  |  no | Keep only the gaseous products of the CEA equilibrium of `eq-CEA-file`: the condensed products are dropped and the mass fractions of the gaseous ones are renormalised to 1. |
| eq-CEA-file |  |  |  no | CEA input file used to derive equilibrium composition. |
| eq-CEA-section | 1 | >=1 |  no | CEA section index used when eq-CEA-file is provided. |
| yspecies | 0.0 |  |  no | Mass fraction assigned to a species name suffix: one number in [0, 1]. |

## ICB-IG

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| mach | 0.0 |  |  no | Ideal-gas Mach number. |
| mach-file |  |  |  no | File-backed input for mach. |
| mach-direction |  | x,y,z,r,t |  no | Direction for 1D mach profiles. |
| p0 | 0.0 |  |  no | Ideal-gas stagnation pressure. |
| p0-file |  |  |  no | File-backed input for p0. |
| p0-direction |  | x,y,z,r,t |  no | Direction for 1D p0 profiles. |
| T0 | 0.0 |  |  no | Ideal-gas stagnation temperature. |
| T0-file |  |  |  no | File-backed input for T0. |
| T0-direction |  | x,y,z,r,t |  no | Direction for 1D T0 profiles. |
| p | 0.0 |  |  no | Ideal-gas static pressure. |
| p-file |  |  |  no | File-backed input for p. |
| p-direction |  | x,y,z,r,t |  no | Direction for 1D p profiles. |
| T | 0.0 |  |  no | Ideal-gas static temperature. |
| T-file |  |  |  no | File-backed input for T. |
| T-direction |  | x,y,z,r,t |  no | Direction for 1D T profiles. |
| rho | 0.0 |  |  no | Ideal-gas density. |
| rho-file |  |  |  no | File-backed input for rho. |
| rho-direction |  | x,y,z,r,t |  no | Direction for 1D rho profiles. |
| alpha | 0.0 |  |  no | Velocity angle alpha. |
| beta | 0.0 |  |  no | Velocity angle beta. |
| u | 0.0 |  |  no | Prescribed x-velocity component. |
| v | 0.0 |  |  no | Prescribed y-velocity component. |
| w | 0.0 |  |  no | Prescribed z-velocity component. |
| un | 0.0 |  |  no | Prescribed normal velocity component. |
| mit | 0.0 |  |  no | Turbulence intensity for 1-equation models. |
| kappa | 0.0 |  |  no | Turbulent kinetic energy. |
| omega | 0.0 |  |  no | Specific dissipation rate. |
| rhoRij | 0.0 |  |  no | Reynolds-stress tensor magnitude. |
| nrans | 0 | >=0 |  no | Explicit turbulence model size override. |
| old-solution |  |  |  no | Previous solution file used for interpolation. |
| old-block-id | 0 | >=0 |  no | Source block index for interpolation. Zero means auto. |
| interpolation-law | outlaw | outlaw<br>index<br>multiple<br>minimum_distance<br>spherical_minimum_distance<br>extrude |  no | Interpolation mapping law (outlaw = not given: minimum_distance; index revolves a 2D source onto a target revolved with the same cells; extrude revolves a 2D source about x through theta degrees in nz cells, then each target cell takes the nearest revolved cell). |
| theta | 90.0 |  |  no | Angle in degrees of the sector into which the extrude law revolves the 2D source (from the source plane towards +z). |
| nz | 4 | >=1 |  no | Number of cells of the sector built by the extrude law. |
| nozzle-direction | dx | dx,sx |  no | Nozzle marching direction. |
| nozzle-threshold | 0.0 |  |  no | Coordinate threshold separating plenum and nozzle. |

## ICB-RF

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| p | 0.0 |  |  no | Real-fluid pressure. |
| p-file |  |  |  no | File-backed input for p. |
| p-direction |  | x,y,z,r,t |  no | Direction for 1D p profiles. |
| T | 0.0 |  |  no | Real-fluid temperature. |
| T-file |  |  |  no | File-backed input for T. |
| T-direction |  | x,y,z,r,t |  no | Direction for 1D T profiles. |
| h | 0.0 |  |  no | Real-fluid enthalpy. |
| h-file |  |  |  no | File-backed input for h. |
| h-direction |  | x,y,z,r,t |  no | Direction for 1D h profiles. |
| vel | 0.0 |  |  no | Real-fluid speed magnitude. |
| vel-file |  |  |  no | File-backed input for vel. |
| vel-direction |  | x,y,z,r,t |  no | Direction for 1D vel profiles. |
| alpha | 0.0 |  |  no | Velocity angle alpha. |
| beta | 0.0 |  |  no | Velocity angle beta. |
| u | 0.0 |  |  no | Prescribed x-velocity component. |
| v | 0.0 |  |  no | Prescribed y-velocity component. |
| w | 0.0 |  |  no | Prescribed z-velocity component. |
| un | 0.0 |  |  no | Prescribed normal velocity component. |
| mit | 0.0 |  |  no | Turbulence intensity for 1-equation models. |
| kappa | 0.0 |  |  no | Turbulent kinetic energy. |
| omega | 0.0 |  |  no | Specific dissipation rate. |
| rhoRij | 0.0 |  |  no | Reynolds-stress tensor magnitude. |
| nrans | 0 | >=0 |  no | Explicit turbulence model size override. |
| old-solution |  |  |  no | Previous solution file used for interpolation. |
| old-block-id | 0 | >=0 |  no | Source block index for interpolation. Zero means auto. |
| interpolation-law | outlaw | outlaw<br>index<br>multiple<br>minimum_distance<br>spherical_minimum_distance<br>extrude |  no | Interpolation mapping law (outlaw = not given: minimum_distance; index revolves a 2D source onto a target revolved with the same cells; extrude revolves a 2D source about x through theta degrees in nz cells, then each target cell takes the nearest revolved cell). |
| theta | 90.0 |  |  no | Angle in degrees of the sector into which the extrude law revolves the 2D source (from the source plane towards +z). |
| nz | 4 | >=1 |  no | Number of cells of the sector built by the extrude law. |

## ICB-SP

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| T | 0.0 |  |  no | Solid temperature. |
| T-file |  |  |  no | File-backed input for T. |
| T-direction |  | x,y,z,r,t |  no | Direction for 1D T profiles. |
| material |  |  |  no | Solid material name from the phase database. |
| old-solution |  |  |  no | Previous solution file used for interpolation. |
| old-block-id | 0 | >=0 |  no | Source block index for interpolation. Zero means auto. |
| interpolation-law | outlaw | outlaw<br>index<br>multiple<br>minimum_distance<br>spherical_minimum_distance<br>extrude |  no | Interpolation mapping law (outlaw = not given: minimum_distance; index revolves a 2D source onto a target revolved with the same cells; extrude revolves a 2D source about x through theta degrees in nz cells, then each target cell takes the nearest revolved cell). |
| theta | 90.0 |  |  no | Angle in degrees of the sector into which the extrude law revolves the 2D source (from the source plane towards +z). |
| nz | 4 | >=1 |  no | Number of cells of the sector built by the extrude law. |

## ICB-DP

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| krho | 0.0 |  |  no | Per-population density ratios relative to IG density. |
| kT | 1.0 |  |  no | Per-population temperature ratios. |
| Pp | 0.0 |  |  no | Per-population pseudo-pressure values. |
| dp | 0.0 |  |  no | Per-population particle diameters. |
| rp | 0.0 |  |  no | Per-population particle radii. Use as an alternative to dp. |
| neuler | 0 |  |  no | Eulerian model selector for dispersed phase support fields. |
| old-solution |  |  |  no | Previous solution file used for interpolation. |
| old-block-id | 0 | >=0 |  no | Source block index for interpolation. Zero means auto. |
| interpolation-law | outlaw | outlaw<br>index<br>multiple<br>minimum_distance<br>spherical_minimum_distance<br>extrude |  no | Interpolation mapping law (outlaw = not given: minimum_distance; index revolves a 2D source onto a target revolved with the same cells; extrude revolves a 2D source about x through theta degrees in nz cells, then each target cell takes the nearest revolved cell). |
| theta | 90.0 |  |  no | Angle in degrees of the sector into which the extrude law revolves the 2D source (from the source plane towards +z). |
| nz | 4 | >=1 |  no | Number of cells of the sector built by the extrude law. |
