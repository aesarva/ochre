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


## Before merging

- `swift test` passes.
- `ARCHS=arm64 scripts/build-app.sh` builds, and the app runs.
- Commit messages follow the existing style: `feat:`, `fix:`, `perf:`, `docs:`, `refactor:`, `chore:`.

## Debugging

Launch arguments for `build/Ochre.app/Contents/MacOS/Ochre`:

- `-OpenPopoverOnLaunch YES` opens the panel on start.
- `-PopoverTab <tab>` chooses the starting tab (`overview`, `cpu`, `memory`, `network`, `disk`, `sensors`, `processes`).
- `-SnapshotDir <path>` saves PNGs of the menu bar item, every tab and the settings, without Screen Recording permission.

## Releasing

1. Merge `develop` into `main` with `--no-ff` and tag the merge `v<version>`.
2. On `main`, run `scripts/release.sh <version>`. It builds a universal app, signs it with Developer ID, notarizes and staples the app and the DMG, and checks both with Gatekeeper. The result is `dist/Ochre-<version>.dmg`.
3. Push `main` and the tag, then fast-forward `develop` to `main`.
4. Create a GitHub release for the tag and attach the DMG in the **Attach binaries** area.
5. Update the download links (button and Install section) in `README.md` and `README.ru.md`.

One-time setup:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create a **Developer ID Application** certificate in Xcode → Settings → Accounts → Manage Certificates.
3. Store notarization credentials:
   ```sh
   xcrun notarytool store-credentials Ochre --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
   ```

With several signing identities, choose one with `SIGN_IDENTITY="Developer ID Application: …"`. `scripts/release.sh <version> --unsigned` runs every step except signing and notarization.

## Landing page

`site/` is a static page with no build step. Preview it with `cd site && python3 -m http.server`. Its download buttons link to `Ochre.dmg` next to `index.html`; `scripts/release.sh` also writes that file to `dist/`.

## Notes

Builds that used the old bundle identifiers (`com.alexsarva.StatusApp`, `local.statusapp.StatusApp`) have their settings moved over on first launch.
