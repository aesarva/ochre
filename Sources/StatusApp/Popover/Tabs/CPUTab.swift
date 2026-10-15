import Charts
import MetricsCore
import SwiftUI

struct CPUTab: View {
    let store: MetricsStore

    private static let levelColors: [Color] = [.orange, .blue, .green, .purple]

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let h = store.history
        VStack(alignment: .leading, spacing: 10) {
            HistoryChart(title: "Общая загрузка: " + Format.percent(snapshot?.cpu?.totalPercent),
                         points: h.points(.cpuTotal, now: now), color: .blue,
                         yDomain: 0...100, valueLabel: { Format.percent($0) })
            ForEach(snapshot?.cpu?.clusters ?? [], id: \.level) { cluster in
                HistoryChart(title: cluster.name + ": " + Format.percent(cluster.percent),
                             points: h.points(.cluster(cluster.level), now: now),
                             color: Self.color(level: cluster.level),
                             yDomain: 0...100, valueLabel: { Format.percent($0) })
            }
            if let cores = snapshot?.cpu?.cores, !cores.isEmpty {
                Text("Ядра").font(.caption).foregroundStyle(.secondary)
                Chart(cores, id: \.index) { core in
                    BarMark(x: .value("Ядро", String(core.index)), y: .value("Загрузка", core.percent))
                        .foregroundStyle(Self.color(level: core.level))
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(Format.percent(v)).font(.system(size: 9)) }
                        }
                    }
                }
                .frame(height: 70)
            }
        }
    }

    private static func color(level: Int) -> Color {
        levelColors[max(level, 0) % levelColors.count]
    }
}
