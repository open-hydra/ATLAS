# Contributing

Contribute to ATLAS development!

## Code of Conduct

TODO: Add or reference code of conduct
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

- Keep PRs focused on single feature/fix
- Include tests for new functionality
- Update relevant documentation
- Follow [Code Style Guide](./code-style)
- Ensure CI/CD passes

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

TODO: Document testing requirements

```bash
# Run full test suite
cd build
ctest --output-on-failure

# Run specific tests
ctest -R TestName --output-on-failure

# Build and test
make && !ctest
```

## Documentation

### When to Update Docs

- Adding new features
- Changing behavior
- Fixing user-facing bugs
- Improving clarity

### How to Update Docs

1. Edit relevant `.md` files in `docs/`
2. Follow [VitePress format](https://vitepress.dev/)
3. Test locally:
   ```bash
   cd docs
   npx vitepress build
   ```

## Development Resources

- **Code Style**: [Code Style Guide](./code-style)
- **Build Guide**: [Build Instructions](./build)
- **Architecture**: [Project Structure](./structure)
- **Testing**: [Testing Guide](./testing)

## Questions?

- 💬 GitHub Discussions
- 📧 Email maintainers
- 📖 Check existing documentation
- 🤝 Ask in pull requests

## Attribution

Contributors are recognized in:
- `LICENSE` or `CONTRIBUTORS` file
- GitHub contributor graph
- TODO: Other attribution methods

---

**Thank you for contributing!** 🙏

See also: [Code Style](./code-style), [Testing](./testing)
