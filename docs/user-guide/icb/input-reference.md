# ATLAS ICB Input Parameters

Units: every value is SI (Pa, K, J/kg, m/s); the solver dumps and the profile files are read in the same units. The key un (normal velocity) of the ICB-IG and ICB-RF tables is used by BCB only: ICB accepts it and ignores it.


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
| mach | 0.0 |  |  no | Ideal-gas Mach number: the speed of the zone, along alpha and beta (not with u, v, w). |
| mach-file |  |  |  no | Profile of mach in place of the constant (not with it): a two-column table (coordinate, value) along mach-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| mach-direction |  | x,y,z,r,t |  no | Letter of the 1-D mach-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with mach-file. |
| p0 | 0.0 |  |  no | Ideal-gas stagnation pressure: p lies on the isentrope from p0 down to T, as at the solvers' inlet. |
| p0-file |  |  |  no | Profile of p0 in place of the constant (not with it): a two-column table (coordinate, value) along p0-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| p0-direction |  | x,y,z,r,t |  no | Letter of the 1-D p0-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with p0-file. |
| T0 | 0.0 |  |  no | Ideal-gas stagnation temperature: T from h(T0) = h(T) + V^2/2, V given by mach or by u, v, w. |
| T0-file |  |  |  no | Profile of T0 in place of the constant (not with it): a two-column table (coordinate, value) along T0-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| T0-direction |  | x,y,z,r,t |  no | Letter of the 1-D T0-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with T0-file. |
| p | 0.0 |  |  no | Ideal-gas static pressure. |
| p-file |  |  |  no | Profile of p in place of the constant (not with it): a two-column table (coordinate, value) along p-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| p-direction |  | x,y,z,r,t |  no | Letter of the 1-D p-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with p-file. |
| T | 0.0 |  |  no | Ideal-gas static temperature. |
| T-file |  |  |  no | Profile of T in place of the constant (not with it): a two-column table (coordinate, value) along T-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| T-direction |  | x,y,z,r,t |  no | Letter of the 1-D T-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with T-file. |
| rho | 0.0 |  |  no | Ideal-gas density. |
| rho-file |  |  |  no | Profile of rho in place of the constant (not with it): a two-column table (coordinate, value) along rho-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| rho-direction |  | x,y,z,r,t |  no | Letter of the 1-D rho-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with rho-file. |
| alpha | 0.0 |  |  no | Flow angle [rad] in the x-y plane, from x towards y: the direction is (cos alpha cos beta, sin alpha cos beta, sin beta). |
| beta | 0.0 |  |  no | Flow angle [rad] out of the x-y plane, towards z. |
| u | 0.0 |  |  no | Prescribed x-velocity component. |
| v | 0.0 |  |  no | Prescribed y-velocity component. |
| w | 0.0 |  |  no | Prescribed z-velocity component. |
| un | 0.0 |  |  no | Prescribed normal velocity component. |
| nuTilde | 0.0 |  |  no | Spalart-Allmaras working variable nu_tilde [m2/s] (not the eddy viscosity), specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoNuTilde. |
| k | 0.0 |  |  no | Turbulent kinetic energy k [m2/s2], specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoK. |
| omega | 0.0 |  |  no | Specific dissipation rate omega [1/s], specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoOmega. |
| Rij | 0.0 |  |  no | Normal Reynolds stresses R11 = R22 = R33 [m2/s2], specific, one value for the three (the shear stresses are set to 1e-8). ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoRij. |
| rhoNuTilde | 0.0 |  |  no | Density-weighted Spalart-Allmaras working variable rho*nu_tilde [kg/(m s)]. ICB writes it as given (the band of the IC file). Give it or the specific nuTilde. |
| rhoK | 0.0 |  |  no | Density-weighted turbulent kinetic energy rho*k [kg/(m s2)]. ICB writes it as given (the band of the IC file). Give it or the specific k. |
| rhoOmega | 0.0 |  |  no | Density-weighted specific dissipation rate rho*omega [kg/(m3 s)]. ICB writes it as given (the band of the IC file). Give it or the specific omega. |
| rhoRij | 0.0 |  |  no | Density-weighted normal Reynolds stresses rho*Rij [kg/(m s2)], one value for the three (the shear stresses are set to 1e-8). ICB writes it as given (the band of the IC file). Give it or the specific Rij. |
| nrans | 0 | >=0 |  no | Explicit turbulence model size override. |
| old-solution |  |  |  no | Previous solution file used for interpolation. |
| old-block-id | 0 | >=0 |  no | Source block index for interpolation. Zero means auto. |
| interpolation-law | outlaw | outlaw<br>index<br>multiple<br>minimum_distance<br>spherical_minimum_distance<br>extrude |  no | Interpolation mapping law (outlaw = not given: minimum_distance; index revolves a 2D source onto a target revolved with the same cells; extrude revolves a 2D source about x through theta degrees in nz cells, then each target cell takes the nearest revolved cell). |
| theta | 90.0 |  |  no | Angle in degrees of the sector into which the extrude law revolves the 2D source (from the source plane towards +z). |
| nz | 4 | >=1 |  no | Number of cells of the sector built by the extrude law. |
| old-species |  |  |  no | Species list of the old solution for IG interpolation: a directory (old/, reads old/<phase>phase.txt) or a file prefix (old-, reads old-<phase>phase.txt in the case directory; the launcher then also finds old-phase.txt and writes a header-only old-ic.tec). |
| nozzle-direction | dx | dx,sx |  no | Nozzle marching direction. |
| nozzle-threshold | 0.0 |  |  no | Coordinate threshold separating plenum and nozzle. |
| yspecies-file |  |  |  no | Mass-fraction profile of the species named by the suffix (y<species>-file, in place of the constant y<species>): a Tecplot field on the block grid, or a two-column table (coordinate, y) along y<species>-direction; read like T-file, it makes the zone variable. |
| yspecies-direction |  | x,y,z,r,t |  no | Direction of the 1D y<species>-file table. |

## ICB-RF

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| p | 0.0 |  |  no | Real-fluid pressure. |
| p-file |  |  |  no | Profile of p in place of the constant (not with it): a two-column table (coordinate, value) along p-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| p-direction |  | x,y,z,r,t |  no | Letter of the 1-D p-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with p-file. |
| T | 0.0 |  |  no | Real-fluid temperature. |
| T-file |  |  |  no | Profile of T in place of the constant (not with it): a two-column table (coordinate, value) along T-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| T-direction |  | x,y,z,r,t |  no | Letter of the 1-D T-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with T-file. |
| h | 0.0 |  |  no | Real-fluid enthalpy. |
| h-file |  |  |  no | Profile of h in place of the constant (not with it): a two-column table (coordinate, value) along h-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| h-direction |  | x,y,z,r,t |  no | Letter of the 1-D h-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with h-file. |
| vel | 0.0 |  |  no | Real-fluid speed magnitude. |
| vel-file |  |  |  no | Profile of vel in place of the constant (not with it): a two-column table (coordinate, value) along vel-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| vel-direction |  | x,y,z,r,t |  no | Letter of the 1-D vel-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with vel-file. |
| alpha | 0.0 |  |  no | Flow angle [rad] in the x-y plane, from x towards y: the direction is (cos alpha cos beta, sin alpha cos beta, sin beta). |
| beta | 0.0 |  |  no | Flow angle [rad] out of the x-y plane, towards z. |
| u | 0.0 |  |  no | Prescribed x-velocity component. |
| v | 0.0 |  |  no | Prescribed y-velocity component. |
| w | 0.0 |  |  no | Prescribed z-velocity component. |
| un | 0.0 |  |  no | Prescribed normal velocity component. |
| nuTilde | 0.0 |  |  no | Spalart-Allmaras working variable nu_tilde [m2/s] (not the eddy viscosity), specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoNuTilde. |
| k | 0.0 |  |  no | Turbulent kinetic energy k [m2/s2], specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoK. |
| omega | 0.0 |  |  no | Specific dissipation rate omega [1/s], specific. ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoOmega. |
| Rij | 0.0 |  |  no | Normal Reynolds stresses R11 = R22 = R33 [m2/s2], specific, one value for the three (the shear stresses are set to 1e-8). ICB multiplies it by the cell density (ideal-gas zone; refused in a real-fluid zone, whose table carries no density). Give it or the density-weighted rhoRij. |
| rhoNuTilde | 0.0 |  |  no | Density-weighted Spalart-Allmaras working variable rho*nu_tilde [kg/(m s)]. ICB writes it as given (the band of the IC file). Give it or the specific nuTilde. |
| rhoK | 0.0 |  |  no | Density-weighted turbulent kinetic energy rho*k [kg/(m s2)]. ICB writes it as given (the band of the IC file). Give it or the specific k. |
| rhoOmega | 0.0 |  |  no | Density-weighted specific dissipation rate rho*omega [kg/(m3 s)]. ICB writes it as given (the band of the IC file). Give it or the specific omega. |
| rhoRij | 0.0 |  |  no | Density-weighted normal Reynolds stresses rho*Rij [kg/(m s2)], one value for the three (the shear stresses are set to 1e-8). ICB writes it as given (the band of the IC file). Give it or the specific Rij. |
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
| T-file |  |  |  no | Profile of T in place of the constant (not with it): a two-column table (coordinate, value) along T-direction, covering the cell centres of the zone, or without it a Tecplot field (.tec, .szplt) on a structured grid, each cell taking the first variable of the nearest cell. |
| T-direction |  | x,y,z,r,t |  no | Letter of the 1-D T-file table: x, y, z, or r and t about the x axis (in the x-y plane on a 2-D mesh; t in degrees); only with T-file. |
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
