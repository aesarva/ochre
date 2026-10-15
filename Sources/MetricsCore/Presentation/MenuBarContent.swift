import Foundation

public enum MenuBarSegment: Equatable, Sendable {
    /// Мини-кристалл: ячейки ядер; пустой массив — данных CPU ещё нет.
    case miniDie([MiniDieCell])
    case cpuGraph([Double])
    /// `widthTemplate` — самое широкое значение сегмента: под него резервируется место, чтобы значок
    /// в строке меню не менял ширину вместе с числом (иначе открытая панель сдвигается вслед за ним).
    case text(String, highlighted: Bool, widthTemplate: String? = nil)
}

public enum MenuBarContent {
    static let graphSamples = 10

    public static func segments(items: Set<MenuBarItem>, snapshot: Snapshot?, cpuHistory: [Double],
                                active: Set<AlertKind>) -> [MenuBarSegment] {
        var result: [MenuBarSegment] = []
        var highlightedKinds: Set<AlertKind> = []

        for item in MenuBarItem.allCases where items.contains(item) {
            switch item {
            case .icon:
                result.append(miniDie(snapshot))
            case .cpuGraph:
                result.append(.cpuGraph(Array(cpuHistory.suffix(graphSamples))))
            case .cpuPercent:
                result.append(text("CPU " + Format.percent(snapshot?.cpu?.totalPercent), template: "CPU 100%",
                                   kind: .cpuLoad, active: active, shown: &highlightedKinds))
            case .memoryPercent:
                result.append(text("RAM " + Format.percent(snapshot?.memory?.usedPercent), template: "RAM 100%",
                                   kind: .memoryPressure, active: active, shown: &highlightedKinds))
            case .temperature:
                result.append(text(Format.celsius(snapshot?.sensors?.cpuCelsius), template: "100°",
                                   kind: .cpuTemperature, active: active, shown: &highlightedKinds))
            case .network:
                let net = snapshot?.network
                result.append(.text("↓" + Format.compactRate(net?.downPerSecond)
                                    + " ↑" + Format.compactRate(net?.upPerSecond), highlighted: false,
                                    widthTemplate: "↓1023M ↑1023M"))
            }
        }

        if result.isEmpty { result = [miniDie(snapshot)] }
        if !active.isSubset(of: highlightedKinds) {
            result.append(.text("⚠", highlighted: true))
        }
        return result
    }

    /// Подпись значка для VoiceOver: текст сегментов рисуется картинками фиксированной ширины.
    public static func spokenLabel(_ segments: [MenuBarSegment]) -> String {
        (["StatusApp"] + segments.compactMap { if case let .text(text, _, _) = $0 { text } else { nil } })
            .joined(separator: ", ")
    }

    private static func miniDie(_ snapshot: Snapshot?) -> MenuBarSegment {
        .miniDie(snapshot?.cpu.map(MiniDieLayout.cells) ?? [])
    }

    private static func text(_ string: String, template: String, kind: AlertKind, active: Set<AlertKind>,
                             shown: inout Set<AlertKind>) -> MenuBarSegment {
        let highlighted = active.contains(kind)
        if highlighted { shown.insert(kind) }
        return .text(string, highlighted: highlighted, widthTemplate: template)
    }
}
