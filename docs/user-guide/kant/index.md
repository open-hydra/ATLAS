# KAnT — Kinetic Analyzer and Tester

KAnT runs zero-dimensional and one-dimensional chemistry analyses from an INI file. It is used to validate mechanisms, transport data, and phase settings before running a larger ATLAS workflow.

!!! tip "Where KAnT fits"
    Use KAnT to check thermodynamic and kinetic inputs in isolation. It is a fast way to catch inconsistent species definitions, unexpected ignition behavior, or transport issues before generating tables or starting a CFD run.

---

## Simulation Types

<div class="grid cards" markdown>

-   :material-chemical-weapon: **Chemical Equilibrium**

    ---

    Compute the equilibrium state for a mixture at a specified temperature and pressure.

    **What you get:** equilibrium composition and adiabatic flame temperature.

    **When to use:** sanity-check a mechanism or compare a model against a known equilibrium limit.

-   :material-fire: **Ignition Delay**

    ---

    Integrate a zero-dimensional reactor until the thermal runaway condition is reached.

    **What you get:** ignition delay time, temperature history, and species evolution.

    **When to use:** validate chemistry before 3-D combustion simulations or compare against shock-tube data.

-   :material-flask: **Ignition Delay with Reference Data**

    ---

    Same ignition-delay calculation, with optional experimental data loaded from a reference case.

    **What you get:** computed ignition delay overlaid with the selected reference dataset.

    **When to use:** mechanism validation against published experiments.

-   :material-clock-fast: **Time Evolution**

    ---

    Integrate a zero-dimensional constant-pressure or constant-volume reactor forward in time.

    **What you get:** temperature, pressure, and species history over the integration window.

    **When to use:** characterize transient reactor kinetics or generate validation data for post-processing.

-   :material-waves: **Counterflow Diffusion Flame**

    ---

    Solve a steady one-dimensional counterflow diffusion flame between a fuel stream and an oxidizer stream.

    **What you get:** temperature and species profiles, plus extinction-related flame data.

    **When to use:** validate transport and finite-rate chemistry for diffusion-flame problems.

</div>

---

## Command Line

Run KAnT from an ATLAS simulation directory:

```bash
ATLAS KAnT
```

You can also run it directly from the Python source tree:

```bash
python3 -B /path/to/KAnT [--plot] [<ini-file>]
```

or as a module:

```bash
python3 -m kant
```

If no input file is passed, KAnT looks for `kant.ini` first and then `input.ini` in the current directory. Passing `--plot` opens the Matplotlib figures for the computed results.

## Input File

KAnT reads one or both of these sections from the INI file:

- `[KAnT-Simulation0D]`
- `[KAnT-Simulation1D]`

The 0-D section enables equilibrium, ignition-delay, and time-evolution runs. The 1-D section enables the counterflow flame solver.

### 0-D Configuration

The main keys are:

| Key | Meaning |
|-----|---------|
| `type` | Reactor type, such as `HP`, `LP`, or `UV` |
| `equilibrium` | Enable the equilibrium calculation |
| `ignition-delay` | Enable the ignition-delay calculation |
| `time-evolution` | Enable the transient reactor calculation |
| `case` | Reference case name from `data/reference/cases.yaml` |
| `fuel` | Fuel stream composition |
| `oxidizer` | Oxidizer stream composition |
| `fuel-T` | Fuel stream temperature in K |
| `oxidizer-T` | Oxidizer stream temperature in K |
| `pressure` | Pressure sweep in bar |
| `of` | Mixture-ratio sweep |
| `temperature` | Temperature sweep in K |
| `reactions` | Mechanism list |
| `thermo` | Optional thermodynamic model override |
| `tend` | Final integration time in s |
| `nstep` | Number of output points |

For `pressure`, `of`, and `temperature`, KAnT accepts either explicit arrays or sweep helpers:

- `pressure-linear`, `of-linear`, `temperature-linear`
- `pressure-exp`, `of-exp`, `temperature-exp`

If `fuel` or `oxidizer` is given as a bare species name, KAnT converts it to a unit-composition stream internally.

### 1-D Configuration

The 1-D counterflow section uses these keys:

| Key | Meaning |
|-----|---------|
| `fuel` | Fuel stream composition |
| `oxidizer` | Oxidizer stream composition |
| `fuel-T` | Fuel stream temperature in K |
| `oxidizer-T` | Oxidizer stream temperature in K |
| `pressure` | Operating pressure in bar |
| `of` | Mixture ratio |
| `mdot` | Total mass flux in kg/m^2/s |
| `width` | Domain width in m |
| `reactions` | Mechanism list |
| `thermo` | Optional thermodynamic model override |

## Output

KAnT writes Tecplot ASCII output to `KAnT-out.dat` in the current working directory. Each simulated model is written as a separate zone in the same file.

If plotting is enabled, KAnT also opens a Matplotlib window for the computed results.

## Reference Cases

Reference datasets for the ignition-delay examples are stored under `data/reference/`. The packaged cases are the same ones used by the tutorial page and the regression tests.

See the [KAnT tutorials](../../tutorials/kant/index.md) for case-by-case walkthroughs.
