public struct BatteryCollector {
    public init() {}

    public func sample() -> BatteryStats? {
        guard let props = IORegistry.properties(ofClass: "AppleSmartBattery").first else { return nil }
        return BatteryStats.parse(props)
    }
}
