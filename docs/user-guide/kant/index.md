# KAnT — Kinetics and Thermodynamics

KAnT runs zero-dimensional thermochemical simulations. It is designed as a validation and analysis companion to the ATLAS pre-processing suite: verify that your phase configuration produces the expected thermodynamics before running Hydra.

---

## Simulation Types

<div class="grid cards" markdown>

-   :material-fire: **Ignition Delay**

    ---

    Compute the auto-ignition delay time from a given initial mixture, temperature, and pressure. Integrates the 0-D reactor until the thermal runaway condition is met.

    **What you get:** ignition delay time $\tau_{ign}$, temperature history, species evolution.

    **When to use:** validate fuel/oxidiser chemistry before 3-D combustion simulations; compare against shock-tube data.

-   :material-fire-alert: **Ignition Delay (Experimental Comparison)**

    ---

    Same as ignition delay, with direct comparison against user-supplied experimental data.

    **What you get:** computed vs. measured $\tau_{ign}$ over a range of temperatures or equivalence ratios.

    **When to use:** mechanism validation; checking that the kinetic data used in GPB matches published experiments.

-   :material-chemical-weapon: **Chemical Equilibrium**

    ---

    Compute the equilibrium composition for a given mixture, temperature, and pressure. Does not require a reaction mechanism — uses Cantera's thermodynamic minimisation directly.

    **What you get:** equilibrium mole/mass fractions, adiabatic flame temperature, thermodynamic properties at equilibrium.

    **When to use:** sanity-check of GPB equilibrium inputs; rapid estimation of combustion product composition.

-   :material-waves: **Counterflow Diffusion Flame**

    ---

    Simulate a steady counterflow diffusion flame between a fuel stream and an oxidiser stream at given strain rates.

    **What you get:** temperature and species profiles across the flame, extinction strain rate.

    **When to use:** validate transport and kinetic properties for diffusion flame modelling; estimate scalar dissipation rates.

-   :material-clock-fast: **Time Evolution**

    ---

    Integrate a 0-D constant-pressure or constant-volume reactor from a given initial state forward in time.

    **What you get:** temperature, pressure, and species history over the integration period.

    **When to use:** characterise reactor kinetics; generate validation data for CFD post-processing; test mechanism stiffness.

</div>

---

## Summary

| Simulation | Key output | Mechanism needed? |
|-----------|-----------|-------------------|
| Ignition delay | $\tau_{ign}(T, p, \phi)$ | Yes |
| Ignition delay + exp. | $\tau_{ign}$ vs. data | Yes |
| Equilibrium | Species, $T_{ad}$ | No |
| Counterflow flame | Profiles, extinction | Yes |
| Time evolution | Species, T, p vs. t | Yes |

---

## How KAnT Connects to GPB

KAnT and GPB share the same Cantera and CEA backends. The typical validation workflow is:

1. Configure phases in GPB (species, mechanism, transport)
2. Run KAnT equilibrium or ignition-delay to verify the mechanism behaves as expected
3. If results match, proceed with GPB table generation and Hydra runs
4. Use KAnT post-run to compare 0-D predictions against Hydra scalar outputs

---

## Usage

```bash
python -m KAnT --input-file kant.ini
```

## Package Structure

```
src/KAnT/
├── config/       — configuration parsing
├── data/         — thermodynamic / kinetics data helpers
├── output/       — result writers
├── simulations/  — simulation drivers (one module per type)
└── utils/        — shared utilities
```

## Test Cases

Five reference cases are provided in `test/KAnT/`:

- `counterflow/`
- `equilibrium/`
- `ignition_delay/`
- `ignition_delay_exp/`
- `time_evolution/`

See the [tutorials](/tutorials/kant/) for step-by-step walkthroughs.
