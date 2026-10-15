import Darwin

/// Reads physical memory breakdown, pressure level and swap usage.
public struct MemoryCollector {
    public init() {}

    public func sample() -> MemoryStats? {
        guard let memsize = Sysctl.int("hw.memsize"), memsize > 0 else { return nil }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        let page = UInt64(pageSize)

        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let app = (internalPages > purgeable ? internalPages - purgeable : 0) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let cached = (UInt64(stats.external_page_count) + purgeable) * page
        let total = UInt64(memsize)
        let used = min(app + wired + compressed, total)

        let pressure = Sysctl.int("kern.memorystatus_vm_pressure_level").flatMap(MemoryPressure.init(rawValue:))
        let swap = Sysctl.swapUsage()

        return MemoryStats(total: total, used: used, app: app, wired: wired,
                           compressed: compressed, cached: cached,
                           swapUsed: swap?.used ?? 0, swapTotal: swap?.total ?? 0,
                           pressure: pressure)
    }
}
