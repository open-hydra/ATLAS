# ICB Builders

Source: `src/hydra-tools/ICB/builder*.f90`

::: warning Work in progress
:::

## `build` (module `ic_builder_mod`)

Top-level subroutine; dispatches based on `strategy`.

```fortran
call build(cfg, block_idx, blk)
```

## Per-Strategy Builders

| Strategy | Module | Description |
|----------|--------|-------------|
| `uniform-ig` | `ic_builder_ig_mod` | Uniform ideal-gas state |
| `uniform-rf` | `ic_builder_rf_mod` | Uniform real-fluid state |
| `uniform-dp` | `ic_builder_dp_mod` | Uniform dispersed-phase state |
| `uniform-sp` | `ic_builder_sp_mod` | Uniform solid-particle state |
| `interpolate` | `ic_interpolation_mod` | Interpolate from different mesh |
| `import` | — | Import a Hydra solution file |
