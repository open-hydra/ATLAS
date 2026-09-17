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
modeling = lagrangian
material = AL2O3(L)
k        = 0.25
cp       = 1000
rho      = 2500
```

### Temperature-dependent properties

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
```

### Mult-material mixtures

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L), H2O(L)
thermo   = Burcat
rho      = 2500, 1000
```

### Groups specification

For dispersed phases, the user can specify the number of groups to be used for the particle size distribution. This is relevant for sprays and particle-laden flows.

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
groups   = 3
```

### Per-material solver models

Optional keys of `[GPB-Phase*]` that select, per material, the models the Lagrangian solver (IGLOO) applies
to that material. Each key takes one value per entry of `material`, space-separated in the same order (a
single value is broadcast to every material). GPB validates them and writes them as `key=value` tokens after
`<material> <groups>` on the material line of `<name>-phase.txt`; the solvers consume the tokens, ATLAS's own
readers (BCB/ICB) ignore them. An absent key emits no token and the solver's default applies.

!!! note
    The keys are validated by GPB but **not yet written** to the phase file: the IGLOO/ICE/MI2 readers have
    to accept tokens first (hydra-side change). Until then a key in `[GPB-Phase*]` is checked and discarded.

```ini
[GPB-Phase1]
type        = condensed-dispersed
material    = AL2O3(L) H2O(L)
thermo      = Burcat
rho         = 2500 1000
evaporation = CEM ASM
interface   = LK
alpha-e     = 1.0
```

produces, once written, the material lines

```
AL2O3(L) 1 evaporation=CEM interface=LK alpha-e=1
H2O(L) 1 evaporation=ASM interface=LK alpha-e=1
```

| key | kind | allowed values | meaning (solver default) |
|---|---|---|---|
| `evaporation` | word | `d2-law`, `CEM`, `CEM-B`, `ASM`, `TC` | Evaporation model override (global `[IGLOO-Models] evaporation`) |
| `liquid-conduction` | word | `ITC`, `P2T` | Liquid-side conduction model (`ITC`) |
| `interface` | word | `VLE`, `LK` | Interface model: equilibrium or Langmuir-Knudsen (`VLE`) |
| `boiling` | word | `clamp`, `ZGR` | Boiling branch (`clamp`) |
| `combustion` | word | `Beckstead` | Metal combustion model; presence switches the material to the metal track |
| `solidification` | word | `on`, `off` | Solidification with supercooling/recalescence (`off`) |
| `alpha-e` | real | | Langmuir-Knudsen accommodation coefficient, `interface = LK` (1.0) |
| `k-liq` | real | | Liquid thermal conductivity [W/m/K], required with `liquid-conduction = P2T` (0) |
| `mu-liq` | real | | Liquid viscosity [Pa s], `liquid-conduction = P2T` (0) |
| `K-burn` | real | | Beckstead burn-rate coefficient at `X-eff` = 1 [m^n-burn/s], required > 0 with `combustion = Beckstead` (0) |
| `n-burn` | real | | Beckstead burn-law diameter exponent (1.8) |
| `X-eff` | real | | Effective oxidizer mole fraction C_O2 + 0.6 C_H2O + 0.22 C_CO2 (1.0) |
| `beta-part` | real | | Heat-partition fraction of `q-comb` released to the particle (0) |
| `xi-cap` | real | | Oxide-cap mass fraction retained on the burning particle (0) |
| `T-ign` | real | | Ignition temperature [K]; the particle is inert below it (2350) |
| `q-comb` | real | | Heat of combustion per unit Al mass [J/kg] (0) |
| `T-melt` | real | | Melt temperature [K] (2327, alumina) |
| `h-fus` | real | | Heat of fusion [J/kg], solidification (0) |
| `T-nuc` | real | | Nucleation temperature [K]; absent or 0 = 0.8 `T-melt` (0) |
| `cp-solid` | real | | Solid-phase specific heat [J/kg/K], solidification (0) |

A word outside the allowed set, a non-numeric real, or a value count that is neither 1 nor the number of
materials stops GPB with `[ERROR] [GPB-Phase1] <key> ...`.

## Solid Phase (`type = solid`)

`solid-bulk` is accepted as a synonym of `solid`, and `solid-bulk` is the word the generated `<prefix>phase.txt` carries on its first line.

Used to model walls and structural materials. Same syntax as the condensed-dispersed phase, but with `type = solid`.

Groups specification is not relevant for solid phases, as they are not dispersed.

---