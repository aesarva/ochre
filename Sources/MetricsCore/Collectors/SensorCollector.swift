import Foundation
import CPrivateAPI

/// Температуры (IOHIDEventSystemClient), вентиляторы и мощность системы (AppleSMC).
/// Не `Sendable`: владеет HID-клиентом и SMC-соединением.
public final class SensorCollector {
    private let hidClient: IOHIDEventSystemClient?
    private var smcConnection: UInt32 = 0
    private let smcOpen: Bool

    public init() {
        if let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) {
            let matching: [String: Any] = [
                "PrimaryUsagePage": NSNumber(value: 0xff00 as Int32),
                "PrimaryUsage": NSNumber(value: 5 as Int32),
            ]
            _ = IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)
            hidClient = client
        } else {
            hidClient = nil
        }
        var conn: UInt32 = 0
        if smc_open(&conn) == 0 {
            smcConnection = conn
            smcOpen = true
        } else {
            smcOpen = false
        }
    }

    deinit {
        if smcOpen { smc_close(smcConnection) }
    }

    public func sample() -> SensorStats? {
        let agg = SensorAggregator.aggregate(readTemperatures())
        let fanCount = smcValue("FNum").map { Int($0) } ?? 0
        let fans = Self.fans(count: fanCount) { smcValue("F\($0)Ac") }
        let power = smcValue("PSTR")
        if agg.readings.isEmpty && fans.isEmpty && power == nil { return nil }
        return SensorStats(temperatures: agg.readings, cpuCelsius: agg.cpu, gpuCelsius: agg.gpu,
                           fans: fans, systemPowerWatts: power)
    }

    /// Собирает список вентиляторов, пропуская нечитаемые.
    static func fans(count: Int, read: (Int) -> Double?) -> [FanReading] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { i in read(i).map { FanReading(index: i, rpm: $0) } }
    }

    private func readTemperatures() -> [TemperatureReading] {
        guard let client = hidClient, let services = IOHIDEventSystemClientCopyServices(client) else { return [] }
        var result: [TemperatureReading] = []
        for i in 0..<CFArrayGetCount(services) {
            guard let raw = CFArrayGetValueAtIndex(services, i) else { continue }
            let service = unsafeBitCast(raw, to: IOHIDServiceClient.self)
            guard let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String,
                  let event = IOHIDServiceClientCopyEvent(service, 15, 0, 0) else { continue }
            let value = IOHIDEventGetFloatValue(event, 15 << 16)
            if value.isFinite { result.append(TemperatureReading(name: name, celsius: value)) }
        }
        return result
    }

    private func smcValue(_ key: String) -> Double? {
        guard smcOpen, key.utf8.count == 4 else { return nil }
        var type = [CChar](repeating: 0, count: 5)
        var bytes = [UInt8](repeating: 0, count: 32)
        var size: UInt32 = 0
        let rc = key.withCString { smc_read(smcConnection, $0, &type, &bytes, &size) }
        guard rc == 0 else { return nil }
        let typeString = String(cString: type)
        return SMCDecoder.decode(type: typeString, bytes: Array(bytes.prefix(Int(size))))
    }
}
