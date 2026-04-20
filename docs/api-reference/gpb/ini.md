# GPB INI Parsers

Source: `src/hydra-tools/GPB/ini/`

::: warning Work in progress
Auto-generated API documentation is planned. For now, this page describes the module contracts.
:::

## `ini.common` — Shared Parameters

Parses keys common to all phase types: `name`, `type`, `Tmin`, `Tmax`.

```python
from GPB.ini.common import parse_common
cfg = parse_common(section)   # section: configparser.SectionProxy
# cfg.name, cfg.type, cfg.Tmin, cfg.Tmax
```

## `ini.ideal_gas` — Ideal-Gas / Heavy-Gas Parser

Extends `common` with: `phase`, `thermo`, `transport`, `reactions`, `species`, `add-species`, `mixture`, `mixture-name`, `inerts-mixing`, `gamma`, `cp`, `cv`, `R`, `mw`, `mil`, `kl`, `Pr`, `eq-*`, `CEA-file`, `CEA-section`.

## `ini.condensed` — Condensed / Solid Parser

Keys: `material`, `groups`, `k`, `cp`, `rho`, `thermo`.

## `ini.real_fluid` — Real-Fluid Parser

Keys: `fluid`, `pmin`, `pmax`, `Tmin`, `Tmax`, `NP`, `NH`, `model`.

## `ini.equilibrium` — Equilibrium Helper

Parses equilibrium subsection keys used by both Cantera (`eq-*`) and CEA (`CEA-*`) paths.
