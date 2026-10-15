public enum MemoryPressure: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4
}

public struct MemoryStats: Sendable, Equatable {
    public let total: UInt64
    public let used: UInt64
    public let app: UInt64
    public let wired: UInt64
    public let compressed: UInt64
    public let cached: UInt64
    public let swapUsed: UInt64
    public let swapTotal: UInt64
    public let pressure: MemoryPressure?

    public var usedPercent: Double {
        total > 0 ? Double(used) * 100 / Double(total) : 0
    }

    public init(total: UInt64, used: UInt64, app: UInt64, wired: UInt64, compressed: UInt64,
                cached: UInt64, swapUsed: UInt64, swapTotal: UInt64, pressure: MemoryPressure?) {
        self.total = total
        self.used = used
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressure = pressure
    }
}
