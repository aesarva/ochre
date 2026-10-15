public struct InterfaceCounters: Sendable, Equatable {
    public let rx: UInt64
    public let tx: UInt64

    public init(rx: UInt64, tx: UInt64) {
        self.rx = rx
        self.tx = tx
    }
}

public struct NetworkStats: Sendable, Equatable {
    /// Name of the primary interface, or `nil` when traffic is summed over all `en*` interfaces.
    public let interface: String?
    public let downPerSecond: Double?
    public let upPerSecond: Double?
    public let totalDown: UInt64
    public let totalUp: UInt64

    public init(interface: String?, downPerSecond: Double?, upPerSecond: Double?,
                totalDown: UInt64, totalUp: UInt64) {
        self.interface = interface
        self.downPerSecond = downPerSecond
        self.upPerSecond = upPerSecond
        self.totalDown = totalDown
        self.totalUp = totalUp
    }
}
