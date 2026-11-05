# Phases (GPB)

GPB builds the tables of every phase of a case: a gas from constants, from a mechanism or from an equilibrium, a heavy
gas, particles, a solid, a real fluid. Each tutorial runs one test case of `test/GPB/`.

| Tutorial | Case | You learn |
|----------|------|-----------|
| [Fixed-Gas Mixture](fixed-gas.md) | `IG-fixgas` | a gas from constant properties, without a database |
| [Cantera Ideal Gas](cantera-ideal-gas.md) | `IG-reactive` | a gas from a Cantera mechanism, with its chemistry tables |
| [Cantera Equilibrium](cantera-equilibrium.md) | `IG-ct-equilibrium` | a gas of the equilibrium composition, from Cantera |
| [CEA Reactive](cea-reactive.md) | `IG-ceafile-reactive-OG` | a gas from a CEA input file |
| [Heavy-Gas Mixture](heavy-gas.md) | `IG-mixture-HG` | a gas that carries condensed products as heavy species |
| [Condensed Phase](condensed.md) | `CP-Tvar-dispersed` | particles or droplets, with properties against temperature |
| [Solid Phase](solid.md) | `SP-Tvar` | a solid material, for heat conduction |
| [Real Fluid](real-fluid.md) | `RF-co2` | CO₂ near its critical point, on a (p, h) grid |
