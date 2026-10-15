import Foundation

public enum MenuBarSegment: Equatable, Sendable {
    /// Мини-кристалл: ячейки ядер; пустой массив — данных CPU ещё нет.
    case miniDie([MiniDieCell])
    case cpuGraph([Double])
    /// `widthTemplate` — обычная наибольшая ширина значения (две цифры): под неё резервируется место,
    /// чтобы значок не менял ширину на переходах вроде 9 → 10 (иначе открытая панель сдвигается за ним).
    /// Редкие трёхзначные значения просто чуть шире шаблона.
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
                result.append(text("CPU " + Format.percent(snapshot?.cpu?.totalPercent), template: "CPU 00%",
                                   kind: .cpuLoad, active: active, shown: &highlightedKinds))
            case .memoryPercent:
                result.append(text("RAM " + Format.percent(snapshot?.memory?.usedPercent), template: "RAM 00%",
                                   kind: .memoryPressure, active: active, shown: &highlightedKinds))
            case .temperature:
                result.append(text(Format.celsius(snapshot?.sensors?.cpuCelsius), template: "00°",
                                   kind: .cpuTemperature, active: active, shown: &highlightedKinds))
            case .network:
                let net = snapshot?.network
                result.append(.text("↓" + Format.compactRate(net?.downPerSecond)
                                    + " ↑" + Format.compactRate(net?.upPerSecond), highlighted: false,
                                    widthTemplate: "↓99.9M ↑99.9M"))
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
        (["Ochre"] + segments.compactMap { if case let .text(text, _, _) = $0 { text } else { nil } })
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
