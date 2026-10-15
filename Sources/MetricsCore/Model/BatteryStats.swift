import Foundation

public struct BatteryStats: Sendable, Equatable {
    public let percent: Double
    public let isCharging: Bool
    public let onExternalPower: Bool
    public let cycleCount: Int?
    public let healthPercent: Double?
    public let powerWatts: Double?
}

extension BatteryStats {
    /// Разбирает свойства сервиса `AppleSmartBattery`. Без `CurrentCapacity`/`MaxCapacity` — `nil`.
    static func parse(_ props: [String: Any]) -> BatteryStats? {
        guard let current = number(props["CurrentCapacity"])?.doubleValue,
              let max = number(props["MaxCapacity"])?.doubleValue, max > 0 else { return nil }
        let percent = Swift.min(Swift.max(current / max * 100, 0), 100)

        let data = props["BatteryData"] as? [String: Any]
        var health: Double?
        let full = number(props["AppleRawMaxCapacity"])?.doubleValue ?? number(data?["FullChargeCapacity"])?.doubleValue
        let design = number(data?["DesignCapacity"])?.doubleValue ?? number(props["DesignCapacity"])?.doubleValue
        if let full, let design, design > 0 {
            health = Swift.min(full / design * 100, 100)
        }

        var watts: Double?
        if let mV = number(props["Voltage"])?.doubleValue, let amps = number(props["InstantAmperage"]) {
            watts = abs(mV * Double(amps.int64Value)) / 1e6
        }

        return BatteryStats(
            percent: percent,
            isCharging: number(props["IsCharging"])?.boolValue ?? false,
            onExternalPower: number(props["ExternalConnected"])?.boolValue ?? false,
            cycleCount: number(props["CycleCount"]).map { $0.intValue },
            healthPercent: health,
            powerWatts: watts)
    }

    private static func number(_ value: Any?) -> NSNumber? { value as? NSNumber }
}
