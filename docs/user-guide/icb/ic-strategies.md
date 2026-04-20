# IC Strategies

::: warning Work in progress
This page is being populated. See `src/hydra-tools/ICB/` source files for current strategy implementations.
:::

## Available Strategies

### Direct Assignment

| Strategy | Description |
|----------|-------------|
| `uniform-ig` | Uniform primitive-variable state for an ideal-gas phase |
| `uniform-rf` | Uniform state for a real-fluid phase |
| `uniform-sp` | Uniform state for a solid-particle phase |
| `uniform-dp` | Uniform state for a condensed dispersed phase |

### Profile-Based

| Strategy | Description |
|----------|-------------|
| `profile-ig` | Read a 1-D profile and map onto the 3-D block |

### Interpolation

| Strategy | Description |
|----------|-------------|
| `interpolate` | Interpolate a solution from a different (coarser/finer) mesh |
| `interpolate-conservative` | Conservative interpolation preserving integral quantities |

### Restart / Import

| Strategy | Description |
|----------|-------------|
| `import` | Import a Hydra-format solution file |
| `restart` | Continue from an existing Hydra restart file |
