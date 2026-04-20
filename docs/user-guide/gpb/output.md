# GPB Output Files

## Output Directory

By default GPB writes all output to `fromATLAStoSolver/` relative to the working directory. This is controlled by `OUTPATH` in `src/hydra-tools/GPB/config.py`.

## File Naming

```
<name>.bin           — ideal-gas / condensed / solid phase
<name>-HG.bin        — heavy-gas phase
<name>_rf.bin        — real-fluid lookup table
```

Where `<name>` is the value of the `name` key in the INI section (or the section name if `name` is not set).

## Binary Format

The binary layout is defined in `GPB/ideal_gas/io.py` (ideal-gas) and the equivalent `io.py` files in `condensed/` and `real_fluid/`. All files are Fortran-compatible unformatted binary (record-length headers).

### Ideal-Gas File Structure

1. **Header block** — number of species, temperature grid size, flags
2. **Temperature array** — $T_i$, $i = 1 \ldots N_T$
3. **Per-species thermo arrays** — $c_p(T_i)$, $h(T_i)$, $s^\circ(T_i)$
4. **Per-species transport arrays** — $\mu(T_i)$, $\lambda(T_i)$
5. **Mixture metadata** — molar masses, stoichiometry (if reactive)

### Real-Fluid Table Structure

1. **Header block** — grid dimensions ($N_P \times N_H$), pressure and enthalpy bounds
2. **Property arrays** — $\rho$, $T$, $c$, $\mu$, $\lambda$ on the $(p, h)$ grid

## Verification

After running GPB, check that `fromATLAStoSolver/` contains a `.bin` file for each `[GPB-Phase*]` section. Non-zero file sizes indicate successful generation.

```bash
ls -lh fromATLAStoSolver/
```
