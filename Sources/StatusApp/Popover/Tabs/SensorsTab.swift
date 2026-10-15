import MetricsCore
import SwiftUI

struct SensorsTab: View {
    let store: MetricsStore

    var body: some View {
        let snapshot = store.latest
        let sensors = snapshot?.sensors
        VStack(alignment: .leading, spacing: 10) {
            section("Температуры") {
                if let temps = sensors?.temperatures, !temps.isEmpty {
                    ForEach(temps, id: \.name) { DetailRow(label: $0.name, value: Format.celsius($0.celsius)) }
                } else {
                    DetailRow(label: "—", value: "—")
                }
            }
            if let fans = sensors?.fans, !fans.isEmpty {
                section("Вентиляторы") {
                    ForEach(fans, id: \.index) { fan in
                        DetailRow(label: "Вентилятор \(fan.index + 1)",
                                  value: fan.rpm == 0 ? "остановлен" : Format.rpm(fan.rpm))
                    }
                }
            }
            section("GPU") {
                DetailRow(label: "Загрузка", value: Format.percent(snapshot?.gpu?.utilizationPercent))
            }
            section("Мощность системы") {
                DetailRow(label: "Потребление", value: Format.watts(sensors?.systemPowerWatts))
            }
            if let b = snapshot?.battery {
                section("Батарея") {
                    DetailRow(label: "Заряд", value: Format.percent(b.percent))
                    DetailRow(label: "Циклы", value: b.cycleCount.map { String($0) } ?? "—")
                    DetailRow(label: "Здоровье", value: Format.percent(b.healthPercent))
                    DetailRow(label: "Мощность", value: Format.watts(b.powerWatts))
                    DetailRow(label: "Состояние",
                              value: b.isCharging ? "Заряжается" : (b.onExternalPower ? "От сети" : "От батареи"))
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
