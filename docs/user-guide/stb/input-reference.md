# ATLAS STB Input Parameters


## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| strict-keys | T |  |  no | F turns the error on a key the tool does not read (or not honoured by the resolved BC type, or y of an undeclared species) into a WARNING; wrong values are always errors (keys with the prefix ignore- are never read). |

## STB-Block*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| direction |  | x,y,z,r,t |  no | Direction for 1D profiles: x,y,z,r,t or combinations. |
| x-areavariation |  |  |  no | Area profile file for x-directed variation. |
| y-areavariation |  |  |  no | Area profile file for y-directed variation. |
| r-areavariation |  |  |  no | Area profile file for radial variation. |
| theta-areavariation |  |  |  no | Area profile file for azimuthal variation (degrees in file). |
| qvol | 0.0 |  |  no | Uniform Volumetric heat source value. |
| qvol-file |  |  |  no | File path for 1D profile or 3D field input. |
