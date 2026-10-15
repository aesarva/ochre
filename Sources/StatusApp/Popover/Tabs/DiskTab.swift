import MetricsCore
import SwiftUI

struct DiskTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let d = snapshot?.disk
        let h = store.history
        VStack(alignment: .leading, spacing: 10) {
            HistoryChart(title: "Чтение " + Format.rate(d?.readPerSecond),
                         points: h.points(.diskRead, now: now), color: .green,
                         yDomain: nil, valueLabel: { Format.rate($0) })
            HistoryChart(title: "Запись " + Format.rate(d?.writePerSecond),
                         points: h.points(.diskWrite, now: now), color: .red,
                         yDomain: nil, valueLabel: { Format.rate($0) })
            ForEach(d?.volumes ?? [], id: \.path) { volume in
                VStack(alignment: .leading, spacing: 3) {
                    Text(volume.name).font(.system(size: 12, weight: .medium))
                    let used = volume.total >= volume.available ? volume.total - volume.available : 0
                    ProgressView(value: Double(used), total: Double(max(volume.total, 1)))
                    Text("свободно \(Format.bytes(volume.available)) из \(Format.bytes(volume.total))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
