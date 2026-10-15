import MetricsCore
import SwiftUI

struct OverviewTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let tiles = OverviewTile.visible(in: snapshot)
        let grid = tiles.filter { $0 != .battery }
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(grid, id: \.self) { tile in
                    tileView(tile, snapshot: snapshot, now: now)
                }
            }
            if tiles.contains(.battery), let battery = snapshot?.battery {
                Text(batteryText(battery))
                    .font(.system(size: 12).monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            Text("Топ процессов").font(.caption).foregroundStyle(.secondary)
            if let rows = snapshot?.processes, !rows.isEmpty {
                ProcessListView(rows: rows, limit: 5)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func batteryText(_ b: BatteryStats) -> String {
        let health = b.healthPercent.map { Format.percent($0) + " здоровья" } ?? "—"
        return "\(Format.percent(b.percent)) · \(health) · \(Format.watts(b.powerWatts))"
    }

    @ViewBuilder
    private func tileView(_ tile: OverviewTile, snapshot: Snapshot?, now: TimeInterval) -> some View {
        let h = store.history
        let alerts = store.activeAlerts
        switch tile {
        case .cpu:
            TileView(title: "CPU", value: Format.percent(snapshot?.cpu?.totalPercent),
                     highlighted: alerts.contains(.cpuLoad),
                     points: h.points(.cpuTotal, now: now), color: .blue)
        case .memory:
            TileView(title: "Память", value: Format.percent(snapshot?.memory?.usedPercent),
                     highlighted: alerts.contains(.memoryPressure),
                     points: h.points(.memoryUsed, now: now), color: .purple)
        case .temperature:
            TileView(title: "Температура", value: Format.celsius(snapshot?.sensors?.cpuCelsius),
                     highlighted: alerts.contains(.cpuTemperature),
                     points: h.points(.cpuTemperature, now: now), color: .red)
        case .gpu:
            TileView(title: "GPU", value: Format.percent(snapshot?.gpu?.utilizationPercent),
                     highlighted: false, points: h.points(.gpu, now: now), color: .orange)
        case .network:
            TileView(title: "Сеть",
                     value: "↓" + Format.compactRate(snapshot?.network?.downPerSecond)
                        + " ↑" + Format.compactRate(snapshot?.network?.upPerSecond),
                     highlighted: false, points: h.points(.networkDown, now: now), color: .cyan)
        case .disk:
            TileView(title: "Диск", value: Format.bytes(snapshot?.disk?.systemVolumeAvailable) + " своб.",
                     highlighted: alerts.contains(.diskSpace),
                     points: h.points(.diskRead, now: now), color: .green)
        case .battery:
            EmptyView()
        }
    }
}
