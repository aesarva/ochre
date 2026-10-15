import Charts
import MetricsCore
import SwiftUI

/// Зеркальный график: первая серия — область вверх от оси, вторая — вниз. Монохромный.
struct MirroredChart: View {
    let up: [HistoryPoint]
    let down: [HistoryPoint]
    let upLabel: String
    let downLabel: String
    let upCurrent: Double?
    let downCurrent: Double?
    let format: (Double?) -> String

    private struct Sample: Identifiable {
        let id: String
        let t: TimeInterval
        let value: Double
        let series: String
    }

    var body: some View {
        let samples = up.map { Sample(id: "u\($0.t)", t: $0.t, value: $0.value, series: "up") }
            + down.map { Sample(id: "d\($0.t)", t: $0.t, value: -$0.value, series: "down") }
        let peak = max(up.map(\.value).max() ?? 0, down.map(\.value).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 4) {
            legendRow(upLabel, current: upCurrent, peak: up.map(\.value).max())
            Chart {
                ForEach(samples) { s in
                    AreaMark(x: .value("t", s.t), y: .value("v", s.value), series: .value("s", s.series))
                        .foregroundStyle(Color.primary.opacity(s.series == "up" ? 0.35 : 0.18))
                    LineMark(x: .value("t", s.t), y: .value("v", s.value), series: .value("s", s.series))
                        .foregroundStyle(Color.primary.opacity(s.series == "up" ? 0.85 : 0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                }
                RuleMark(y: .value("0", 0))
                    .foregroundStyle(Color.primary.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartYScale(domain: -peak...peak)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 90)
            legendRow(downLabel, current: downCurrent, peak: down.map(\.value).max())
        }
    }

    private func legendRow(_ label: String, current: Double?, peak: Double?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Text(format(current))
            Spacer()
            Text("пик " + format(peak)).foregroundStyle(.tertiary)
        }
        .font(.system(size: 12).monospacedDigit())
    }
}
