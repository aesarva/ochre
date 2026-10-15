import MetricsCore
import SwiftUI

struct DiskTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let d = snapshot?.disk
        let h = store.history
        VStack(alignment: .leading, spacing: 12) {
            ForEach(d?.volumes ?? [], id: \.path) { volume in
                volumeRow(volume)
            }
            MirroredChart(up: h.points(.diskRead, now: now), down: h.points(.diskWrite, now: now),
                          upLabel: "Чтение", downLabel: "Запись",
                          upCurrent: d?.readPerSecond, downCurrent: d?.writePerSecond, format: Format.rate)
        }
    }

    private func volumeRow(_ volume: VolumeInfo) -> some View {
        let total = Double(max(volume.total, 1))
        let used = volume.total >= volume.available ? Double(volume.total - volume.available) : 0
        let lowSpace = Double(volume.available) / total < 0.1
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(volume.name).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("свободно \(Format.bytes(volume.available)) из \(Format.bytes(volume.total))")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(lowSpace ? Color.heatHot : .secondary)
            }
            GeometryReader { geo in
                Capsule().fill(Color.primary.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(lowSpace ? Color.heatHot : Color.primary.opacity(0.45))
                            .frame(width: geo.size.width * used / total)
                    }
            }
            .frame(height: 4)
        }
    }
}
