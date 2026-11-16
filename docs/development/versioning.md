# Versioning

ATLAS follows [Semantic Versioning 2.0.0](https://semver.org/), as ORION, OSLO, FLINT, MOSE and ICE do:
a release is a tag `vX.Y.Z` on `main`, and its changes are listed in
[CHANGELOG.md](https://github.com/open-hydra/ATLAS/blob/main/CHANGELOG.md). Before 1.0.0 a breaking
change raises `Y`, anything else `Z`.

## How ATLAS requires its libraries

`CMakeLists.txt` names the releases ATLAS is tested with:

| Library | Requirement | How |
|---|---|---|
| ORION | `ATLAS_ORION_VERSION 2.1`: 2.1.0 and later, up to 3.0.0 excluded | `semver_dependency` of `cmake/SemVerDeps.cmake` |
| FiNeR | `ATLAS_FINER_TAG v2.3.0` | the submodule `lib/FiNeR`, checked against its `VERSION` file |
| CEA | `ATLAS_CEA_VERSION 3.3.4` | the submodule `lib/cea` (or `CEA_PATH`), checked against its `project()` |
| PiNeR | the commit of the gitlink | the submodule `lib/PiNeR` |

`cmake/SemVerDeps.cmake` is FLINT's file, copied unmodified: update it from FLINT, never here.
A requirement accepts the releases from its own up to the next change of its leftmost nonzero
number (`2.1` accepts 2.1.0 to 3.0.0 excluded, `0.3` accepts 0.3.x only). Only `vX.Y.Z` tags are
releases; a tag such as `v2.2.0-rc1` is never selected.

ATLAS needs ORION 2: GPB reads its point files with `tec_read_structured_multiblock`, since 2.0.0
removed `tec_read_points_multivars`. 2.1.0 is the release the tests are run with.

A submodule must be checked out at the commit this ATLAS commit records, or the configure stops:
run `git submodule update --init` and configure again. Bump a gitlink together with its release in
`CMakeLists.txt`.

FiNeR's own libraries are fetched as FiNeR's author does (`fobis fetch`: their default
branches, `ATLAS_FINER_DEPS=FREE`). If an upstream change breaks ATLAS, `ATLAS_FINER_DEPS=BACKUP`
checks out the releases of `ATLAS_FINER_BACKUP_PINS`, the ones MOSE, ICE and GROOT share.

## Which release a build gets

The release of ORION is, in order:

1. the clone given with `-DFETCHCONTENT_SOURCE_DIR_ORION=<folder>` (`install.sh --include-orion`),
   as it is; the configure stops if it is not a release that ATLAS accepts
   (`-DATLAS_PIN_CHECK=WARNING` builds it on purpose);
2. the release in `deps.lock`, if it satisfies the requirement;
3. the newest release on GitHub that satisfies it.

The configure checks the release out in `lib/ORION` and writes it to `deps.lock`; both are git
ignored. `-DSEMVER_UPDATE=ALL` (`install.sh build --update-deps`) selects the newest one again.
`deps.lock` is not committed: in hydra, the top of the build tree, hydra chooses the releases.

An external FiNeR (`-DFETCHCONTENT_SOURCE_DIR_FINER`, `install.sh --include-finer`) must be
`ATLAS_FINER_TAG`. A relative path to an external clone is taken from the ATLAS folder.

## The requirements in hydra

Hydra builds ATLAS with the same ORION as its solvers. When hydra selects ORION with SemVerDeps,
ATLAS's requirement is checked against that release, so:

- a new **major** of ORION in ATLAS's requirement is a major (before 1.0.0, minor) release of ATLAS;
- a later **minor** (from ORION `2.1` to `2.2`) is a minor (before 1.0.0, patch) release;
- another FiNeR or CEA release is a major (before 1.0.0, minor) release of ATLAS.

## Making a release

1. Choose the number from the `[Unreleased]` entries of `CHANGELOG.md`.
2. Rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and open a new, empty `[Unreleased]` above it.
3. Merge into `main` through a pull request.
4. Tag the merge commit and push the tag:
   ```bash
   git fetch origin
   git tag vX.Y.Z origin/main
   git push origin vX.Y.Z
   ```

!!! warning "A published tag stays"
    A pushed tag is never moved or deleted: other projects' lock files name it.
