import MetricsCore
import SwiftUI

struct CPUTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let now = snapshot?.uptime ?? MonotonicClock.now()
        let h = store.history
        VStack(alignment: .leading, spacing: 12) {
            if snapshot?.cpu != nil || snapshot?.gpu != nil {
                DieMapView(cpu: snapshot?.cpu, gpu: snapshot?.gpu, cpuCelsius: snapshot?.sensors?.cpuCelsius,
                           size: .large, temperatureHighlighted: store.activeAlerts.contains(.cpuTemperature))
            }
            HistoryChart(title: "Всего", value: Format.percent(snapshot?.cpu?.totalPercent),
                         points: h.points(.cpuTotal, now: now), yDomain: 0...100,
                         valueLabel: { Format.percent($0) }, highlighted: store.activeAlerts.contains(.cpuLoad))
            ForEach(snapshot?.cpu?.clusters ?? [], id: \.level) { cluster in
                HistoryChart(title: cluster.name, value: Format.percent(cluster.percent),
                             points: h.points(.cluster(cluster.level), now: now), yDomain: 0...100,
                             valueLabel: { Format.percent($0) })
            }
        }
    }
}
