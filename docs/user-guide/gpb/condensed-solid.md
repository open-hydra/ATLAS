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

The header then reads `Enthalpy_abs` instead of `Enthalpy`; without `h0` nothing changes. Use the same reference state as the gas-phase thermodynamics (NASA/Burcat: enthalpy of formation of the liquid at 298.15 K), e.g. `h0 = -15865000` for liquid water. Temperature-dependent materials from a database (`thermo = NASA7`, `NASA9` or `Burcat`) always write `Enthalpy_abs`, because the polynomials carry the formation enthalpy; a `custom` material writes it when its class sets `absolute_enthalpy`.

```ini
[GPB-Phase1]
type     = condensed-dispersed
material = H2O(L)
cp       = 4184
rho      = 997
h0       = -15865000
```

#### Saturation pressure from the thermo database (`psat-vapour`, `psat-liquid`)

A dispersed material can carry its saturation pressure `p_sat(T)` in `<name>properties.dat`. `psat-vapour` names the vapour species of the thermo database GPB loads (`nasa9.yaml` for `thermo = NASA9` or no `thermo`, `burcat.yaml` for `thermo = Burcat`, a file that the user supplies: [Thermodynamics Databases](../../databases/thermodynamics/index.md#burcat-distribution)) and `psat-liquid` the liquid species, by default the material name. Both keys take one value per entry of `material` (a single value is broadcast); `psat-vapour = none` skips a material. GPB computes, on every row of the table,

```text
p_sat(T) = p_ref · exp(−(g_vap(T) − g_liq(T)) / (R·T)),     g = h − T·s (molar),   p_ref = 1 bar
```

inside the temperature range the two fits share, and continues it outside that range along the Clausius–Clapeyron line through its nearer end (with `h_vap − h_liq` taken there). `p_ref` is the standard-state pressure of the NASA and Burcat polynomials. The same pair gives the latent heat, the molar mass and the specific heat of the vapour:

```text
Lv(T)  = (h_vap(T_e) − h_liq(T_e)) / Mv,   T_e = T within the range the two fits share     [J/kg]
Mv     = molar mass of the vapour species                                                 [kg/kmol]
Cpv(T) = cp_vap(T_v) / Mv,                 T_v = T within the range of the vapour's fit    [J/(kg·K)]
```

`Lv` takes on every row the `h_vap − h_liq` that `Psat` takes there, so `d ln p_sat/dT = Lv·Mv/(R·T²)` holds on every row: Gibbs–Helmholtz inside the common range, the Clausius–Clapeyron line outside it. The four columns `Psat` [Pa], `Lv`, `Mv` and `Cpv` follow the enthalpy column (see [Output Files](./output.md)); an unpaired material gets zeros in all four, and without `psat-vapour` the table keeps its four columns. The solvers read the columns by name; a column of zeros leaves a material on the solver's own data (its Clausius–Clapeyron model, its latent heat and vapour constants). The phase file `<name>phase.txt` is unchanged: the two keys are not material-line tokens.

```ini
[GPB-Phase1]
type        = condensed-dispersed
material    = H2O(L)
cp          = 4184
rho         = 997
h0          = -15865000
psat-vapour = H2O
```

For each paired material GPB prints the common range of the two fits, the implied normal boiling point (where `p_sat` = 1 atm), `h_vap − h_liq` there (`Lv` at that point) and `Mv`:

```text
 -- Psat of H2O(L): H2O(L)/H2O, common range 273.15-600 K, normal boiling point 373.57 K, h_vap - h_liq there 2268.1 kJ/kg, Mv 18.015 kg/kmol
```

Read that boiling point: it is the only symptom of a wrong isomer, which passes every check below. In Burcat, `C7H16` is iso-heptane and `C6H14` is 2-methylpentane: paired with the n-heptane liquid `C7H16(L)`, `C7H16` gives a boiling point of 324.7 K instead of 371.6 K (`C7H16,n-heptane` gives 373.0 K), and `C6H14` with `C6H14(L)` gives 271 K (use `C6H14,n-hexane`).

GPB stops with `[ERROR] ...` when a species is not in the loaded file, when either species is not a NASA7/NASA9 polynomial fit (the NASA9 entries `CH4(L)`, `O2(L)` and `H2(L)` are constant-cp), when the two elemental compositions differ, when `h_vap − h_liq ≤ 0` on a row, when a value count is neither 1 nor the number of materials, when `psat-liquid` is given without `psat-vapour`, for `thermo = NASA7` (`nasa_condensed.yaml` holds no vapour species), for `thermo = custom` (no species file: a custom material gives its own `psat`) and for a solid phase.

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

The rows marked Burcat were obtained with the 2016 edition of `burcat.yaml`, which the user supplies.

Against the IAPWS saturation line the water pair is within 0.1 % at 280–300 K, −0.85 % at 350 K, −2.8 % at 400 K, −6.6 % at 450 K and −31 % at 600 K: the route treats the vapour as an ideal gas and ignores the pressure dependence of the liquid, so the error grows toward the critical point. It also needs a liquid entry with full polynomials (there is none for n-hexadecane) and a material that evaporates as the named molecule (alumina does not: its vapour is Al, AlO and O, and `AL2O3(L)` / `AL2O3` gives 1e-6 atm at 3250 K).

### Temperature-dependent properties

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L)
thermo   = NASA9
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
thermo   = NASA9
rho      = 1000 2500
cp       = 1800
h0       = -10000000
groups   = 2 1
```

```text
 -- FOO(L) is not in nasa9.yaml: constant properties from the INI (cp = 1800, rho = 1000, h0 = -1e+07)
 -- AL2O3(L) from nasa9.yaml: its cp in the INI is not used
```

The database tables carry the formation enthalpy (`Enthalpy_abs`), so a material that falls back next to database
materials needs its `h0` on the same scale: without it GPB stops (`give h0`). When no material of the phase is in the
database, `h0` is optional as for any constant-property phase. A material the database lacks with no `cp` stops GPB with
the material and the database named: correct the name or give `cp`. `cp` without `thermo` keeps its meaning: every
material takes the constants, whatever the database holds.

### Custom materials (`thermo = custom`)

With `thermo = custom`, every material of `material` is a `CondensedMaterial` made in `custom.py` (that of
`database/thermo`, or of the case directory), which is given `cp(T)`, `rho(T)` and, optionally, `k(T)`, the enthalpy
`h(T)` and `psat(T)`. This is the way to give a solid or a liquid temperature-dependent properties that no database holds.

```ini
[GPB-Phase1]
type     = liquid-dispersed
name     = drop
material = Foam Graphite
thermo   = custom
Tmin     = 300
Tmax     = 600
```

`Graphite` ships with ATLAS; `Foam` is a class that you write, as in [Custom Substances](../../databases/thermodynamics/custom.md#condensed-materials).
`cp`, `rho`, `k` and `h0` of the section are ignored (a `[WARNING]` names them): the material gives its own. A material
that `custom.py` does not define stops GPB, with the names that it does. The classes, their methods and the checks are
in [Custom Substances](../../databases/thermodynamics/custom.md#condensed-materials).

### Multi-material mixtures

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L) H2O(L)
thermo   = NASA9
rho      = 2500 1000
```

### Groups specification

For dispersed phases, the user can specify the number of groups to be used for the particle size distribution. This is relevant for sprays and particle-laden flows.

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
material = AL2O3(L)
thermo   = NASA9
rho      = 2500
groups   = 3
```

### Per-material solver models

Optional keys of `[GPB-Phase*]` that select, per material, the models the solvers (IGLOO, ICE) apply to that
material. Each key takes one value per entry of `material`, space-separated in the same order (a single value is
broadcast to every material). GPB validates them and writes them in two places:

- the model WORDS, and the constants of the models of the table below, as `key=value` tokens after
  `<material> <groups>` on the material line of `<name>phase.txt`;
- the CONSTANTS of the burning and breakup models in `<name>models.txt`, one row per material and kind (next section).

The solvers consume both, ATLAS's own readers (BCB/ICB) ignore them. An absent key emits nothing and the solver's
default applies.

```ini
[GPB-Phase1]
type        = condensed-dispersed
material    = AL2O3(L) H2O(L)
thermo      = NASA9
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
| `combustion` | word | `Beckstead`, `direct`, `none` | Burning model of the material: the d^n law, or the d2 law of a drop held at its burning temperature; its constants go to `<name>models.txt` (the solver section's `combustion`) |
| `solidification` | word | `on`, `off` | Solidification with supercooling and recalescence, and melting at `T-melt`, in IGLOO and ICE (`off`) |
| `breakup` | word | `Pilch-Erdman`, `Reitz-Diawakar`, `Reitz-KHRT`, `TAB`, `ETAB`, `NoBreakup` | Breakup model of the material, IGLOO only; its constants go to `<name>models.txt` (the solver section's `breakup`) |
| `alpha-e` | real | | Langmuir-Knudsen accommodation coefficient, `interface = LK` (1.0) |
| `k-liq` | real | | Liquid thermal conductivity [W/m/K], required with `liquid-conduction = P2T` (0) |
| `mu-liq` | real | | Liquid viscosity [Pa s], `liquid-conduction = P2T` (0) |
| `T-melt` | real | | Melt temperature [K] (2327, alumina) |
| `h-fus` | real | | Heat of fusion [J/kg], solidification (0) |
| `T-nuc` | real | | Nucleation temperature [K]; absent or 0 = 0.8 `T-melt` (0) |
| `cp-solid` | real | | Solid-phase specific heat [J/kg/K], solidification (0) |

A word outside the allowed set, a non-numeric real, or a value count that is neither 1 nor the number of
materials stops GPB with `[ERROR] [GPB-Phase1] <key> ...`.

### The constants of the models: `<name>models.txt`

One row per material and kind, `<material> <kind> <model> key=value ...`, the keys in any order; lines that start
with `#` are comments. The file is written only when a material of the phase has such constants. The material line
keeps the word of each kind (`combustion=<model>`, `cap=<law>`, `breakup=<model>`) and none of the constants.

```ini
[GPB-Phase2]
type       = condensed-dispersed
material   = Al Mg
rho        = 2700 1740
cp         = 1177 1300
h0         = 9.53e6 5.0e6
combustion = Beckstead direct
K-burn     = 1.39e-6
n-burn     = 1.8
X-eff      = 0.5
beta-part  = 0.3
T-ign      = 290
T-burn     = 0 1363
q-comb     = 1.0e6 9.53e6
d-stop     = 6.0e-5 0
d-burnout  = 0 1.0e-7
```

writes the material lines `Al 1 combustion=Beckstead` and `Mg 1 combustion=direct`, and the rows

```
Al combustion Beckstead K-burn=1.39e-06 n-burn=1.8 X-eff=0.5 beta-part=0.3 T-ign=290 q-comb=1000000 d-stop=6e-05 d-burnout=0
Mg combustion direct T-burn=1363 q-comb=9530000 d-stop=0 d-burnout=1e-07
```

| kind | its model is named by | models | constants each model reads |
|---|---|---|---|
| `combustion` | `combustion` | `Beckstead` | `K-burn` [m^n-burn/s], `n-burn`, `X-eff`, `beta-part`, `T-ign` [K], `q-comb` [J/kg], `d-stop` [m], `d-burnout` [m], `d-gen` [m] |
| | | `direct` | `T-burn` [K], `q-comb` [J/kg], `d-stop` [m], `d-burnout` [m], `d-gen` [m] |
| `cap` (the oxide cap of a burning drop, IGLOO) | `xi-law` (absent: `constant`) | `constant` | `xi-cap`, `xi-ox0`, `product`, `residue` (`on`, `off`), `d-residue` [m] |
| | | `Gallier21` | `xi-ox0`, `product`, `residue`, `d-residue` |
| `breakup` (IGLOO) | `breakup` | `Pilch-Erdman` | `Cd`, `B` |
| | | `Reitz-Diawakar` | `WeBag`, `Cb`, `Cstrip`, `Cs` |
| | | `Reitz-KHRT` | `B0`, `B1`, `Ctau`, `CRT`, `mShedLim`, `WeLimit` |
| | | `TAB` | `Comega`, `Cmu`, `WeCrit`, `method` (1, 2), `n` |
| | | `ETAB` | `k1`, `k2`, `WeCrit`, `WeTrans`, `Comega`, `Cmu` |

- A constant goes in the row of each material whose model reads it. Where the model does not read it, a single
  value given for all the materials is not written for that one, and an entry of a per-material list must be the
  "not given" value (`0`; `none` for `product`; `off` for `residue`): GPB stops otherwise, and it stops on a
  constant that no material's model reads.
- A cap row is written for a material that asks for a cap: `xi-law = Gallier21`, or a cap constant that is not
  the "not given" value. Its line then carries `cap=<law>`.
- A material with `combustion = none` gets no `combustion` or `cap` row, one with `breakup = NoBreakup` no `breakup`
  row, and a combustion product (the material `product` names: 0 groups, never injected) no row and no
  `combustion=` or `breakup=` word. When the `combustion` or `breakup` key is absent, the constants given are written
  under the model `-`: the solver's own section then names the model.
- The breakup constants are optional: one absent from the row takes IGLOO's default (in the
  [GPB key reference](input-reference.md)); `WeCrit` is the critical Weber number as written, which IGLOO doubles.
  Breakup is IGLOO's: ICE, which has no breakup model, ignores the `breakup=` word of a material line and a
  `breakup` row with one warning each, so give the breakup keys to a phase IGLOO solves (`modeling = lagrangian`).
  GPB does not check that, as it does not for `cap` (which ICE refuses).

```ini
[GPB-Phase1]
type     = condensed-dispersed
modeling = lagrangian
name     = part
material = A B C
rho      = 1000 1000 1000
cp       = 4182 4182 4182
breakup  = TAB ETAB NoBreakup
Comega   = 10
WeTrans  = 0 60 0
method   = 1 0 0
```

writes the material lines `A 1 breakup=TAB`, `B 1 breakup=ETAB`, `C 1 breakup=NoBreakup` and the rows

```
A breakup TAB Comega=10 method=1
B breakup ETAB WeTrans=60 Comega=10
```
- `d-burnout` is the one removal size ICE and IGLOO share; without it each keeps its own floor (a drop mass of
  1e-20 kg). To compare a material in the two solvers give it, at about 0.1 of the injected diameter.
- `combustion = direct` reads its latent heat in the `Lv` column of the properties table, at `T-burn`: give the
  material its vapour pair (`psat-vapour`, above). Without the column the solver's own section must give a
  constant.

### The mass a burning material generates

`particle-mechanism`'s reaction for a burning material may give, besides gas species, one condensed product.
GPB resolves that product as one of two things (any other condensed product stops GPB): the oxide a `cap`
retains (`product=`, above), or a **generated mass** — a material of an *eulerian* dispersed phase with a population
(`groups >= 1` there), born in that phase's ICE family. A capped material whose `product=` material is itself
declared as a generated mass (its own line asks for a population in an eulerian phase) gets both a `cap` record and a
combustion record: what the cap does not retain is handed to the gas as that generated mass, in the same reaction.

A burning material that generates mass needs `d-gen` (the diameter of the generated drops, [m]) on its row; a material
without one that is given `d-gen` is refused, and a material with a population in two eulerian phases is refused
(a generated mass is born in exactly one ICE family). The reaction itself, written out, appears as a comment above the
material's record of `<name>products.txt`, whose combustion record (or `release`, for the oxide a cap born as
generated mass whole hands to the gas) then ends in the eulerian phase's output prefix: see
[Output Files](./output.md#prefixproductstxt), which hydra-MI2 reads to route the generated mass into that ICE family.

```ini
[GPB-Phase1]
type    = ideal-gas
name    = gas
species = N2 H2O H2
thermo  = NASA9
Tmax    = 4000

[GPB-Phase2]
type       = condensed-dispersed
modeling   = eulerian
name       = part
thermo     = NASA9
material   = AL(L) AL2O3(L)
groups     = 1 1
rho        = 1540 2606
Tmax       = 4000
particle-mechanism = al-h2o-gen    ; 2 AL(L) + 3 H2O => AL2O3(L) + 3 H2
combustion = Beckstead none
K-burn     = 1.39e-6
n-burn     = 1.8
X-eff      = 0.5
T-ign      = 2300
beta-part  = 0.02
q-comb     = 1.49e7
d-gen      = 1.0e-6 0
; AL2O3(L)'s table crosses its melting point, 2327 K, below Tmax: solidification = on with the database's own
; T-melt, h-fus and cp-solid there (next paragraph)
solidification = off on
T-melt         = 0 2327
h-fus          = 0 1.092578e6
cp-solid       = 0 1433.17
T-nuc          = 0 1861.6
```

AL2O3(L), the second material of the same eulerian phase, is AL(L)'s generated mass (it has a population, `groups = 1`,
in the same `[GPB-Phase2]`); this writes AL(L)'s row of `part-models.txt` with `d-gen=1e-06` and ends the
combustion record of `part-products.txt` with the output prefix of `[GPB-Phase2]` (`part-`).

A generated mass whose database table crosses its substance's melting point inside the phase's `[Tmin, Tmax]` holds no
heat of fusion there. Named by the liquid species (as `AL2O3(L)` above), the table below the melting point is the
liquid's own fit: the generated mass needs `solidification = on`, else GPB stops, naming the melting point and the
database's own `h-fus` and `cp-solid` there (GPB checks only the word; it does not itself check `h-fus` or
`cp-solid` against the database, and warns, rather than stops, when `T-melt` is more than 0.5 K off the database's
value). Named by a solid species whose fit is extended, at constant `cp`, past where the liquid begins,
`solidification = on` cannot fix it: GPB asks for the liquid species instead, or `Tmax` capped at the melting
point.

## Solid Phase (`type = solid`)

`solid-bulk` is accepted as a synonym of `solid`, and `solid-bulk` is the word the generated `<prefix>phase.txt` carries on its first line.

Used to model walls and structural materials. Same syntax as the condensed-dispersed phase, but with `type = solid`.
A wall whose properties vary with temperature is a `thermo = custom` material; its `k(T)` is written in the `Conductivity`
column (the materials that ship with ATLAS are listed in [Custom Substances](../../databases/thermodynamics/custom.md#shipped-materials)):

```ini
[GPB-Phase1]
type     = solid
name     = solido
material = UC
thermo   = custom
```

Groups specification is not relevant for solid phases, as they are not dispersed.

---