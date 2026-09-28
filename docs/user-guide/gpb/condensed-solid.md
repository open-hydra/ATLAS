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

#### Enthalpy datum of constant-property materials (`h0`)

With `cp` given, the `Enthalpy` column of `<name>properties.dat` is the relative `cp·T` (its value at 298.15 K is `cp·298.15`, not the enthalpy of formation). Add `h0` (J/kg, one value per material) to make the column absolute:

```text
h(T) = cp·T + (h0 − cp·298.15)      so that   h(298.15 K) = h0
```

The header then reads `Enthalpy_abs` instead of `Enthalpy`; without `h0` nothing changes. Use the same reference state as the gas-phase thermodynamics (NASA/Burcat: enthalpy of formation of the liquid at 298.15 K), e.g. `h0 = -15865000` for liquid water. Temperature-dependent materials (`thermo = Burcat` and the NASA tables) always write `Enthalpy_abs`, because the polynomials carry the formation enthalpy.

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = H2O(L)
cp       = 4184
rho      = 997
h0       = -15865000
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

#### Materials the database does not hold

With `thermo = NASA7`, `NASA9` or `Burcat` (and with neither `thermo` nor `cp`, which means `NASA9`), GPB takes every
material of `material` from that database, in the order of `material`. A material the database does not hold takes
constant properties from the section instead, exactly as a constant-property material: its `cp` and `rho`, its `k` if
given, and its `h0`. GPB prints a line naming the material and the database file. `rho`, `cp`, `k` and `h0` hold one value
per material in the order of `material` (a single value applies to every material); the `cp` of a material the database
holds is not used, and GPB says so.

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = FOO(L) AL2O3(L)
thermo   = Burcat
rho      = 1000 2500
cp       = 1800
h0       = -10000000
groups   = 2 1
```

```text
 -- FOO(L) is not in burcat.yaml: constant properties from the INI (cp = 1800, rho = 1000, h0 = -1e+07)
 -- AL2O3(L) from burcat.yaml: its cp in the INI is not used
```

The database tables carry the formation enthalpy (`Enthalpy_abs`), so a material that falls back next to database
materials needs its `h0` on the same scale: without it GPB stops (`give h0`). When no material of the phase is in the
database, `h0` is optional as for any constant-property phase. A material the database lacks with no `cp` stops GPB with
the material and the database named: correct the name or give `cp`. `cp` without `thermo` keeps its meaning: every
material takes the constants, whatever the database holds.

### Mult-material mixtures

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L) H2O(L)
thermo   = Burcat
rho      = 2500 1000
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