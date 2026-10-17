import Foundation
import os

/// Owns all collectors and produces one `Snapshot` per call.
public actor Sampler {
    private var cpu = CPUCollector()
    private let memory = MemoryCollector()
    private var network = NetworkCollector()
    private var disk = DiskCollector()
    private let battery = BatteryCollector()
    private let gpu = GPUCollector()
    private let sensors = SensorCollector()
    private var processes = ProcessCollector()

    private let logger = Logger(subsystem: "com.alexsarva.Ochre", category: "sampler")
    /// Collectors currently known to be unavailable (already logged).
    private var unavailable: Set<String> = []
    /// Collectors that legitimately return nil on their first call.
    private var warmedUp: Set<String> = []

    public init() {}

    public func sample(includeProcesses: Bool) -> Snapshot {
        let now = MonotonicClock.now()
        var snapshot = Snapshot(uptime: now)
        snapshot.cpu = track("CPU", firstCallMayBeNil: true, cpu.sample())
        snapshot.memory = track("память", memory.sample())
        snapshot.sensors = track("датчики", sensors.sample(maxTemperatureAge: includeProcesses ? 2 : 15,
                                                                      cpuOnly: !includeProcesses))
        snapshot.gpu = track("GPU", gpu.sample())
        snapshot.network = track("сеть", firstCallMayBeNil: true, network.sample(now: now))
        snapshot.disk = track("диск", firstCallMayBeNil: true, disk.sample(now: now))
        snapshot.battery = track("батарея", battery.sample())
        if includeProcesses {
            snapshot.processes = track("процессы", firstCallMayBeNil: true, processes.sample(now: now))
        }
        return snapshot
    }

    /// Logs one notice when a collector turns unavailable; again only after a success.
    private func track<T>(_ name: String, firstCallMayBeNil: Bool = false, _ value: T?) -> T? {
        if value != nil {
            unavailable.remove(name)
            warmedUp.insert(name)
        } else if firstCallMayBeNil && !warmedUp.contains(name) {
            warmedUp.insert(name)
        } else if unavailable.insert(name).inserted {
            logger.notice("\(name, privacy: .public) недоступен")
        }
        return value
    }
}
