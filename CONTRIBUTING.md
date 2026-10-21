# Contributing

## Branches

- `main` holds released code only. It changes only when `develop` is merged into it for a release.
- `develop` is the integration branch. Every change reaches it through a merge, never through a direct commit.
- Each feature, fix or improvement gets its own branch from `develop`:
  - `feature/<name>` for new functionality;
  - `fix/<name>` for bug fixes;
  - `chore/<name>`, `docs/<name>` or `perf/<name>` for everything else.
- When the work is done and `swift test` passes, merge the branch into `develop` with `git merge --no-ff`, then delete it.

```sh
git switch develop && git pull
git switch -c feature/battery-graph
# ...commits...
git switch develop
git merge --no-ff feature/battery-graph
git branch -d feature/battery-graph
git push
```

Releases: merge `develop` into `main` with `--no-ff`, tag the merge `v<version>`, then run `scripts/release.sh <version>`.

## Before merging

- `swift test` passes.
- `ARCHS=arm64 scripts/build-app.sh` builds, and the app runs.
- Commit messages follow the existing style: `feat:`, `fix:`, `perf:`, `docs:`, `refactor:`, `chore:`.
