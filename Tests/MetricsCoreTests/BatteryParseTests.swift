import Testing
import Foundation
@testable import MetricsCore

@Suite struct BatteryParseTests {
    let props: [String: Any] = [
        "CurrentCapacity": 100, "MaxCapacity": 100, "IsCharging": false, "ExternalConnected": true,
        "CycleCount": 5, "Voltage": 13166,
        "InstantAmperage": NSNumber(value: UInt64(18_446_744_073_709_551_379)),   // −237 мА
        "BatteryData": ["FullChargeCapacity": 6256, "DesignCapacity": 6249]]

    @Test func parsesRealSample() throws {
        let b = try #require(BatteryStats.parse(props))
        #expect(b.percent == 100); #expect(b.cycleCount == 5); #expect(b.onExternalPower)
        #expect(b.healthPercent == 100)
        #expect(abs((b.powerWatts ?? 0) - 3.12) < 0.01)
    }

    @Test func nilWithoutCapacity() { #expect(BatteryStats.parse(["Voltage": 1]) == nil) }

    @Test func zeroDesignCapacityGivesNilHealth() throws {
        var p = props
        p["BatteryData"] = ["FullChargeCapacity": 6256, "DesignCapacity": 0]
        let b = try #require(BatteryStats.parse(p))
        #expect(b.healthPercent == nil)
    }

    @Test func missingVoltageGivesNilPower() throws {
        var p = props
        p["Voltage"] = nil
        let b = try #require(BatteryStats.parse(p))
        #expect(b.powerWatts == nil)
    }
}
