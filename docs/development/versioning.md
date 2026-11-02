# Versioning

ATLAS follows [Semantic Versioning 2.0.0](https://semver.org/), as FLINT, ORION and OSLO do:

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: incompatible user-facing changes
- **MINOR**: backward-compatible new functionality
- **PATCH**: backward-compatible fixes and documentation-only corrections

A release is a tag `vX.Y.Z` on `main`. The changes of each release are listed in
[CHANGELOG.md](https://github.com/open-hydra/ATLAS/blob/main/CHANGELOG.md).

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
- A later minor release of ORION in ATLAS's requirement

### MAJOR (`X.y.z`)

Use major releases for:

- Removal or renaming of user-facing options/files/interfaces
- Behavior changes that require users to update inputs or workflows
- Output format changes that break downstream consumers
- A new major release of ORION, or another release of FiNeR or CEA, in ATLAS's requirement

## Compatibility Rules In ATLAS

Treat these as public interfaces when deciding SemVer impact:

- Command-line and script workflows (`ATLAS.sh`, `install.sh`)
- `input.ini` keys and expected file layout in test/tutorial cases
- Output files consumed by downstream solvers
- Documented behavior in user and development guides
- The requirements: the releases of ORION, FiNeR and CEA that ATLAS accepts

If a change modifies one of the interfaces above in a non-backward-compatible way, it is at least a **MAJOR** bump.

A numerical fix that changes results is a patch or a minor release, not a major one: a wrong result is not part
of the interface. Its changelog entry says which results change and by how much.

### The requirements

In hydra, the top-level project, the solvers and ATLAS build with the same clones of ORION and FiNeR, which
hydra gives ATLAS (see [External clones](./build.md#external-clones)). So:

- **A new major release of ORION in ATLAS's requirement is a major release of ATLAS.** Hydra's ORION would
  stop satisfying it, and the configure of ATLAS would stop with no change of hydra's own.
- **A later minor release is a minor release of ATLAS.** Raising the requirement from ORION 2 to 2.2 asks for
  2.2.0 or a later 2.x, which a hydra on the newest ORION 2 already gives.
- FiNeR and CEA are required by one release each: another one is a major release of ATLAS.

## How ATLAS requires its libraries

`CMakeLists.txt` requires ORION and FiNeR with `semver_dependency` of `cmake/SemVerDeps.cmake`, a copy of
FLINT's file, unmodified (every project carries one, and the newest copy in a build tree is used):

```cmake
semver_dependency(ORION GIT_REPOSITORY https://github.com/MarcoGrossi92/ORION.git VERSION 2 SOURCE_DIR lib/ORION)
semver_dependency(FiNeR GIT_REPOSITORY https://github.com/szaghi/FiNeR.git GIT_TAG v2.3.0
                  SOURCE_DIR lib/third_party/FiNeR)
```

A `VERSION` requirement accepts the releases from its own up to the next change of its leftmost nonzero number,
the one that a release of the library may not change without breaking its users:

| Requirement | Accepts |
|---|---|
| `2` | 2.0.0 and later, up to 3.0.0 excluded |
| `2.1` | 2.1.0 and later, up to 3.0.0 excluded |
| `0.3` | 0.3.0 and later, up to 0.4.0 excluded (before 1.0.0, a minor release may break) |
| `1.7 2` | 1.7.0 and later 1.x, or 2.x: the values are alternatives |

Only the tags `vX.Y.Z` are releases; a tag with a suffix, such as `v2.2.0-rc1`, is never selected. `GIT_TAG`
pins one tag, for a library that is not released in this way: FiNeR, a third-party library.

ATLAS requires the oldest release that has everything it uses, and raises the requirement when it starts to use
something newer, with a comment that says what. ORION: `2`, because ORION 2.0.0 removed
`tec_read_points_multivars` and ATLAS reads the point files of GPB with `tec_read_structured_multiblock`; the
test suite passes with 2.0.0 and 2.1.0.

CEA stays a git submodule (`lib/cea`), pinned by its commit; `ATLAS_CEA_VERSION` in `CMakeLists.txt` is checked
against the release CEA declares, also for an external CEA (`CEA_PATH`). FiNeR's own dependencies are fetched as
FiNeR's author does (`fobis fetch`, their default branches), or at the backup releases of
`ATLAS_FINER_BACKUP_PINS` with `ATLAS_FINER_DEPS=BACKUP` (see [Build](./build.md#libraries-releases-pins-and-external-clones)).

### Which release a build gets

The release of ORION is, in order:

1. the external clone given with `-DFETCHCONTENT_SOURCE_DIR_ORION=<folder>` (`install.sh --include-orion`), as it
   is: the configure stops when its version, the newest `vX.Y.Z` tag in its history, does not satisfy the
   requirement (`-DATLAS_PIN_CHECK=WARNING` builds it anyway);
2. the release in `deps.lock`, in the ATLAS folder, if it satisfies the requirement;
3. the newest release on GitHub that satisfies the requirement.

FiNeR is its tag, or the external clone of `-DFETCHCONTENT_SOURCE_DIR_FINER` (`install.sh --include-finer`), whose
`VERSION` must be that tag. At the end of the configure `deps.lock` lists the release of ORION selected, and the
next configure uses it without the network; `-DSEMVER_UPDATE=ORION` (`install.sh --update-deps`) selects the
newest one again. `deps.lock` is not committed: ATLAS is not the top of its build tree, hydra is, and chooses
the releases.

## PR Checklist For Versioning

When opening a PR, add an entry under `[Unreleased]` in `CHANGELOG.md` for every change that a user of ATLAS
sees, and include a short SemVer note:

- `SemVer impact: PATCH` (or `MINOR` / `MAJOR`)
- One-line reason tied to user-facing behavior

Example:

```text
SemVer impact: MINOR
Reason: adds a new optional BCB input key with default behavior unchanged.
```

## Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/): the entries of the next release
under `[Unreleased]`, each in its section (Added, Changed, Deprecated, Removed, Fixed). An entry says what changes
for the user and, for a change of results, which results and by how much. It begins with **Breaking.** when a
user or a project that uses ATLAS has to change with it, which makes the release a major one.

## Making a release

1. Choose the number from the entries under `[Unreleased]` in `CHANGELOG.md`: major if one is **Breaking**,
   otherwise minor if one adds something, otherwise patch.
2. In `CHANGELOG.md`, rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`, and open a new, empty `[Unreleased]` above
   it.
3. Merge into `main` through a pull request.
4. Tag the merge commit and push the tag:
   ```bash
   git fetch origin
   git tag vX.Y.Z origin/main
   git push origin vX.Y.Z
   ```
5. Optionally, publish a GitHub release from the tag, with the section of the changelog as its notes.

!!! warning "A published tag stays"
    Once pushed, a tag is never moved or deleted: the lock files of other projects name it, and a build of theirs
    would get other sources under the same number. A mistake in a release is corrected by the next release.
