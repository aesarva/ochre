/// Cumulative CPU tick counters for one logical CPU (or an aggregate of them).
public struct CPUTicks: Sendable, Equatable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// CPU utilisation computed from two tick snapshots.
public enum CPULoad {
    /// Busy percentage between two snapshots of a single set of counters.
    /// `nil` when no ticks elapsed or any counter decreased.
    public static func percent(from: CPUTicks, to: CPUTicks) -> Double? {
        guard to.user >= from.user, to.system >= from.system,
              to.idle >= from.idle, to.nice >= from.nice else { return nil }
        let busy = (to.user - from.user) + (to.system - from.system) + (to.nice - from.nice)
        let total = busy + (to.idle - from.idle)
        guard total > 0 else { return nil }
        return Double(busy) * 100 / Double(total)
    }

    /// Busy percentage across many CPUs, weighted by ticks (sum of all per-CPU deltas).
    /// `nil` when the arrays differ in length or the aggregate computation is `nil`.
    public static func percent(from: [CPUTicks], to: [CPUTicks]) -> Double? {
        guard from.count == to.count else { return nil }
        return percent(from: aggregate(from), to: aggregate(to))
    }

    private static func aggregate(_ ticks: [CPUTicks]) -> CPUTicks {
        ticks.reduce(CPUTicks(user: 0, system: 0, idle: 0, nice: 0)) { sum, t in
            CPUTicks(user: sum.user &+ t.user,
                     system: sum.system &+ t.system,
                     idle: sum.idle &+ t.idle,
                     nice: sum.nice &+ t.nice)
        }
    }
}
