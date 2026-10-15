import MetricsCore
import SwiftUI

struct MemoryTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let m = snapshot?.memory
        VStack(alignment: .leading, spacing: 10) {
            HistoryChart(title: "Использовано: " + Format.percent(m?.usedPercent),
                         points: store.history.points(.memoryUsed, now: now), color: .purple,
                         yDomain: 0...100, valueLabel: { Format.percent($0) })
            VStack(spacing: 4) {
                DetailRow(label: "Приложения", value: Format.bytes(m?.app))
                DetailRow(label: "Wired", value: Format.bytes(m?.wired))
                DetailRow(label: "Сжатая", value: Format.bytes(m?.compressed))
                DetailRow(label: "Кэш", value: Format.bytes(m?.cached))
                DetailRow(label: "Давление", value: pressureText(m?.pressure),
                          valueColor: m?.pressure == .critical ? .red : .primary)
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

    private func swapText(_ m: MemoryStats?) -> String {
        guard let m else { return "—" }
        return "\(Format.bytes(m.swapUsed)) / \(Format.bytes(m.swapTotal))"
    }
}
