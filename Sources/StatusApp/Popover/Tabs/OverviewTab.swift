import MetricsCore
import SwiftUI

struct OverviewTab: View {
    let store: MetricsStore
    let onOpenCPU: () -> Void

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let h = store.history
        let alerts = store.activeAlerts
        VStack(alignment: .leading, spacing: 12) {
            if snapshot?.cpu != nil || snapshot?.gpu != nil {
                DieMapView(cpu: snapshot?.cpu, gpu: snapshot?.gpu, cpuCelsius: snapshot?.sensors?.cpuCelsius,
                           size: .compact, temperatureHighlighted: alerts.contains(.cpuTemperature),
                           onTap: onOpenCPU)
            }
            VStack(spacing: 9) {
                if let cpu = snapshot?.cpu {
                    MetricRow(title: "Процессор", value: Format.percent(cpu.totalPercent),
                              points: h.points(.cpuTotal, now: now), highlighted: alerts.contains(.cpuLoad))
                }
                if let mem = snapshot?.memory {
                    MetricRow(title: "Память", value: "\(Format.bytes(mem.used)) / \(Format.bytes(mem.total))",
                              points: h.points(.memoryUsed, now: now), highlighted: alerts.contains(.memoryPressure))
                }
                if let net = snapshot?.network {
                    MetricRow(title: "Сеть",
                              value: "↓\(Format.compactRate(net.downPerSecond)) ↑\(Format.compactRate(net.upPerSecond))",
                              points: h.points(.networkDown, now: now))
                }
                if let disk = snapshot?.disk, disk.systemVolumeAvailable != nil {
                    MetricRow(title: "Диск", value: Format.bytes(disk.systemVolumeAvailable) + " своб.",
                              points: h.points(.diskRead, now: now), highlighted: alerts.contains(.diskSpace))
                }
            }
            if let rows = snapshot?.processes, !rows.isEmpty {
                Divider().opacity(0.5)
                ProcessListView(rows: rows, limit: 3)
            }
        }
    }
}
