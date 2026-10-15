import MetricsCore
import SwiftUI

struct SensorsTab: View {
    let store: MetricsStore
    @State private var cpuExpanded = false

    var body: some View {
        let snapshot = store.latest
        let sensors = snapshot?.sensors
        VStack(alignment: .leading, spacing: 14) {
            section("Температуры") {
                if let temps = sensors?.temperatures, !temps.isEmpty {
                    let groups = SensorPresentation.group(temps)
                    if !groups.cpu.isEmpty {
                        cpuRow(groups)
                        if cpuExpanded {
                            ForEach(Array(groups.cpu.enumerated()), id: \.offset) { _, r in
                                DetailRow(label: r.name, value: Format.celsius(r.celsius), valueColor: Self.tint(r.celsius)).padding(.leading, 14)
                            }
                        }
                    }
                    ForEach(Array(groups.other.enumerated()), id: \.offset) { _, r in
                        DetailRow(label: r.name, value: Format.celsius(r.celsius), valueColor: Self.tint(r.celsius))
                    }
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
            if let gpu = snapshot?.gpu?.utilizationPercent {
                section("GPU") {
                    DetailRow(label: "Загрузка", value: Format.percent(gpu))
                }
            }
            if let watts = sensors?.systemPowerWatts {
                section("Мощность системы") {
                    DetailRow(label: "Потребление", value: Format.watts(watts))
                }
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

    /// Температура окрашивается ступенчато по шкале нагрева; нейтральная — основным цветом.
    private static func tint(_ celsius: Double) -> Color {
        let level = HeatScale.temperatureLevel(celsius)
        return level == .neutral ? .primary : level.color.textColor
    }

    private func cpuRow(_ groups: SensorGroups) -> some View {
        Button { cpuExpanded.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: cpuExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                DetailRow(label: "CPU (\(groups.cpu.count) датч.)",
                          value: "макс \(Format.celsius(groups.cpuMax)) · сред. \(Format.celsius(groups.cpuAverage))",
                          valueColor: groups.cpuMax.map(Self.tint) ?? .primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Группа как в системных настройках: заголовок над подложкой, строки на слегка выделенном фоне.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
            VStack(alignment: .leading, spacing: 7) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 10, style: .continuous))
        }
    }
}
