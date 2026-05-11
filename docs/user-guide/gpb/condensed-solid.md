# GPB — Condensed & Solid Phases

GPB supports the definition of condensed and solid phases, which can be used to model liquid droplets, solid particles, walls, and structural materials. These phases can be defined with fixed properties or with temperature-dependent properties from databases.

!!! warning
    It is important to note that the condensed phase used in this context to represent liquid droplets is not the same modeling of real-fluid presented in [Real Fluid](./real-fluid.md). For dispersed droplets, heat capacity, density, and thermal conductivity are typically enough to properly setup the simulation. On the other hand, for continuous liquid phases, used for other applications, the real-fluid model is the most appropriate approach.

---

## Condensed-Dispersed Phase (`type = condensed-dispersed`)

Used when liquid droplets or solid particles are carried in a gas suspension.

### Constant properties

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L)
k        = 0.25
cp       = 1000
rho      = 2500
```

### Temperature-dependent properties

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
```

### Mult-material mixtures

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L), H2O(L)
thermo   = Burcat
rho      = 2500, 1000
```

### Groups specification

For dispersed phases, the user can specify the number of groups to be used for the particle size distribution. This is relevant for sprays and particle-laden flows.

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
groups   = 3
```

## Solid Phase (`type = solid`)

Used to model walls and structural materials. Same syntax as the condensed-dispersed phase, but with `type = solid`.

Groups specification is not relevant for solid phases, as they are not dispersed.

---