# GPB — Condensed & Solid Phases

## Condensed Phase (`type = condensed`)

A liquid/condensed phase with constant or temperature-variable properties:

```ini
[GPB-Phase2]
type     = condensed
material = AL2O3(L)
rho      = 2500
thermo   = fixed
cp       = 1200
```

## Condensed-Dispersed Phase (`type = condensed-dispersed`)

Used when liquid droplets or solid particles are carried in a gas suspension:

```ini
[GPB-Phase2]
type     = condensed-dispersed
material = AL2O3(L)
thermo   = Burcat
rho      = 2500
```

With `thermo = Burcat`, GPB looks up temperature-dependent $c_p(T)$ from the Burcat database.

## Solid Phase (`type = solid`)

```ini
[GPB-Phase2]
type     = solid
name     = solido
material = UC
thermo   = SP-database
```

With `thermo = SP-database`, properties are read from the ATLAS internal solid-phase database.

---

## `thermo` Options for Condensed / Solid

| Value | Description |
|-------|-------------|
| `fixed` | Constant $c_p$, $\rho$, $k$ from INI keys |
| `Burcat` | Temperature-dependent $c_p$ from the Burcat database |
| `SP-database` | ATLAS solid-phase database |

## Required Keys by Type

| `type` | Required keys |
|--------|--------------|
| `condensed` | `material` or (`cp`, `rho`) |
| `condensed-dispersed` | `material`, `rho` |
| `solid` | `material` |
