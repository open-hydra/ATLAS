# GPB — Ideal-Gas & Heavy-Gas Phases

## Ideal-Gas Phase (`type = ideal-gas`)

This is the default phase type. GPB supports four main configuration paths:

### 1. Fixed-gas properties

Specify thermo and transport constants directly:

```ini
[GPB-Phase1]
name     = gasmix
type     = ideal-gas
species  = N2f Hef
gamma    = 1.4  1.66
mw       = 28.0 4.0
mil      = 1e-5 1.3e-5
kl       = 0.25 0.30
```

GPB solves the algebraic system to derive any missing properties ($c_p$, $c_v$, $R$, $\gamma$) from the provided values. If `Pr` is given, $\lambda$ is back-computed.

### 2. Cantera species database

Load thermo and transport from a Cantera mechanism:

```ini
[GPB-Phase1]
name      = combustion_gas
type      = ideal-gas
reactions = JLR-nasuti          ; Cantera .yaml mechanism name
species   = N2                  ; additional inert species
thermo    = NASA9
transport = cantera
Tmax      = 5000
```

### 3. Cantera equilibrium

Compute the equilibrium composition then generate tables:

```ini
[GPB-Phase1]
name         = equilibrium_gas
type         = ideal-gas
eq-of        = 6
eq-pressure  = 3000 psi
eq-fuel      = H2
eq-fuel-T    = 300.0
eq-oxidizer  = O2(L)
```

### 4. CEA reactive / frozen

Use a pre-run CEA output file:

```ini
[GPB-Phase1]
type         = ideal-gas
CEA-file     = CEA.inp
transport    = CEA
reactions    = troyes
inerts-mixing = true
```

### Prescribed mixture (no reactions)

```ini
[GPB-Phase1]
mixture-name = air
mixture      = {N2: 75.4} {O2: 23.3} {Ar: 1.3}
thermo       = NASA9
transport    = CEA
```

---

## Heavy-Gas Phase (`type = heavy-gas`)

Heavy-gas is a variant of ideal-gas where the mixture contains condensed species alongside the gas. The pressure is internally scaled by `HG_FACTOR = 1e5`. All ideal-gas keys are valid; simply change the `type`:

```ini
[GPB-Phase1]
type      = heavy-gas
mixture   = {N2: 55.4} {O2: 23.3} {Ar: 1.3} {AL2O3(L): 20.0}
transport = CEA
```

Output filename gets the suffix `-HG` (e.g. `gasmix-HG.bin`).

---

## `thermo` Options

| Value | Description |
|-------|-------------|
| `NASA9` | NASA 9-coefficient polynomial fits (from Cantera species database) |
| `CEA` | CEA curve fits |
| `cantera` | Cantera internal thermo model |
| `fixed` | Constant properties from `cp`, `gamma`, etc. keys |

## `transport` Options

| Value | Description |
|-------|-------------|
| `CEA` | CEA transport polynomial fits (requires `$ATLASDIR/database/transport/CEApolynomials.yaml`) |
| `cantera` | Cantera mixture-averaged transport |
| `sutherland` | Sutherland's law |
| `fixed` | Constant `mil`, `kl` from INI keys |
