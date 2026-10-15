import Foundation

public enum MenuBarSegment: Equatable, Sendable {
    case icon
    case cpuGraph([Double])
    case text(String, highlighted: Bool)
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
                result.append(.icon)
            case .cpuGraph:
                result.append(.cpuGraph(Array(cpuHistory.suffix(graphSamples))))
            case .cpuPercent:
                result.append(text("CPU " + Format.percent(snapshot?.cpu?.totalPercent),
                                   kind: .cpuLoad, active: active, shown: &highlightedKinds))
            case .memoryPercent:
                result.append(text("RAM " + Format.percent(snapshot?.memory?.usedPercent),
                                   kind: .memoryPressure, active: active, shown: &highlightedKinds))
            case .temperature:
                result.append(text(Format.celsius(snapshot?.sensors?.cpuCelsius),
                                   kind: .cpuTemperature, active: active, shown: &highlightedKinds))
            case .network:
                let net = snapshot?.network
                result.append(.text("↓" + Format.compactRate(net?.downPerSecond)
                                    + " ↑" + Format.compactRate(net?.upPerSecond), highlighted: false))
            }
        }

        if result.isEmpty { result = [.icon] }
        if !active.isSubset(of: highlightedKinds) {
            result.append(.text("⚠", highlighted: true))
        }
        return result
    }

    private static func text(_ string: String, kind: AlertKind, active: Set<AlertKind>,
                             shown: inout Set<AlertKind>) -> MenuBarSegment {
        let highlighted = active.contains(kind)
        if highlighted { shown.insert(kind) }
        return .text(string, highlighted: highlighted)
    }
}
