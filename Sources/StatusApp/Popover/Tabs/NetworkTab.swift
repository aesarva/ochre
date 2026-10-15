import MetricsCore
import SwiftUI

struct NetworkTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let n = snapshot?.network
        let h = store.history
        VStack(alignment: .leading, spacing: 12) {
            MirroredChart(up: h.points(.networkDown, now: now), down: h.points(.networkUp, now: now),
                          upLabel: "Приём", downLabel: "Отдача",
                          upCurrent: n?.downPerSecond, downCurrent: n?.upPerSecond, format: Format.rate)
            VStack(spacing: 4) {
                DetailRow(label: "Интерфейс", value: n == nil ? "—" : (n?.interface ?? "en*"))
                DetailRow(label: "Принято с запуска", value: Format.bytes(n?.totalDown))
                DetailRow(label: "Отдано с запуска", value: Format.bytes(n?.totalUp))
            }
        }
    }
}
