import Foundation

public struct AlertEngine: Sendable {
    private let cooldown: TimeInterval
    private let maxGap: TimeInterval
    private var lastEvaluation: TimeInterval?
    private var since: [AlertKind: TimeInterval] = [:]
    private var lastNotified: [AlertKind: TimeInterval] = [:]
    /// Порог, при котором копится `since`: при его смене прежнее время превышения уже ничего не значит.
    private var thresholds: [AlertKind: Double] = [:]

    public init(cooldown: TimeInterval = 600, maxGap: TimeInterval = 15) {
        self.cooldown = cooldown
        self.maxGap = maxGap
    }

    public mutating func evaluate(_ snapshot: Snapshot, config: AlertConfig,
                                  now: TimeInterval) -> (active: Set<AlertKind>, events: [AlertEvent]) {
        if let last = lastEvaluation, now - last > maxGap {
            since.removeAll()
        }
        lastEvaluation = now

        var active: Set<AlertKind> = []
        var events: [AlertEvent] = []
        for kind in AlertKind.allCases {
            let rule = config.rule(kind)
            if thresholds[kind] != rule.threshold {
                thresholds[kind] = rule.threshold
                since[kind] = nil
            }
            if rule.enabled && Self.conditionHolds(kind, snapshot, rule) {
                since[kind] = since[kind] ?? now
            } else {
                since[kind] = nil
            }
            guard rule.enabled, let start = since[kind], now - start >= rule.duration else { continue }
            active.insert(kind)
            // Cooldown действует и между эпизодами: значение, скачущее через порог, не шлёт уведомление на каждый скачок.
            if lastNotified[kind].map({ now - $0 >= cooldown }) ?? true {
                lastNotified[kind] = now
                events.append(Self.event(kind, snapshot, rule))
            }
        }
        return (active, events)
    }

    /// Unavailable (nil) values never satisfy a condition.
    private static func conditionHolds(_ kind: AlertKind, _ s: Snapshot, _ rule: AlertRuleConfig) -> Bool {
        switch kind {
        case .cpuTemperature:
            return s.sensors?.cpuCelsius.map { $0 > rule.threshold } ?? false
        case .cpuLoad:
            return s.cpu.map { $0.totalPercent > rule.threshold } ?? false
        case .memoryPressure:
            return s.memory?.pressure == .critical
        case .diskSpace:
            return s.disk?.systemVolumeAvailable.map { Double($0) < rule.threshold * 1_073_741_824 } ?? false
        }
    }

    private static func event(_ kind: AlertKind, _ s: Snapshot, _ rule: AlertRuleConfig) -> AlertEvent {
        switch kind {
        case .cpuTemperature:
            return AlertEvent(kind: kind, title: "Перегрев CPU",
                              body: String(format: "Температура CPU %.0f °C дольше %.0f с",
                                           s.sensors?.cpuCelsius ?? 0, rule.duration))
        case .cpuLoad:
            return AlertEvent(kind: kind, title: "Высокая нагрузка CPU",
                              body: String(format: "Загрузка CPU %.0f %% дольше %.0f с",
                                           s.cpu?.totalPercent ?? 0, rule.duration))
        case .memoryPressure:
            return AlertEvent(kind: kind, title: "Критическое давление памяти",
                              body: "Закройте лишние приложения")
        case .diskSpace:
            return AlertEvent(kind: kind, title: "Мало места на диске",
                              body: "Свободно \(Format.bytes(s.disk?.systemVolumeAvailable)) на системном томе")
        }
    }
}
