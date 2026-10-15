import Testing
@testable import MetricsCore

@Suite struct SensorPresentationTests {
    // Реальный набор с этой машины после SensorAggregator (сортировка по имени).
    let readings: [TemperatureReading] = [
        .init(name: "NAND CH0 temp", celsius: 34), .init(name: "PMU tcal", celsius: 52),
        .init(name: "PMU tdie1", celsius: 41), .init(name: "PMU tdie10", celsius: 40),
        .init(name: "PMU tdie2", celsius: 43), .init(name: "PMU tdie9", celsius: 39),
        .init(name: "gas gauge battery", celsius: 30)]

    @Test func groupsCPUSensorsWithNumericOrder() {
        let g = SensorPresentation.group(readings)
        #expect(g.cpu.map(\.name) == ["CPU, датчик 1", "CPU, датчик 2", "CPU, датчик 9", "CPU, датчик 10"])
        #expect(g.cpuMax == 43)
        #expect(g.cpuAverage == 40.75)
    }

    @Test func renamesKnownOtherSensors() {
        let g = SensorPresentation.group(readings)
        #expect(g.other.map(\.name) == ["SSD", "Батарея", "Контроллер питания"])
        #expect(g.other.map(\.celsius) == [34, 30, 52])
    }

    @Test func keepsUnknownNamesAndHandlesNoCPU() {
        let g = SensorPresentation.group([.init(name: "Mystery sensor", celsius: 50)])
        #expect(g.cpu.isEmpty); #expect(g.cpuMax == nil); #expect(g.cpuAverage == nil)
        #expect(g.other == [.init(name: "Mystery sensor", celsius: 50)])
    }

    @Test func accSensorsCountAsCPU() {
        let g = SensorPresentation.group([.init(name: "pACC MTR Temp Sensor3", celsius: 60),
                                          .init(name: "eACC MTR Temp Sensor1", celsius: 50)])
        #expect(g.cpu.map(\.name) == ["CPU, датчик 1", "CPU, датчик 3"])
    }
}
