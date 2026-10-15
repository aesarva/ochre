import Foundation

public enum AlertKind: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case cpuTemperature, cpuLoad, memoryPressure, diskSpace
}

public struct AlertRuleConfig: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var threshold: Double
    public var duration: TimeInterval

    public init(enabled: Bool, threshold: Double, duration: TimeInterval) {
        self.enabled = enabled
        self.threshold = threshold
        self.duration = duration
    }
}

public struct AlertConfig: Codable, Sendable, Equatable {
    public var rules: [AlertKind: AlertRuleConfig]

    public init(rules: [AlertKind: AlertRuleConfig]) {
        self.rules = rules
    }

    public static let `default` = AlertConfig(rules: [
        .cpuTemperature: AlertRuleConfig(enabled: true, threshold: 95, duration: 30),
        .cpuLoad: AlertRuleConfig(enabled: true, threshold: 90, duration: 60),
        .memoryPressure: AlertRuleConfig(enabled: true, threshold: 0, duration: 0),
        .diskSpace: AlertRuleConfig(enabled: true, threshold: 10, duration: 0),
    ])

    public func rule(_ kind: AlertKind) -> AlertRuleConfig {
        rules[kind] ?? Self.default.rules[kind]
            ?? AlertRuleConfig(enabled: false, threshold: 0, duration: 0)
    }
}

public struct AlertEvent: Sendable, Equatable {
    public let kind: AlertKind
    public let title: String
    public let body: String

    public init(kind: AlertKind, title: String, body: String) {
        self.kind = kind
        self.title = title
        self.body = body
    }
}
