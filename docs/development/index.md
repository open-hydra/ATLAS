# Development

ATLAS is a mixed-language project. Pre-processing tools are implemented in **Fortran 2008** (BCB, ICB, STB) and **Python 3** (GPB, KAnT). Both language tracks share the same CMake build system.

## Language Tracks

| Track | Tools | Entry point |
|-------|-------|-------------|
| [Fortran](./fortran-guide) | BCB, ICB, STB | CMake → `make` |
| [Python](./python-guide) | GPB, KAnT | `python -m <package>` |

## Quick Links

- **[Build Instructions](./build)** — Compile the Fortran tools from source
- **[Fortran Development Guide](./fortran-guide)** — Modules, types, coding conventions
- **[Python Development Guide](./python-guide)** — Package structure, conventions, testing
- **[Fortran Module Reference](./fortran-modules)** — All `.mod` files and their purpose
- **[Python Package Reference](./python-packages)** — All Python packages and public APIs
- **[Project Structure](./structure)** — Source tree overview
- **[Contributing Guide](./contributing)** — Branching, PRs, review process
- **[Testing](./testing)** — Running the test suite
- **[Code Style](./code-style)** — Naming and style conventions

## Setting Up Development Environment

TODO: Document development environment setup

```bash
# Clone repository
git clone https://github.com/open-hydra/ATLAS.git
cd ATLAS

# Create development branch
git checkout -b feature/my-feature

# Build for development
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
```

## Development Workflow

TODO: Document typical development workflow

1. Create feature branch
2. Make changes
3. Run tests
4. Submit pull request
5. Address review feedback

## Key Components

TODO: List and briefly describe key components

- **BCB**: Boundary Condition Block
- **ICB**: Initial Condition Block
- **STB**: [Description needed]
- **Core Libraries**: ...

## Documentation

TODO: Links to development documentation

- [Fortran API](./structure)
- [Module Documentation](/api-reference/)
- [Architecture Decisions](#)

## Getting Help

- 💬 Check discussions on GitHub
- 🐛 Report issues
- 📖 Read existing code
- 💡 Ask in pull requests

---

**Ready to start?** See [Build Instructions](./build).
