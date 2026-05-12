# IC Strategies

Full reference for all strategies recognised by ICB. See `src/hydra-tools/ICB/` for current implementations.

## Direct Assignment

| Strategy | Code | Phase | When to use |
|----------|------|-------|-------------|
| Uniform ideal gas | `uniform-ig` | Ideal gas | Cold-start from a known reference condition (freestream, chamber, stagnation state). |
| Uniform real fluid | `uniform-rf` | Real fluid | Cold-start for high-pressure or cryogenic flow simulations. |
| Uniform condensed | `uniform-dp` | Condensed (dispersed) | Initial spray distribution at rest or with a known velocity. |
| Uniform solid | `uniform-sp` | Solid | Initial wall temperature for conjugate heat transfer setups. |

## Profile-Based

| Strategy | Code | Phase | When to use |
|----------|------|-------|-------------|
| 1-D profile | `profile-ig` | Ideal gas | Inlet boundary-layer or jet profiles; non-uniform freestream conditions. |

## Nozzle Initialization

| Strategy | Code | Phase | When to use |
|----------|------|-------|-------------|
| De Laval nozzle | `nozzle` | Ideal gas | Cold-start of a supersonic nozzle. Requires STB area schedule. Avoids starting transients. |

## Interpolation

| Strategy | Code | Phase | When to use |
|----------|------|-------|-------------|
| Interpolate | `interpolate` | Any | Mesh refinement studies, p-adaptive restarts, transferring results between grid generations. |

## Restart / Import

| Strategy | Code | Phase | When to use |
|----------|------|-------|-------------|
| Import | `import` | Any | Load a Hydra-format solution file generated externally. |
| Restart | `restart` | Any | Standard simulation continuation; recovering from an interrupted run. |
