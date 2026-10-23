# Changelog

Every release is on the [Releases](https://github.com/aesarva/ochre/releases) page as `Ochre-<version>.dmg`, signed with Developer ID and notarized by Apple. Dates are UTC.

## 1.1.4 — 2026-10-24

- Fixed: when an update offer was left uninstalled for a day, Ochre dropped it but its recheck was refused while Sparkle was still closing the previous session, leaving an Install button that did nothing until the next daily check (or for good with automatic checks off). The button now clears at once and the recheck runs after the session closes.

## 1.1.3 — 2026-10-23

- Native settings window: tabs with icons in the toolbar (General, Menu Bar, Alerts), the window title follows the selected tab, and the height adapts to each tab. The old segmented control on an inset box is gone.

## 1.1.2 — 2026-10-23

- When Check Now in Settings → General finds a new version, the button turns into Install and Relaunch, so you can update without leaving Settings. The line below it shows download progress.

## 1.1.1 — 2026-10-23

- Cancelling the administrator password prompt during installation offers the update again right away.
- Retry and Check Now are disabled while a check is already running.
- An update left uninstalled for a day is rechecked, so a newer release replaces an older offer.
- The menu bar item no longer redraws on every chunk of a download.
- If Ochre doesn't quit for installation, the installer asks again instead of staying on «Установка…».
- The app no longer bundles Sparkle's XPC services, which only sandboxed apps use.

## 1.1.0 — 2026-10-23

- Updates in one click: Ochre checks for a new version once a day (Sparkle). A found version shows a dot on the menu bar item and Install and Relaunch in the panel; one click downloads it, verifies its signature, replaces the app and relaunches it. Checks can be turned off in Settings.
- The daily update check against GitHub is the only network request; it sends no data about your Mac.
- Settings and Quit at the bottom of the panel are icons.
- Opened straight from the disk image, Ochre asks to be moved to Applications to receive updates.
- Version 1.0.0 has no updater: update it once by downloading the DMG.

## 1.0.0 — 2026-10-21

- First public release: a menu bar monitor with every CPU and GPU core on a die map, memory, network, disk, battery, temperatures, fans and system power, the busiest processes, and alerts for CPU temperature, CPU load, memory pressure and low disk space.
