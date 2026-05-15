# Contributing

Contribute to ATLAS development!

## Code of Conduct

ATLAS currently follows standard open-source collaboration expectations:

- Be respectful and constructive in reviews and discussions
- Assume good intent and focus feedback on code and behavior
- Avoid discriminatory, harassing, or hostile language

Until a dedicated `CODE_OF_CONDUCT.md` is added, treat GitHub community standards as the baseline for project interactions.
- Be respectful
- Be inclusive
- Help others

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ATLAS.git
   cd ATLAS
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Set up development environment**:
   ```bash
   ./install.sh
   # or see Build Instructions
   ```

## Making Changes

### Before You Start

- Check [existing issues](https://github.com/open-hydra/ATLAS/issues)
- Look for [ongoing discussions](https://github.com/open-hydra/ATLAS/discussions)
- Open an issue to discuss major changes

### Code Changes

1. **Make your changes** following [Code Style Guide](./code-style)
2. **Write tests** for new functionality
3. **Run tests locally**:
   ```bash
   cd build
   ctest --output-on-failure
   ```
4. **Update documentation** if needed
5. **Commit with clear messages**:
   ```bash
   git commit -m "Add feature X"
   git commit -m "Fix issue #123"
   ```

## Submitting Changes

### Pull Request Process

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a PR** on GitHub with:
   - Clear title describing the change
   - Reference any related issues (#123)
   - Description of what changed and why

3. **Address review feedback**:
   - Make requested changes
   - Push updates to same branch
   - Request re-review

4. **Merge** once approved

### PR Guidelines

- **Keep PRs focused**: One feature or bug fix per PR
- **Include tests**: New functionality must have tests  
- **Update docs**: If changing user-facing APIs, update [docs/development](./index)
- **Follow code style**: See [Code Style Guide](./code-style)
- **Ensure CI passes**: All GitHub Actions checks must pass
- **Meaningful commits**: Commit messages describe *what* and *why*
- **Reference issues**: Use `Fixes #123` in PR description if applicable
- **Declare SemVer impact**: Add `SemVer impact: PATCH|MINOR|MAJOR` with one-line rationale

### PR Checklist

Use this before submitting:

- [ ] Tests pass: `cd build && ctest --output-on-failure`
- [ ] New tests added for new functionality
- [ ] Code follows [Code Style Guide](./code-style)
- [ ] Documentation updated (if needed)
- [ ] Commit messages are clear
- [ ] SemVer impact is declared in PR description
- [ ] No unrelated changes included
- [ ] Branch is up-to-date with `main`

## Issue Tracking

### Reporting Bugs

Include:
- Clear description of issue
- Steps to reproduce
- Expected vs actual behavior
- Environment (OS, compiler, version)
- Relevant output/logs

### Feature Requests

Include:
- Clear description of feature
- Use case and motivation
- Possible implementation approach
- Examples or mockups

## Types of Contributions

### Code Contributions
- Bug fixes
- New features
- Performance improvements
- Refactoring

### Documentation
- User guide improvements
- Code documentation
- Examples and tutorials
- Troubleshooting guides

### Testing
- Bug reproductions
- Test cases
- CI/CD improvements

### Other
- Issue triage
- Community support
- Outreach

## Testing Your Changes

Minimum expectations before opening a PR:

- Build succeeds locally from a clean or updated build tree
- Relevant regression tests pass for touched areas
- Documentation changes are included when behavior or interfaces change

```bash
# Run full test suite
cd build
ctest --output-on-failure

# Run specific tests
ctest -R TestName --output-on-failure

# Build and test
cmake --build . && ctest --output-on-failure
```

## Documentation

### When to Update Docs

- Adding new features
- Changing behavior
- Fixing user-facing bugs
- Improving clarity

### How to Update Docs

1. Edit relevant `.md` files in `docs/`
2. Follow MkDocs + Material markdown conventions already used in the docs
3. Test locally:
   ```bash
   mkdocs build
   mkdocs serve
   ```

## Development Resources

- **Code Style**: [Code Style Guide](./code-style)
- **Build Guide**: [Build Instructions](./build)
- **Architecture**: [Project Structure](./structure)
- **Testing**: [Testing Guide](./testing)
- **Versioning**: [Semantic Versioning Guide](./versioning)

## Questions?

- 💬 GitHub Discussions
- 📧 Email maintainers
- 📖 Check existing documentation
- 🤝 Ask in pull requests

## Attribution

Contributors are recognized in:
- GitHub contributor graph
- `AUTHORS.md` updates when applicable
- Release notes and changelog entries for notable features/fixes

---

**Thank you for contributing!** 🙏

See also: [Code Style](./code-style), [Testing](./testing)
