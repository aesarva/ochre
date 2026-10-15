# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

delegated: plain static HTML/CSS/JS with no build step, in `site/` of this repo. All URLs are relative so the folder can sit under its own path (for example `/statusapp/`) on a shared host the author will also use for other apps. Hosting provider is not chosen yet; the app is closed-source, so the site must not depend on this repo being public (Cloudflare Pages, or a separate public GitHub Pages repo, both fit).

## Users

Mac owners on Apple Silicon, from technical users (developers, people who know what P-cores, SMC and swap are) to everyday owners who want to see what is heating up or slowing the Mac. The first impression must work for both; technical detail sits lower.

## Product Purpose

StatusApp is a macOS menu-bar system monitor: CPU, memory, disk, network, GPU, battery, sensors (temperatures, fans, system power) and processes, shown in a popover from the menu bar. Success: a glance at the menu bar or the Overview tab tells which cores are loaded and whether the Mac is overheating.

## Positioning

The signature is the die map: the user's own chip drawn as its core clusters (e.g. 6 Super + 12 Performance cores on M5 Pro) plus a strip of GPU cores, each cell lit by load. A mini copy of the map lives in the menu bar. Colour in the interface means heat only: cool glass → amber → ember → heat red.

## Operating Context

Lives only in the menu bar (no Dock icon). Popover tabs: Overview, CPU, Memory, Network, Disk, plus Sensors and Processes under "More". Alerts (CPU temperature, CPU load, memory pressure, free disk space) raise a system notification and turn the value heat-red. Settings window chooses menu-bar items (mini die, CPU %, RAM %, temperature, network, sparkline) and refresh interval; launch at login.

## Capabilities and Constraints

- Requires macOS 26 or later (Liquid Glass UI). Universal build (Apple Silicon and Intel); on Intel Macs temperatures are unavailable, fans and power still read via SMC.
- Reads sensors through private APIs (SMC, IOHID), so it is distributed outside the Mac App Store as a Developer ID–signed, Apple-notarized DMG.
- Measured on an M5 Pro with the popover closed: about 0.7% CPU and about 13 MB of memory (phys_footprint). Temperatures refresh every 15 s while closed, 2 s while open.
- Processes of other users and root are not readable and are skipped. Sensor names vary between Mac models.
- Interface language of the app: Russian.

## Brand Commitments

- Name: StatusApp.
- App icon: `Resources/AppIcon.icon` (die map with heat-lit cores on graphite).
- Price: free. Source code is closed: no GitHub/source links on public surfaces.
- The landing page is bilingual, Russian and English, with a switcher.

## Evidence on Hand

- Real UI renders of every popover tab, the menu bar item and settings, produced by the app's `-SnapshotDir` debug export.
- App icon artwork: `Resources/AppIcon.icon/Assets/die.png`.
- The measured resource figures above (single machine, M5 Pro).
- Absent, must not be fabricated: testimonials, press, download or user counts, ratings, benchmarks against other apps, a published download URL (the notarized DMG is not released yet).

## Product Principles

1. Show the machine, not a dashboard: the chip's real topology is the interface.
2. Colour is a measurement: warm colour always means heat or load, never decoration.
3. Stay out of the way: lightweight enough to never become the thing it monitors.
4. Glanceable first, detailed on demand.
