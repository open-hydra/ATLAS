# GPB — General Phase Builder

GPB reads an INI file describing one or more thermodynamic phases and writes binary property tables for Hydra.

## Usage

```bash
export ATLASDIR=/path/to/ATLAS
python -m GPB --input-file input.ini
```

### CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--input-file` | `input.ini` | Path to the INI configuration file |
| `--write-config-doc` | — | Print a documentation string for every known INI key and exit |

## Phase Sections

The INI file can contain an arbitrary number of phase sections named `[GPB-Phase1]`, `[GPB-Phase2]`, etc. GPB reads them in order until a section is not found.

```ini
[GPB-Phase1]
name = gas
type = ideal-gas
...

[GPB-Phase2]
name = particles
type = condensed-dispersed
...
```

## Supported Phase Types

| `type` value | Description |
|--------------|-------------|
| `ideal-gas` (default) | Thermally / calorically perfect gas |
| `heavy-gas` | Ideal-gas with heavy-gas pressure scaling |
| `condensed` | Condensed liquid phase (constant or T-variable) |
| `condensed-dispersed` | Condensed dispersed particles |
| `solid` | Solid material |
| `real-fluid` | Real-fluid lookup table |

## Output

Binary property files are written to `fromATLAStoSolver/` (controlled by `OUTPATH` in `config.py`). Heavy-gas files have the suffix `-HG` appended to the name.

See the sections below for full per-type parameter reference:

- [Input Reference](./input-reference)
- [Ideal-Gas & Heavy-Gas](./ideal-gas)
- [Condensed & Solid](./condensed-solid)
- [Real Fluid](./real-fluid)
- [Output Files](./output)
