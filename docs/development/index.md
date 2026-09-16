# Development

ATLAS is a mixed-language project. Pre-processing tools are implemented in **Fortran 2008** (BCB, ICB, MDB, STB) and **Python 3** (GPB, KAnT). Both language tracks share the same CMake build system.

## Language Tracks

| Track | Tools | Entry point |
|-------|-------|-------------|
| [Fortran](./fortran-guide.md) | BCB, ICB, MDB, STB | CMake → `make` |
| [Python](./python-guide.md) | GPB, KAnT | `ATLAS <TOOL>` (or `python3 src/<TOOL>`) |

## Where To Go

| Page | Covers |
|---|---|
| [Build Instructions](./build.md) | Prerequisites, `install.sh`, CMake options, troubleshooting |
| [Project Structure](./structure.md) | Source tree, components, dependencies, databases |
| [Fortran Development Guide](./fortran-guide.md) | Module conventions, types, coding patterns |
| [Python Development Guide](./python-guide.md) | Package layout, PiNeR, adding a phase type |
| [Testing](./testing.md) | Registered CTest cases and what each proves |
| [Contributing Guide](./contributing.md) | Branching, PRs, review process |
| [Code Style](./code-style.md) | Naming and formatting conventions |
| [Versioning](./versioning.md) | Semantic versioning rules for change classification |

## First Build

```bash
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS
git submodule update --init --recursive
./install.sh build
```

!!! note "Use `install.sh` for the first build"
    `CMakePresets.json` is **generated** by `install.sh` (it holds machine-local
    library and compiler paths and is git-ignored), so `cmake --preset default`
    only works after a first `./install.sh build`. Afterwards, rebuild from the
    source root with `cmake --preset default && cmake --build build`.

    [Build Instructions](./build.md) has the prerequisites, the full set of
    `install.sh` flags, and the Python/conda environment setup.

## Getting Help

- **GitHub Issues** — Report bugs or request features
- **GitHub Discussions** — Ask questions and discuss development
- **[Contributing Guide](./contributing.md)** — Detailed contribution workflow
