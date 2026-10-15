public struct TemperatureReading: Sendable, Equatable {
    public let name: String
    public let celsius: Double

    public init(name: String, celsius: Double) {
        self.name = name
        self.celsius = celsius
    }
}

public struct FanReading: Sendable, Equatable {
    public let index: Int
    public let rpm: Double

    public init(index: Int, rpm: Double) {
        self.index = index
        self.rpm = rpm
    }
}

public struct SensorStats: Sendable, Equatable {
    public let temperatures: [TemperatureReading]
    public let cpuCelsius: Double?
    public let gpuCelsius: Double?
    public let fans: [FanReading]
    public let systemPowerWatts: Double?

    public init(temperatures: [TemperatureReading], cpuCelsius: Double?, gpuCelsius: Double?,
                fans: [FanReading], systemPowerWatts: Double?) {
        self.temperatures = temperatures
        self.cpuCelsius = cpuCelsius
        self.gpuCelsius = gpuCelsius
        self.fans = fans
        self.systemPowerWatts = systemPowerWatts
    }
}
