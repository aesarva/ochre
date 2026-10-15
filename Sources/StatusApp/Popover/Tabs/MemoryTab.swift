import MetricsCore
import SwiftUI

struct MemoryTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let m = snapshot?.memory
        VStack(alignment: .leading, spacing: 12) {
            if let m {
                StackedBar(segments: [("Приложения", Double(m.app)), ("Wired", Double(m.wired)),
                                      ("Сжатая", Double(m.compressed)), ("Кэш", Double(m.cached))],
                           total: Double(m.total))
            }
            HistoryChart(title: "Использовано", value: Format.percent(m?.usedPercent),
                         points: store.history.points(.memoryUsed, now: now), yDomain: 0...100,
                         valueLabel: { Format.percent($0) },
                         highlighted: store.activeAlerts.contains(.memoryPressure))
            VStack(spacing: 4) {
                DetailRow(label: "Давление", value: pressureText(m?.pressure), valueColor: pressureColor(m?.pressure))
                DetailRow(label: "Swap", value: swapText(m))
            }
        }
    }

    private func pressureText(_ pressure: MemoryPressure?) -> String {
        switch pressure {
        case .normal: "Нормальное"
        case .warning: "Повышенное"
        case .critical: "Критическое"
        case nil: "—"
        }
    }

    private func pressureColor(_ pressure: MemoryPressure?) -> Color {
        switch pressure {
        case .warning: HeatScale.amber.swiftUIColor
        case .critical: .heatHot
        default: .primary
        }
    }

    private func swapText(_ m: MemoryStats?) -> String {
        guard let m else { return "—" }
        return "\(Format.bytes(m.swapUsed)) / \(Format.bytes(m.swapTotal))"
    }
}
