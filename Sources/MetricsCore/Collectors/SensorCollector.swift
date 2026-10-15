import Foundation
import CPrivateAPI

/// Температуры (IOHIDEventSystemClient), вентиляторы и мощность системы (AppleSMC).
/// Не `Sendable`: владеет HID-клиентом и SMC-соединением.
public final class SensorCollector {
    private let hidClient: IOHIDEventSystemClient?
    private var smcConnection: UInt32 = 0
    private let smcOpen: Bool
    private var lastTemperatures: [TemperatureReading] = []
    private var temperaturesReadAt: TimeInterval = -.infinity

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

    /// `maxTemperatureAge` — сколько секунд можно переиспользовать прошлые температуры:
    /// опрос ~77 HID-датчиков стоит ~80 мс, а температуры меняются медленно.
    public func sample(maxTemperatureAge: TimeInterval = 0) -> SensorStats? {
        let now = MonotonicClock.now()
        if now - temperaturesReadAt >= maxTemperatureAge {
            lastTemperatures = readTemperatures()
            temperaturesReadAt = now
        }
        let agg = SensorAggregator.aggregate(lastTemperatures)
        let fanCount = Self.fanCount(from: smcValue("FNum"))
        let fans = Self.fans(count: fanCount) { smcValue("F\($0)Ac") }
        let power = smcValue("PSTR")
        if agg.readings.isEmpty && fans.isEmpty && power == nil { return nil }
        return SensorStats(temperatures: agg.readings, cpuCelsius: agg.cpu, gpuCelsius: agg.gpu,
                           fans: fans, systemPowerWatts: power)
    }

    /// Безопасно переводит значение SMC `FNum` в число вентиляторов: нечисло/бесконечность → 0, максимум 8.
    static func fanCount(from value: Double?) -> Int {
        guard let value, value.isFinite else { return 0 }
        if value >= 8 { return 8 }
        return max(Int(value.rounded()), 0)
    }

    /// Собирает список вентиляторов, пропуская нечитаемые.
    static func fans(count: Int, read: (Int) -> Double?) -> [FanReading] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { i in read(i).map { FanReading(index: i, rpm: $0) } }
    }

    /// Служебные HID-сервисы с именами; список дорог в получении, поэтому кэшируется.
    private var cachedServices: [(name: String, service: IOHIDServiceClient)] = []
    private var servicesRefreshedAt: TimeInterval = -.infinity
    private static let servicesRefreshInterval: TimeInterval = 60

    private func refreshServices() {
        cachedServices = []
        guard let client = hidClient, let services = IOHIDEventSystemClientCopyServices(client) else { return }
        for i in 0..<CFArrayGetCount(services) {
            guard let raw = CFArrayGetValueAtIndex(services, i) else { continue }
            let service = unsafeBitCast(raw, to: IOHIDServiceClient.self)
            if let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String {
                cachedServices.append((name, service))
            }
        }
    }

    private func readEvents() -> [TemperatureReading] {
        var result: [TemperatureReading] = []
        for (name, service) in cachedServices {
            guard let event = IOHIDServiceClientCopyEvent(service, 15, 0, 0) else { continue }
            let value = IOHIDEventGetFloatValue(event, 15 << 16)
            if value.isFinite { result.append(TemperatureReading(name: name, celsius: value)) }
        }
        return result
    }

    private func readTemperatures() -> [TemperatureReading] {
        let now = MonotonicClock.now()
        if cachedServices.isEmpty || now - servicesRefreshedAt > Self.servicesRefreshInterval {
            refreshServices()
            servicesRefreshedAt = now
        }
        let readings = readEvents()
        if readings.isEmpty && !cachedServices.isEmpty {
            // Сервисы могли устареть — один раз обновляем и читаем заново.
            refreshServices()
            servicesRefreshedAt = now
            return readEvents()
        }
        return readings
    }

    private func smcValue(_ key: String) -> Double? {
        guard smcOpen, key.utf8.count == 4 else { return nil }
        var type = [CChar](repeating: 0, count: 5)
        var bytes = [UInt8](repeating: 0, count: 32)
        var size: UInt32 = 0
        let rc = key.withCString { smc_read(smcConnection, $0, &type, &bytes, &size) }
        guard rc == 0 else { return nil }
        let typeString = String(decoding: type.prefix(4).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return SMCDecoder.decode(type: typeString, bytes: Array(bytes.prefix(Int(size))))
    }
}
