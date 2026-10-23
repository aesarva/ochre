# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

delegated: the public product page is built in the separate `utils-landing` repo and served at https://utils.cyber-tech.online/ochre/ (Russian) and /en/ochre/ (English). It takes content and images from this repo (README, CHANGELOG, DESIGN.md, `docs/images/`, `site/img/`) and the version and DMG link from the latest GitHub release. `site/` in this repo is the earlier static landing and serves only as a content source until that page replaces it.

## Users

Mac owners on Apple Silicon, from technical users (developers, people who know what P-cores, SMC and swap are) to everyday owners who want to see what is heating up or slowing the Mac. The first impression must work for both; technical detail sits lower.

## Product Purpose

Ochre is a macOS menu-bar system monitor: CPU, memory, disk, network, GPU, battery, sensors (temperatures, fans, system power) and processes, shown in a popover from the menu bar. Success: a glance at the menu bar or the Overview tab tells which cores are loaded and whether the Mac is overheating.

## Positioning

The signature is the die map: the user's own chip drawn as its core clusters (e.g. 6 Super + 12 Performance cores on M5 Pro) plus a strip of GPU cores, each cell lit by load. A mini copy of the map lives in the menu bar. Colour in the interface means heat only: cool glass → amber → ember → heat red.

## Operating Context

Lives only in the menu bar (no Dock icon). Popover tabs: Overview, CPU, Memory, Network, Disk, plus Sensors and Processes under "More". Alerts (CPU temperature, CPU load, memory pressure, free disk space) raise a system notification and turn the value heat-red. Settings window (standard macOS toolbar tabs: General, Menu Bar, Alerts) chooses menu-bar items (mini die, CPU %, RAM %, temperature, network, sparkline), refresh interval, launch at login and automatic update checks. Updates: once a day Ochre checks GitHub (Sparkle); a found version shows a dot on the menu bar item and an Install and Relaunch button in the panel and in Settings, one click downloads, verifies the signature, replaces the app and relaunches it.

## Capabilities and Constraints

- Requires macOS 26 or later (Liquid Glass UI). Universal build (Apple Silicon and Intel); on Intel Macs temperatures are unavailable, fans and power still read via SMC.
- Reads sensors through private APIs (SMC, IOHID), so it is distributed outside the Mac App Store as a Developer ID–signed, Apple-notarized DMG.
- Measured on an M5 Pro with the popover closed (version 1.1.0, with the updater): about 0.5% of one core and about 14 MB of memory (phys_footprint). Temperatures refresh every 15 s while closed, 2 s while open.
- The only network request is the daily update check against GitHub; it sends no system data and can be turned off in Settings. No analytics, no account.
- Processes of other users and root are not readable and are skipped. Sensor names vary between Mac models.
- Interface language of the app: Russian.

## Brand Commitments

- Name: Ochre (renamed from StatusApp on 2026-10-16; the name is the colour of the heat palette). Bundle id `com.alexsarva.Ochre`.
- App icon: `Resources/AppIcon.icon` (die map with heat-lit cores on graphite).
- Price: free. Open source under the MIT license: https://github.com/aesarva/ochre. Linking to the repository and its Releases page is fine.
- The landing page is bilingual, Russian and English, with a switcher.

## Evidence on Hand

- Real UI renders of every popover tab, the menu bar item and settings, produced by the app's `-SnapshotDir` debug export.
- App icon artwork: `Resources/AppIcon.icon/Assets/die.png`.
- The measured resource figures above (single machine, M5 Pro).
- Published releases on GitHub (tag `vX.Y.Z`, asset `Ochre-X.Y.Z.dmg`, signed and notarized); the latest is always at https://github.com/aesarva/ochre/releases/latest. Release history is in `CHANGELOG.md`.
- Absent, must not be fabricated: testimonials, press, download or user counts, ratings, benchmarks against other apps.

## Product Principles

1. Show the machine, not a dashboard: the chip's real topology is the interface.
2. Colour is a measurement: warm colour always means heat or load, never decoration.
3. Stay out of the way: lightweight enough to never become the thing it monitors.
4. Glanceable first, detailed on demand.
