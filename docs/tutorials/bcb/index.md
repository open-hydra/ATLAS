# Boundary Conditions (BCB)

BCB writes the boundary condition of every boundary cell of the mesh. The tutorials go from the basic types to the
coupled and overset faces; each runs one test case of `test/BCB/`.

| Tutorial | Case | You learn |
|----------|------|-----------|
| [Inlets, Outlets and Walls](walls-and-inlets.md) | `IG-2D` | the BC of every face, and how to read the BC file |
| [Several Conditions on One Face](multipatch.md) | `IG-multipatch-2D` | patches by coordinate ranges |
| [Inlets From Reservoir Conditions](reservoir-inlets.md) | `IG-nozzle-arearatio` | subsonic, supersonic and nozzle inlets |
| [Boundary Data From Tables](data-files.md) | `IG-xtheta-variable-T`, `IG-inflow-p0time` | values in space and in time |
| [Connections and Periodic Faces](connections.md) | `IG-periodic` | the faces between blocks, and periodic pairs |
| [Overset Blocks (Chimera)](chimera.md) | `IG-chimera` | the donors of overlapping blocks |
| [Particles at the Boundaries](particles.md) | `DP-basic` | the inlets of a dispersed phase |
| [Gas-Surface Interaction](gas-surface.md) | `IG-ablation` | ablating, melting and pyrolysing surfaces |
