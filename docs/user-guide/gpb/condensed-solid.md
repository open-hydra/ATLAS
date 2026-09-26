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

#### Saturation pressure from the thermo database (`psat-vapour`, `psat-liquid`)

A dispersed material can carry its saturation pressure `p_sat(T)` in `<name>properties.dat`. `psat-vapour` names the vapour species of the thermo database GPB loads (`nasa9.yaml` for `thermo = NASA9` or no `thermo`, `burcat.yaml` for `thermo = Burcat`) and `psat-liquid` the liquid species, by default the material name. Both keys take one value per entry of `material` (a single value is broadcast); `psat-vapour = none` skips a material. GPB computes, on every row of the table,

```text
p_sat(T) = p_ref · exp(−(g_vap(T) − g_liq(T)) / (R·T)),     g = h − T·s (molar),   p_ref = 1 bar
```

inside the temperature range the two fits share, and continues it outside that range along the Clausius–Clapeyron line through its nearer end (with `h_vap − h_liq` taken there). `p_ref` is the standard-state pressure of the NASA and Burcat polynomials. The curve is written as a fifth column `Psat` [Pa] after the enthalpy column (see [Output Files](./output.md)); an unpaired material gets zeros, and without `psat-vapour` the table keeps its four columns. The solvers read the column by name (IGLOO and ICE); a column of zeros leaves a material on the solver's own Clausius–Clapeyron model. The phase file `<name>phase.txt` is unchanged: the two keys are not material-line tokens.

```ini
[GPB-Phase1]
type        = condensed-dispersed
material    = H2O(L)
cp          = 4184
rho         = 997
h0          = -15865000
psat-vapour = H2O
```

For each paired material GPB prints the common range of the two fits, the implied normal boiling point (where `p_sat` = 1 atm) and `h_vap − h_liq` there:

```text
 -- Psat of H2O(L): H2O(L)/H2O, common range 273.15-600 K, normal boiling point 373.57 K, h_vap - h_liq there 2268.1 kJ/kg
```

Read that boiling point: it is the only symptom of a wrong isomer, which passes every check below. In Burcat, `C7H16` is iso-heptane and `C6H14` is 2-methylpentane: paired with the n-heptane liquid `C7H16(L)`, `C7H16` gives a boiling point of 324.7 K instead of 371.6 K (`C7H16,n-heptane` gives 373.0 K), and `C6H14` with `C6H14(L)` gives 271 K (use `C6H14,n-hexane`).

GPB stops with `[ERROR] ...` when a species is not in the loaded file, when either species is not a NASA7/NASA9 polynomial fit (the NASA9 entries `CH4(L)`, `O2(L)` and `H2(L)` are constant-cp), when the two elemental compositions differ, when `h_vap − h_liq ≤ 0` on a row, when a value count is neither 1 nor the number of materials, when `psat-liquid` is given without `psat-vapour`, for `thermo = NASA7` (`nasa_condensed.yaml` holds no vapour species), for `thermo = SP-database` (no species file) and for a solid phase.

Accuracy of the database pairs:

| pair (file) | `p_sat` at the normal boiling point, in atm |
|---|---|
| `H2O(L)` / `H2O` (NASA9) | 0.984 |
| `C7H16(L)` / `C7H16,n-heptane` (Burcat) | 0.962 |
| `C8H18(L)` / `C8H18,n-octane` (Burcat) | 0.960 |
| `C6H14(L)` / `C6H14,n-hexane` (Burcat) | 0.973 (the liquid fit ends at 300 K) |
| `C10H22(L)` / `N-C10H22` (Burcat) | 1.09 (the liquid fit ends at 446.8 K) |
| `N2H4(L)` / `N2H4` (Burcat) | 0.929 |
| `AL(L)` / `AL` (NASA9) | 0.962 |
| `C2H5OH(L)` / `C2H5OH` (Burcat) | 0.847 |
| `CH3OH(L)` / `CH3OH` (Burcat) | 1.32 |
| `C6H6(L)` / `C6H6` (Burcat) | 72: inconsistent entries, do not use |

Against the IAPWS saturation line the water pair is within 0.1 % at 280–300 K, −0.85 % at 350 K, −2.8 % at 400 K, −6.6 % at 450 K and −31 % at 600 K: the route treats the vapour as an ideal gas and ignores the pressure dependence of the liquid, so the error grows toward the critical point. It also needs a liquid entry with full polynomials (there is none for n-hexadecane) and a material that evaporates as the named molecule (alumina does not: its vapour is Al, AlO and O, and `AL2O3(L)` / `AL2O3` gives 1e-6 atm at 3250 K).

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