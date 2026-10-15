import Testing
import Foundation
@testable import MetricsCore

@Suite struct SensorTests {
    @Test func dropsGarbageAndDedupes() {
        let r = SensorAggregator.aggregate([
            .init(name: "PMU tdie1", celsius: 44.8), .init(name: "PMU tdie1", celsius: 45.4),
            .init(name: "PMU tdie2", celsius: 43.7), .init(name: "PMU tdev1", celsius: -9201.1),
            .init(name: "NAND CH0 temp", celsius: 37), .init(name: "als-temp", celsius: -1)])
        #expect(r.readings.map(\.name) == ["NAND CH0 temp", "PMU tdie1", "PMU tdie2"])
        #expect(r.readings[1].celsius == 45.4)
        #expect(r.cpu == 45.4)
    }
    @Test func aggregateWithoutGPUSensors() {
        #expect(SensorAggregator.aggregate([.init(name: "PMU tdie1", celsius: 50)]).gpu == nil)
        #expect(SensorAggregator.aggregate([.init(name: "GPU MTR Temp Sensor1", celsius: 61)]).gpu == 61)
    }
    @Test func smcDecode() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0xb0, 0x10, 0x45]) == 2315)
        #expect(SMCDecoder.decode(type: "ui8 ", bytes: [0x02]) == 2)
        #expect(SMCDecoder.decode(type: "fpe2", bytes: [0x24, 0x10]) == 2308)
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0x2d, 0x80]) == 45.5)
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00]) == nil)
        #expect(SMCDecoder.decode(type: "zzzz", bytes: [1, 2, 3, 4]) == nil)
    }
    @Test func noFansWhenFNumZero() {
        #expect(SensorCollector.fanCount(from: .nan) == 0)
        #expect(SensorCollector.fanCount(from: .infinity) == 0)
        #expect(SensorCollector.fanCount(from: 4e9) == 8)
        #expect(SensorCollector.fanCount(from: 1e300) == 8)
        #expect(SensorCollector.fanCount(from: -3) == 0)
        #expect(SensorCollector.fanCount(from: 2) == 2)
        #expect(SensorCollector.fanCount(from: nil) == 0)
        #expect(SensorCollector.fans(count: 0, read: { _ in 1000 }).isEmpty)
        #expect(SensorCollector.fans(count: 2, read: { $0 == 0 ? 2315 : nil }) == [.init(index: 0, rpm: 2315)])
    }
}
