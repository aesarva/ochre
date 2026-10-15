import MetricsCore
import SwiftUI

struct SettingsView: View {
    let settings: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem { Text("Общие") }
            MenuBarSettingsTab(settings: settings)
                .tabItem { Text("Строка меню") }
            AlertSettingsTab(settings: settings)
                .tabItem { Text("Оповещения") }
        }
        .frame(width: 420, height: 420)
    }
}

struct GeneralSettingsTab: View {
    let settings: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Picker("Интервал обновления", selection: $settings.settings.refreshInterval) {
                ForEach(AppSettings.allowedIntervals, id: \.self) { Text("\(Int($0)) с").tag($0) }
            }
            Toggle("Запускать при входе", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        try LaunchAtLogin.set(newValue)
                        launchError = nil
                    } catch {
                        launchError = "Не удалось изменить автозапуск: \(error.localizedDescription)"
                    }
                    launchAtLogin = LaunchAtLogin.isEnabled
                }))
            if let launchError {
                Text(launchError).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

struct MenuBarSettingsTab: View {
    let settings: SettingsStore

    private static func title(_ item: MenuBarItem) -> String {
        switch item {
        case .icon: "Иконка"
        case .cpuGraph: "Мини-график CPU"
        case .cpuPercent: "Загрузка CPU"
        case .memoryPercent: "Память"
        case .temperature: "Температура"
        case .network: "Сеть"
        }
    }

    var body: some View {
        Form {
            ForEach(MenuBarItem.allCases, id: \.self) { item in
                Toggle(Self.title(item), isOn: Binding(
                    get: { settings.settings.menuBarItems.contains(item) },
                    set: { on in
                        if on { settings.settings.menuBarItems.insert(item) }
                        else { settings.settings.menuBarItems.remove(item) }
                    }))
            }
        }
        .formStyle(.grouped)
    }
}

struct AlertSettingsTab: View {
    let settings: SettingsStore

    private struct Spec {
        let title: String
        let range: ClosedRange<Double>?
        let step: Double
        let unit: String
        let hasDuration: Bool
    }

    private static func spec(_ kind: AlertKind) -> Spec {
        switch kind {
        case .cpuTemperature: Spec(title: "Температура CPU", range: 60...110, step: 1, unit: "°C", hasDuration: true)
        case .cpuLoad: Spec(title: "Загрузка CPU", range: 50...100, step: 5, unit: "%", hasDuration: true)
        case .memoryPressure: Spec(title: "Давление памяти", range: nil, step: 1, unit: "", hasDuration: false)
        case .diskSpace: Spec(title: "Свободное место", range: 1...100, step: 1, unit: "ГиБ", hasDuration: false)
        }
    }

    private func rule(_ kind: AlertKind) -> Binding<AlertRuleConfig> {
        Binding(
            get: { settings.settings.alerts.rule(kind) },
            set: { settings.settings.alerts.rules[kind] = $0 })
    }

    var body: some View {
        Form {
            ForEach(AlertKind.allCases, id: \.self) { kind in
                let spec = Self.spec(kind)
                let rule = rule(kind)
                Section {
                    Toggle(spec.title, isOn: rule.enabled)
                    if let range = spec.range {
                        Stepper(value: rule.threshold, in: range, step: spec.step) {
                            Text("Порог: \(Int(rule.wrappedValue.threshold)) \(spec.unit)")
                        }
                    }
                    if spec.hasDuration {
                        Stepper(value: rule.duration, in: 0...600, step: 10) {
                            Text("Длительность: \(Int(rule.wrappedValue.duration)) с")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
