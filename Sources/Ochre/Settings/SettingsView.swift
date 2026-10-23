import MetricsCore
import SwiftUI

struct SettingsView: View {
    let settings: SettingsStore
    let store: MetricsStore?
    let updates: UpdateController

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings, updates: updates)
                .fittedForm()
                .tabItem { Text("Общие") }
            MenuBarSettingsTab(settings: settings, store: store)
                .fittedForm()
                .tabItem { Text("Строка меню") }
            AlertSettingsTab(settings: settings)
                .fittedForm()
                .tabItem { Text("Оповещения") }
        }
        .frame(width: 420)
    }
}

extension View {
    /// Форма высотой по содержимому — окно подстраивается под вкладку без пустого места.
    func fittedForm() -> some View {
        scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
    }
}

struct GeneralSettingsTab: View {
    let settings: SettingsStore
    let updates: UpdateController
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
                Label(launchError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
            }
            Section("Обновления") {
                Toggle("Проверять обновления автоматически", isOn: Binding(
                    get: { updates.automaticallyChecks },
                    set: { updates.automaticallyChecks = $0 }))
                LabeledContent("Версия \(updates.currentVersion) (\(updates.currentBuild))") {
                    Button("Проверить сейчас") { updates.checkNow() }
                        .disabled(isBusy)
                }
                if let status = updateStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// «Проверить сейчас» недоступна, пока идёт обновление и когда Ochre открыт из образа DMG.
    private var isBusy: Bool {
        switch updates.model.state {
        case .checking, .downloading, .installing, .needsMove: true
        default: false
        }
    }

    private var updateStatus: String? {
        switch updates.model.state {
        case .checking: "Проверка обновлений…"
        case .upToDate: "Установлена последняя версия"
        case .available(let version, _): "Доступна версия \(version)"
        case .failed(let message): "Не удалось обновить: \(message)"
        case .needsMove: "Перенесите Ochre в «Программы», чтобы получать обновления"
        case .idle, .downloading, .installing: nil
        }
    }
}

struct MenuBarSettingsTab: View {
    let settings: SettingsStore
    let store: MetricsStore?

    private static func title(_ item: MenuBarItem) -> String {
        switch item {
        case .icon: "Мини-кристалл"
        case .cpuGraph: "Мини-график CPU"
        case .cpuPercent: "Загрузка CPU"
        case .memoryPercent: "Память"
        case .temperature: "Температура"
        case .network: "Сеть"
        }
    }

    private var preview: NSImage {
        let latest = store?.latest
        let cpu = latest.map { store?.history.points(.cpuTotal, now: $0.uptime).map(\.value) ?? [] } ?? []
        return MenuBarRenderer.image(MenuBarContent.segments(items: settings.settings.menuBarItems, snapshot: latest,
                                                             cpuHistory: cpu, active: store?.activeAlerts ?? []))
    }

    var body: some View {
        Form {
            Section("Предпросмотр") {
                HStack {
                    Spacer()
                    Image(nsImage: preview)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
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
                            Text("Порог: \(String(format: "%.0f", rule.wrappedValue.threshold)) \(spec.unit)")
                        }
                    }
                    if spec.hasDuration {
                        Stepper(value: rule.duration, in: 0...600, step: 10) {
                            Text("Длительность: \(String(format: "%.0f", rule.wrappedValue.duration)) с")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
