# GPB Tutorials

All test cases referenced here are available in `test/GPB/`.

| Tutorial | Source case | Test objective |
|----------|-------------|----------------|
| [Fixed-gas mixture](./fixed-gas) | `IG-fixgas` | Validate ideal-gas tables from fixed thermodynamic/transport constants. |
| [Cantera ideal-gas](./cantera-ideal-gas) | `IG-reactive` | Validate Cantera-driven ideal-gas thermo/transport property generation. |
| [Cantera equilibrium](./cantera-equilibrium) | `IG-ct-equilibrium` | Validate equilibrium composition and property-table generation with Cantera. |
| [CEA reactive](./cea-reactive) | `IG-ceafile-reactive-OG` | Validate reactive phase generation using CEA input and chemistry outputs. |
| [Heavy-gas mixture](./heavy-gas) | `IG-mixture-HG` | Validate heavy-gas mixture setup with gas/condensed coupling assumptions. |
| [Condensed phase](./condensed) | `CP-Tvar-dispersed` | Validate temperature-dependent condensed/dispersed phase-property tables. |
| [Solid phase](./solid) | `SP-Tvar` | Validate temperature-dependent solid-material property tables. |
| [Real fluid — CO₂](./real-fluid) | `RF-co2` | Validate real-fluid property-table generation for CO2 workflows. |
