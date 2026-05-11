# BCB Input Parameters


## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| BCB-file | input.ini |  |  no | INI file containing BCB block and boundary definitions. |
| BC-force-connect | T |  |  no | Force standard connection matching when chimera is off. |
| BC-chimera | F |  |  no | Enable chimera connectivity instead of standard matching. |

## BCB-Block*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| phase |  |  |  no | Space-separated phase names. Blank means all phases. |
| face1 |  |  |  no | Boundary section name assigned to face 1. |
| face2 |  |  |  no | Boundary section name assigned to face 2. |
| face3 |  |  |  no | Boundary section name assigned to face 3. |
| face4 |  |  |  no | Boundary section name assigned to face 4. |
| face5 |  |  |  no | Boundary section name assigned to face 5. |
| face6 |  |  |  no | Boundary section name assigned to face 6. |

## bc-section

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| type | null | null<br>axisymmetric<br>extrapolation<br>connection<br>chimera<br>symmetry<br>periodic<br>wall<br>inlet<br>outlet<br>manifold<br>srm |  no | Boundary-condition type for the named section. |
| direction |  |  |  no | Patch directions using x,y,z,r,t,i,j,k. |
| patch<n> |  |  |  no | Named sub-patch section used by multipatch boundaries. |
| range<n> | 0.0 |  |  no | Sub-patch limits associated with patch<n>. |
| blocks | 0 |  |  no | Periodic source and destination block indices. |
| faces | 0 |  |  no | Periodic source and destination face indices. |
| block | 0 |  |  no | Connected block index for manifold boundaries. |
| face | 0 |  |  no | Connected face index for manifold boundaries. |
| file-direction |  |  |  no | Coordinate or index directions used by varying BC files. |
| eq-OG | F |  |  no | Enable CEA oxidizer-fuel equilibrium mode. |
| eq-CEA-file |  |  |  no | CEA input file used to derive equilibrium composition. |
| eq-CEA-section | 1 | >=1 |  no | CEA section index used when eq-CEA-file is provided. |
| yspecies | 0.0 | >=0 |  no | Mass fraction assigned to a species name suffix. |
| alpha | 0.0 |  |  no | Velocity angle alpha. |
| beta | 0.0 |  |  no | Velocity angle beta. |
| u | 0.0 |  |  no | Prescribed x-velocity component. |
| v | 0.0 |  |  no | Prescribed y-velocity component. |
| w | 0.0 |  |  no | Prescribed z-velocity component. |
| mit | 0.0 |  |  no | Turbulence intensity for 1-equation models. |
| kappa | 0.0 |  |  no | Turbulent kinetic energy. |
| omega | 0.0 |  |  no | Specific dissipation rate. |
| rhoRij | 0.0 |  |  no | Reynolds-stress tensor magnitude. |
| nrans | 0 | >=0 |  no | Explicit turbulence model size override. |
| mach | 0.0 |  |  no | Ideal-gas Mach number. |
| p0 | 0.0 |  |  no | Ideal-gas stagnation pressure. |
| T0 | 0.0 |  |  no | Ideal-gas stagnation temperature. |
| h0 | 0.0 |  |  no | Ideal-gas stagnation enthalpy. |
| T | 0.0 |  |  no | Ideal-gas static temperature. |
| g | 0.0 |  |  no | Mass flux for inlet boundaries. |
| p | 0.0 |  |  no | Static pressure for outlet or far-field boundaries. |
| p0-time-file | none |  |  no | Time-series file for total pressure. |
| p-time-file | none |  |  no | Time-series file for static pressure. |
| time-file | none |  |  no | Time-series file of full boundary state. |
| periodic | F |  |  no | Treat a time-file series as periodic. |
| rf | 1.0 |  |  no | Boundary relaxation factor. |
| Ae_At | 0.0 | >=1 |  no | Nozzle exit-to-throat area ratio. |
| rt | 0.0 |  |  no | Nozzle throat loading parameter. |
| psub | 0.0 |  |  no | Subsonic exit pressure used with rt. |
| psup | 0.0 |  |  no | Supersonic exit pressure used with rt. |
| q | 0.0 |  |  no | Prescribed wall heat flux. |
| T | 0.0 |  |  no | Prescribed wall temperature. |
| ks | 0.0 |  |  no | Wall roughness height. |
| qrad | 0.0 |  |  no | Radiative heat flux. |
| eps | 0.0 |  |  no | Wall emissivity. |
| q | 0.0 |  |  no | Prescribed wall heat flux. |
| T | 0.0 |  |  no | Prescribed wall temperature. |
| q-time-file | none |  |  no | Time-series file for wall heat flux. |
| T-time-file | none |  |  no | Time-series file for wall temperature. |
| qrad | 0.0 |  |  no | Radiative heat flux. |
| hconv | 0.0 |  |  no | Convective heat-transfer coefficient. |
| Tref | 0.0 |  |  no | Reference temperature for convection. |
| eps | 0.0 |  |  no | Wall emissivity. |
| krho | 0.0 |  |  no | Density ratios for dispersed populations. |
| kV | 1.0 |  |  no | Velocity scaling factors for dispersed populations. |
| kT | 1.0 |  |  no | Temperature scaling factors for dispersed populations. |
| gp | 0.0 |  |  no | Mass flux per dispersed population. |
| up | 0.0 |  |  no | x-velocity component per dispersed population. |
| vp | 0.0 |  |  no | y-velocity component per dispersed population. |
| wp | 0.0 |  |  no | z-velocity component per dispersed population. |
| Vp | 0.0 |  |  no | Velocity magnitude per dispersed population. |
| Tp | 0.0 |  |  no | Temperature per dispersed population. |
| rp | 0.0 |  |  no | Particle radii per dispersed population. |
| dp | 0.0 |  |  no | Particle diameters per dispersed population. |
| sigmap | 0.0 |  |  no | Particle dispersion widths. |
| alphap | 0.0 |  |  no | Primary injection angle per dispersed population. |
| betap | 0.0 |  |  no | Secondary injection angle per dispersed population. |
| rRes | 0.0 |  |  no | Residual radius per dispersed population. |
| Tsat | 0.0 |  |  no | Saturation temperature per dispersed population. |
| mit | 0.0 |  |  no | Turbulence intensity for 1-equation models. |
| kappa | 0.0 |  |  no | Turbulent kinetic energy. |
| omega | 0.0 |  |  no | Specific dissipation rate. |
| rhoRij | 0.0 |  |  no | Reynolds-stress tensor magnitude. |
| nrans | 0 | >=0 |  no | Explicit turbulence model size override. |
| a | 0.0 |  |  no | Burn-rate pre-exponential coefficient. |
| n | 0.0 |  |  no | Burn-rate pressure exponent. |
| pRef | 1.0 |  |  no | Reference pressure for the burn law. |
| rhoGrain | 0.0 |  |  no | Solid propellant density. |
| SF | 1.0 |  |  no | Scale factor for the grain propellant. |
| ks-file |  |  |  no | ASCII file providing varying values for ks. |
| q-file |  |  |  no | ASCII file providing varying values for q. |
| T-file |  |  |  no | ASCII file providing varying values for T. |
| Tref-file |  |  |  no | ASCII file providing varying values for Tref. |
| hconv-file |  |  |  no | ASCII file providing varying values for hconv. |
| qrad-file |  |  |  no | ASCII file providing varying values for qrad. |
| eps-file |  |  |  no | ASCII file providing varying values for eps. |
| alpha-file |  |  |  no | ASCII file providing varying values for alpha. |
| beta-file |  |  |  no | ASCII file providing varying values for beta. |
| g-file |  |  |  no | ASCII file providing varying values for g. |
| krho-file |  |  |  no | ASCII file providing varying values for krho. |
| a-file |  |  |  no | ASCII file providing varying values for a. |
| n-file |  |  |  no | ASCII file providing varying values for n. |
| pRef-file |  |  |  no | ASCII file providing varying values for pRef. |
| rhoGrain-file |  |  |  no | ASCII file providing varying values for rhoGrain. |
| Taf-file |  |  |  no | ASCII file providing varying values for Taf. |
| SFgeo-file |  |  |  no | ASCII file providing varying values for SFgeo. |
| SF-file |  |  |  no | ASCII file providing varying values for SF. |
