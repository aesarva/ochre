import Foundation
import Darwin

/// Lists processes with per-process CPU% (via `proc_pid_rusage`) and physical footprint.
public struct ProcessCollector {
    private var tracker = ProcessCPUTracker()
    private let timebase: (numer: UInt64, denom: UInt64)

    public init() {
        var info = mach_timebase_info_data_t()
        if mach_timebase_info(&info) != KERN_SUCCESS || info.denom == 0 {
            info = mach_timebase_info_data_t(numer: 1, denom: 1)
        }
        timebase = (UInt64(info.numer), UInt64(info.denom))
    }

    public mutating func sample(now: TimeInterval) -> [ProcessRow]? {
        let pids = Self.allPids()
        guard !pids.isEmpty else { return nil }

        struct Raw { let pid: Int32; let name: String; let memory: UInt64 }
        var raws: [Raw] = []
        var samples: [ProcessCPUSample] = []
        raws.reserveCapacity(pids.count)
        samples.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            var info = rusage_info_v4()
            let rc = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard rc == 0 else { continue }  // EPERM etc.: skip silently
            let ticks = info.ri_user_time &+ info.ri_system_time
            let nanos = Self.toNanos(ticks, numer: timebase.numer, denom: timebase.denom)
            samples.append(ProcessCPUSample(pid: pid, startTime: info.ri_proc_start_abstime, cpuTimeNanos: nanos))
            raws.append(Raw(pid: pid, name: Self.name(of: pid), memory: info.ri_phys_footprint))
        }
        guard !raws.isEmpty else { return nil }

        let cpu = tracker.update(samples, at: now)
        return raws.map { ProcessRow(pid: $0.pid, name: $0.name, cpuPercent: cpu[$0.pid], memoryBytes: $0.memory) }
            .sorted {
                let a = $0.cpuPercent ?? 0, b = $1.cpuPercent ?? 0
                return a != b ? a > b : $0.memoryBytes > $1.memoryBytes
            }
    }

    /// ticks * numer / denom without UInt64 overflow.
    static func toNanos(_ ticks: UInt64, numer: UInt64, denom: UInt64) -> UInt64 {
        let (hi, overflow) = ticks.multipliedReportingOverflow(by: numer)
        if !overflow { return hi / denom }
        let whole = ticks / denom, rem = ticks % denom
        return whole &* numer &+ rem &* numer / denom
    }

    private static func allPids() -> [Int32] {
        let bytes = proc_listallpids(nil, 0)
        guard bytes > 0 else { return [] }
        var buffer = [Int32](repeating: 0, count: Int(bytes) / MemoryLayout<Int32>.size + 64)
        let size = Int32(buffer.count * MemoryLayout<Int32>.size)
        let filled = buffer.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, size) }
        guard filled > 0 else { return [] }
        // Return value is the number of pids on modern macOS (bytes in older docs); clamp either way.
        return Array(buffer.prefix(min(Int(filled), buffer.count)))
    }

    private static func name(of pid: Int32) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        if proc_pidpath(pid, &path, UInt32(path.count)) > 0 {
            let last = (String(cString: path) as NSString).lastPathComponent
            if !last.isEmpty { return last }
        }
        var short = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &short, UInt32(short.count)) > 0 {
            let s = String(cString: short)
            if !s.isEmpty { return s }
        }
        return "pid \(pid)"
    }
}
