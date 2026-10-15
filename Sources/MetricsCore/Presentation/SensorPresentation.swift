/// Датчики температуры, сгруппированные для вкладки «Сенсоры».
public struct SensorGroups: Sendable, Equatable {
    /// Датчики кристалла CPU с понятными именами, по возрастанию номера.
    public let cpu: [TemperatureReading]
    public let cpuMax: Double?
    public let cpuAverage: Double?
    /// Остальные датчики: известные — с понятными именами в фиксированном порядке, затем неизвестные по алфавиту.
    public let other: [TemperatureReading]
}

public enum SensorPresentation {
    private static let cpuMarkers = ["tdie", "pACC", "eACC"]
    private static let knownNames: [(raw: String, name: String)] = [
        ("NAND CH0 temp", "SSD"),
        ("gas gauge battery", "Батарея"),
        ("PMU tcal", "Контроллер питания"),
    ]

    public static func group(_ readings: [TemperatureReading]) -> SensorGroups {
        let isCPU = { (r: TemperatureReading) in cpuMarkers.contains { r.name.contains($0) } }
        let cpu = readings.filter(isCPU)
            .map { (number: trailingNumber($0.name), celsius: $0.celsius) }
            .sorted { $0.number < $1.number }
            .map { TemperatureReading(name: "CPU, датчик \($0.number)", celsius: $0.celsius) }
        let rest = readings.filter { !isCPU($0) }
        let known = knownNames.compactMap { k in
            rest.first { $0.name == k.raw }.map { TemperatureReading(name: k.name, celsius: $0.celsius) }
        }
        let unknown = rest.filter { r in !knownNames.contains { $0.raw == r.name } }.sorted { $0.name < $1.name }
        let values = cpu.map(\.celsius)
        return SensorGroups(cpu: cpu,
                            cpuMax: values.max(),
                            cpuAverage: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count),
                            other: known + unknown)
    }

    private static func trailingNumber(_ name: String) -> Int {
        Int(String(name.reversed().prefix { $0.isNumber }.reversed())) ?? 0
    }
}
