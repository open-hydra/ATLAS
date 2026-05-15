# Versioning

ATLAS follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: incompatible user-facing changes
- **MINOR**: backward-compatible new functionality
- **PATCH**: backward-compatible fixes and documentation-only corrections

## How To Classify A Change

### PATCH (`x.y.Z`)

Use patch releases for:

- Bug fixes that do not break existing workflows
- Numerical fixes that keep input/output contracts unchanged
- Build, CI, and documentation fixes

### MINOR (`x.Y.z`)

Use minor releases for:

- New backward-compatible capabilities
- New optional inputs with safe defaults
- New tools/tutorials/docs that do not change existing behavior

### MAJOR (`X.y.z`)

Use major releases for:

- Removal or renaming of user-facing options/files/interfaces
- Behavior changes that require users to update inputs or workflows
- Output format changes that break downstream consumers

## Compatibility Rules In ATLAS

Treat these as public interfaces when deciding SemVer impact:

- Command-line and script workflows (`ATLAS.sh`, `install.sh`)
- `input.ini` keys and expected file layout in test/tutorial cases
- Output files consumed by downstream solvers
- Documented behavior in user and development guides

If a change modifies one of the interfaces above in a non-backward-compatible way, it is at least a **MAJOR** bump.

## PR Checklist For Versioning

When opening a PR, include a short SemVer note:

- `SemVer impact: PATCH` (or `MINOR` / `MAJOR`)
- One-line reason tied to user-facing behavior

Example:

```text
SemVer impact: MINOR
Reason: adds a new optional BCB input key with default behavior unchanged.
```

## Release Notes Guidance

For release notes, group changes by SemVer intent:

- **Breaking Changes** (MAJOR)
- **Added** (MINOR)
- **Fixed** (PATCH)

This makes upgrade risk clear for users and downstream projects.
