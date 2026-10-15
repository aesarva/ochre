import Darwin

/// Samples per-core CPU ticks via Mach and reports load since the previous sample.
public struct CPUCollector {
    private var previous: [CPUTicks]?

    public init() {}

    /// The first call returns `nil` (no baseline yet); any failure also returns `nil`.
    public mutating func sample() -> CPUStats? {
        guard let current = Self.readTicks(), !current.isEmpty else { return nil }
        defer { previous = current }
        guard let prev = previous, prev.count == current.count else { return nil }
        guard let total = CPULoad.percent(from: prev, to: current) else { return nil }

        let levels = Self.effectiveLevels(Self.readLevels(), coreCount: current.count)
        let coreLevels = CoreTopology.levelForEachCore(levels: levels, totalCores: current.count)

        var cores: [CoreLoad] = []
        for i in current.indices {
            let pct = CPULoad.percent(from: prev[i], to: current[i]) ?? 0
            cores.append(CoreLoad(index: i, level: coreLevels[i], percent: pct))
        }

        var clusters: [ClusterLoad] = []
        for level in levels.sorted(by: { $0.index < $1.index }) {
            let idx = current.indices.filter { coreLevels[$0] == level.index }
            let from = idx.map { prev[$0] }
            let to = idx.map { current[$0] }
            guard let pct = CPULoad.percent(from: from, to: to) else { continue }
            clusters.append(ClusterLoad(level: level.index, name: level.name, percent: pct))
        }
        return CPUStats(totalPercent: total, clusters: clusters, cores: cores)
    }

    /// Levels pass through only if their core counts add up to `coreCount`;
    /// otherwise a single "CPU" level covering all cores is used.
    static func effectiveLevels(_ levels: [PerfLevel], coreCount: Int) -> [PerfLevel] {
        if !levels.isEmpty, levels.reduce(0, { $0 + $1.coreCount }) == coreCount {
            return levels
        }
        return [PerfLevel(index: 0, name: "CPU", coreCount: coreCount)]
    }

    private static func readLevels()-> [PerfLevel] {
        guard let count = Sysctl.int("hw.nperflevels"), count > 0 else {
            let cores = Sysctl.int("hw.ncpu") ?? 0
            return [PerfLevel(index: 0, name: "CPU", coreCount: cores)]
        }
        var levels: [PerfLevel] = []
        for n in 0..<count {
            let name = Sysctl.string("hw.perflevel\(n).name") ?? "CPU"
            let cores = Sysctl.int("hw.perflevel\(n).logicalcpu") ?? 0
            levels.append(PerfLevel(index: n, name: name, coreCount: cores))
        }
        return levels
    }

    private static func readTicks() -> [CPUTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return nil }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }
        let stride = Int(CPU_STATE_MAX)
        guard Int(infoCount) >= Int(cpuCount) * stride else { return nil }
        var result: [CPUTicks] = []
        result.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let base = i * stride
            result.append(CPUTicks(
                user: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                idle: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                nice: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))))
        }
        return result
    }
}
