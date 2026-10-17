<p align="center">
  <img src="docs/images/icon.png" width="128" height="128" alt="Ochre icon">
</p>

<h1 align="center">Ochre</h1>

<p align="center">
  <b>A menu bar system monitor for macOS that shows you the chip, not just numbers.</b><br>
  Every CPU core and the GPU on a split-flap die map. The tiles heat up with the load.
</p>

<p align="center">
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-2b2b2b?logo=apple&logoColor=white">
  <img alt="Swift 6.2" src="https://img.shields.io/badge/Swift-6.2-CC8F25?logo=swift&logoColor=white">
  <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-E3BF5C">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-B4462A"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <img src="docs/images/hero.jpg" alt="Ochre's popover open under its menu bar item: the die map shows six Super cores at 100% in hot red and twelve Performance cores in graphite, with CPU, memory, network and disk sparklines below" width="820">
</p>

## Why Ochre

- **The chip, not an average.** Most monitors give you one CPU percentage. Ochre draws the processor as it is built: cores grouped by cluster (Super and Performance on M5, Performance and Efficiency on M1–M4), each with its own load, plus a strip of GPU cores. A single runaway thread stands out right away.
- **Colour means heat and nothing else.** The interface is graphite and paper. Colour appears only where something is working hard: amber, then ember, then hot red. You can read it at a glance from across the desk.
- **Light on the system.** Measured on an M5 Pro: about 0.7% of one core and 13 MB of memory with the panel closed. Temperatures are read every 15 s in the background and every 2 s while the panel is open.
- **Native.** Swift, SwiftUI and AppKit with Liquid Glass. No Electron, no helper daemon, no root password, no kernel extension.
- **Private.** No network requests, no analytics, no account. All data comes from local system interfaces and never leaves your Mac.
- **Alerts that wait before firing.** A threshold has to hold for a set time before you are notified, so a five-second spike doesn't ping you.

## Features

### Menu bar

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/menubar-dark.png">
  <img src="docs/images/menubar-light.png" width="180" alt="Menu bar item: a mini die map, CPU 37%, RAM 62%, 67°">
</picture>

Choose any mix of segments: **mini die map**, **CPU graph**, **CPU %**, **memory %**, **temperature** and **network speed**. Each segment has a fixed width, so the menu bar doesn't jump when numbers change. A segment turns red while its alert is active, and VoiceOver reads the whole item as one sentence.

### Die map and CPU

<img src="docs/images/tab-cpu.jpg" align="right" width="300" alt="CPU tab: the die map and load history for all cores, Super cores and Performance cores">

- One split-flap tile per core with its load in percent. The tile flips when the value changes.
- Cores are grouped by performance level as macOS reports them, and each cluster shows its temperature.
- A GPU strip with one cell per GPU core, lit by utilization.
- Load history for the whole CPU and for each cluster.
- The **Overview** tab also shows CPU, memory, network and disk sparklines and the three busiest processes.

<br clear="right">

### Memory

<img src="docs/images/tab-memory.jpg" align="right" width="300" alt="Memory tab: composition bar with app, wired, compressed and cached memory, usage history, pressure and swap">

- A composition bar: app memory, wired, compressed and cached.
- Used memory with history.
- Memory pressure as macOS reports it, plus swap usage.

<br clear="right">

### Network and disk

<img src="docs/images/tab-network.jpg" align="right" width="300" alt="Network tab: download and upload rates with peaks and history, active interface and totals since launch">

- Download and upload rates with history and peak values.
- The active interface and the traffic total since launch.
- The disk tab shows free space on the startup volume and read/write speed with peaks.

<br clear="right">

### Sensors

<img src="docs/images/tab-sensors.jpg" align="right" width="300" alt="Sensors tab: grouped temperatures, fan speeds, GPU load, system power and battery health">

- Temperatures, grouped: CPU (every die sensor, expandable), SSD, battery, power controller.
- Fan speeds, GPU load and total system power in watts.
- Battery: charge, cycle count, health, power draw and charging state.

<br clear="right">

### Processes and alerts

- The **Processes** tab lists the top processes by CPU or by memory. Click a row to copy its PID.
- Alerts for **CPU temperature**, **CPU load**, **memory pressure** and **low disk space**. You set the threshold and how long it must hold, for example 95 °C for 30 s. When an alert fires, you get a system notification and the menu bar segment turns red.
- Refresh interval of 1, 2 or 5 seconds, and an option to launch at login.

## Install

A signed and notarized DMG will be published on the [Releases](../../releases) page. Until then, build it from source; it takes about a minute.

### Build from source

Requirements: macOS 26 or later and Xcode 26 (Swift 6.2).

```sh
git clone https://github.com/aesarva/ochre.git
cd ochre
scripts/build-app.sh              # universal build/Ochre.app (arm64 + x86_64)
# ARCHS=arm64 scripts/build-app.sh  # Apple Silicon only, faster
cp -R build/Ochre.app /Applications/
open /Applications/Ochre.app
```

Ochre lives only in the menu bar (no Dock icon). Settings are under **Settings** at the bottom of the panel. Allow notifications when asked if you want alerts.

If `xcode-select` points to the Command Line Tools, set `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before running `swift` commands. The build scripts do this themselves.

## How it works

| Metric | Source |
| --- | --- |
| Per-core CPU load | `host_processor_info` |
| Core clusters | `hw.nperflevels`, `hw.perflevel*` sysctls |
| GPU load and core count | IORegistry `IOAccelerator` performance statistics |
| Memory, pressure, swap | `host_statistics64`, `kern.memorystatus_vm_pressure_level`, `vm.swapusage` |
| Network | `NET_RT_IFLIST2` interface counters |
| Disk | `IOBlockStorageDriver` statistics, volume capacity |
| Temperatures (Apple Silicon) | IOHID event system sensors |
| Fans, power, Intel sensors | SMC |
| Battery | `AppleSmartBattery` |
| Processes | `proc_pid_rusage`, `proc_pidpath` |

The code is split into two parts. **MetricsCore** holds the collectors, sampling, history, alert engine and presentation logic, and is covered by unit tests. **Ochre** is the SwiftUI/AppKit app on top of it. Temperature sensors and the SMC are reached through a small C shim (`CPrivateAPI`).

```
Sources/
  CPrivateAPI/   C declarations for IOHID and SMC
  MetricsCore/   collectors, sampling, alerts, presentation (testable)
  Ochre/         menu bar item, popover, settings, notifications
Tests/           MetricsCoreTests
Resources/       Info.plist, Icon Composer icon
scripts/         build-app.sh, release.sh
site/            static landing page (RU/EN)
```

## Limitations

- Sensors are read through private macOS interfaces (IOHID and SMC). Their names and availability vary between Mac models, and a future macOS update can change them. That is also why Ochre is not in the Mac App Store.
- On Intel Macs CPU temperatures are not available, because there are no HID sensors. Fans and power are still read from the SMC.
- Processes owned by other users and by root can't be inspected without elevated rights, so they are left out.
- The interface is currently in Russian only.

## Development

```sh
swift test                         # unit tests for MetricsCore
ARCHS=arm64 scripts/build-app.sh   # quick local build
```

Debug launch arguments:

- `-OpenPopoverOnLaunch YES` opens the panel on start.
- `-PopoverTab <tab>` chooses the starting tab.
- `-SnapshotDir <path>` saves PNGs of the menu bar item, every tab and the settings, without needing Screen Recording permission.

### Releasing

`scripts/release.sh <version>` builds a universal app, signs it with a Developer ID certificate, notarizes and staples both the app and the DMG, and checks the result with Gatekeeper. The output is `dist/Ochre-<version>.dmg`.

One-time setup:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create a **Developer ID Application** certificate in Xcode → Settings → Accounts → Manage Certificates.
3. Store notarization credentials:
   ```sh
   xcrun notarytool store-credentials Ochre --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
   ```

If you have several signing identities, choose one with `SIGN_IDENTITY="Developer ID Application: …"`. `scripts/release.sh <version> --unsigned` runs every step except signing and notarization.

Builds that used the old bundle identifiers (`com.alexsarva.StatusApp`, `local.statusapp.StatusApp`) have their settings moved over on first launch.

### Landing page

`site/` is a static page with no build step. Preview it with `cd site && python3 -m http.server`. Before publishing, put `dist/Ochre.dmg` next to `site/index.html`, because the download buttons link to it.

## License

[MIT](LICENSE) © 2026 Alex Sarva.
The landing page bundles Golos Text and Fira Sans Condensed under the SIL Open Font License; the license texts are in [`site/fonts`](site/fonts).
