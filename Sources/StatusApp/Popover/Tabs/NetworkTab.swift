import MetricsCore
import SwiftUI

struct NetworkTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let n = snapshot?.network
        let h = store.history
        VStack(alignment: .leading, spacing: 10) {
            HistoryChart(title: "Приём ↓ " + Format.rate(n?.downPerSecond),
                         points: h.points(.networkDown, now: now), color: .cyan,
                         yDomain: nil, valueLabel: { Format.rate($0) })
            HistoryChart(title: "Отдача ↑ " + Format.rate(n?.upPerSecond),
                         points: h.points(.networkUp, now: now), color: .orange,
                         yDomain: nil, valueLabel: { Format.rate($0) })
            VStack(spacing: 4) {
                DetailRow(label: "Интерфейс", value: n == nil ? "—" : (n?.interface ?? "en*"))
                DetailRow(label: "Всего с запуска ↓", value: Format.bytes(n?.totalDown))
                DetailRow(label: "Всего с запуска ↑", value: Format.bytes(n?.totalUp))
            }
        }
    }
}
