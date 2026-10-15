import Foundation

public struct ProcessCPUSample: Sendable {
    public let pid: Int32
    public let startTime: UInt64
    public let cpuTimeNanos: UInt64

    public init(pid: Int32, startTime: UInt64, cpuTimeNanos: UInt64) {
        self.pid = pid
        self.startTime = startTime
        self.cpuTimeNanos = cpuTimeNanos
    }
}

/// Turns cumulative per-process CPU time into percentages between consecutive updates.
public struct ProcessCPUTracker: Sendable {
    private struct Previous { let startTime: UInt64; let cpuTimeNanos: UInt64 }
    private var previous: [Int32: Previous] = [:]
    private var previousTime: TimeInterval?

    public init() {}

    /// Returns percent per pid; pids without a valid baseline (new, reused, counter decreased) are absent.
    public mutating func update(_ samples: [ProcessCPUSample], at time: TimeInterval) -> [Int32: Double] {
        var result: [Int32: Double] = [:]
        var next: [Int32: Previous] = [:]
        next.reserveCapacity(samples.count)
        let dt = previousTime.map { time - $0 }
        for s in samples {
            next[s.pid] = Previous(startTime: s.startTime, cpuTimeNanos: s.cpuTimeNanos)
            guard let dt, dt > 0, let old = previous[s.pid],
                  old.startTime == s.startTime, s.cpuTimeNanos >= old.cpuTimeNanos else { continue }
            result[s.pid] = Double(s.cpuTimeNanos - old.cpuTimeNanos) / (dt * 1e9) * 100
        }
        previous = next
        previousTime = time
        return result
    }
}
