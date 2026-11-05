# Tutorial: Fixed-Gas Mixture

**Source case:** `test/GPB/IG-fixgas`

This tutorial shows how to define an ideal-gas phase entirely from explicit physical constants — no species database required. Use this approach when you have experimental or reference values for viscosity and thermal conductivity.

## What You'll Learn

- How to specify a multi-species ideal-gas phase using scalar property lists
- Which properties are required and which are derived automatically

## The Input File

```ini
[GPB-Phase1]
name    = gasmix
type    = ideal-gas
species = N2f Hef
gamma   = 1.4  1.66
mw      = 28.0 4.0
mil     = 1e-5 1.3e-5
kl      = 0.25 0.30
```

### Key Points

| Key | Meaning |
|-----|---------|
| `species = N2f Hef` | Two species: nitrogen-frozen (`N2f`) and helium (`Hef`) — arbitrary names |
| `gamma = 1.4 1.66` | Specific-heat ratios; one value per species |
| `mw = 28.0 4.0` | Molar masses (g mol⁻¹) |
| `mil = 1e-5 1.3e-5` | Dynamic viscosities (Pa s) — constant (calorically perfect) |
| `kl = 0.25 0.30` | Thermal conductivities (W m⁻¹ K⁻¹) — constant |

GPB derives $c_p = \gamma R / (\gamma - 1)$, $c_v = c_p / \gamma$, and $R = R_u / M_w$ automatically. GPB uses the exact SI value of the universal gas constant, $R_u = 8314.46261815324$ J/(kmol K) ($N_A k_B$, CODATA 2018 / SI 2019, identical to Cantera's `gas_constant`); the bundled NASA CEA library keeps its own constant, 8314.51 J/(kmol K).

!!! tip "Over-specified sets"
    You can provide more keys than strictly needed (e.g. both `gamma` and `cp`). GPB will check consistency and raise an error if the set is contradictory.

## Running

Run the case on a copy: GPB writes `fromATLAStoSolver/` in the directory it runs in, which would change the test
deck of the repository.

```bash
cp -r $ATLASDIR/test/GPB/IG-fixgas .
cd IG-fixgas
ATLAS GPB
```

## Expected Output

```
fromATLAStoSolver/gasmix-phase.txt
fromATLAStoSolver/gasmix-thermo.dat
fromATLAStoSolver/gasmix-transport.dat
fromATLAStoSolver/gasmix-composition.txt
```

`gasmix-thermo.dat` holds the constant $c_p$ (with $h$ and $s$) of each species and `gasmix-transport.dat` the constant
$\mu$ and $\lambda$, from 1 K to 5000 K with a 1 K step.
