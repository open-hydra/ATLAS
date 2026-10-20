# ATLAS STB Input Parameters


## ATLAS-Parameters

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| strict-keys | T |  |  no | F turns the error on a key the tool does not read (or not honoured by the resolved BC type, or y of an undeclared species) into a WARNING; wrong values are always errors (keys with the prefix ignore- are never read). |

## STB-Block*

| Parameter | Default | Allowed | Required | Description |
|-----------|---------|---------|----------|-------------|
| direction |  |  |  no | Direction for 1D profiles: x,y,z,r,t or combinations (a combination is read along its first letter by priority x > y > z > r > t, with a WARNING); not given for a 3D field. |
| x-areavariation |  |  |  no | Area profile file for x-directed variation. |
| y-areavariation |  |  |  no | Area profile file for y-directed variation. |
| r-areavariation |  |  |  no | Area profile file for radial variation. |
| theta-areavariation |  |  |  no | Area profile file for azimuthal variation (degrees in file). |
| qvol | 0.0 |  |  no | Uniform Volumetric heat source value. |
| qvol-file |  |  |  no | File of the Volumetric heat source: a two-column 1D profile (coordinate value) read along direction, or, without direction, a 3D Tecplot field on another mesh (cell-centred variable power, W per cell, or qvol, W/m3) remapped conservatively onto the block. |
| qvol-remap | covered | covered<br>fraction |  no | Rule of the 3D remap: covered gives the whole power of a donor cell to the part the blocks cover (the power of every touched donor cell is conserved: a field with no power outside the blocks); fraction gives the volume fraction of it (the blocks are a part, e.g. a symmetry sector, of a field with power outside them). |
