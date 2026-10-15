import Foundation

public struct Snapshot: Sendable {
    public var uptime: TimeInterval
    public var cpu: CPUStats?
    public var memory: MemoryStats?
    public var sensors: SensorStats?
    public var gpu: GPUStats?
    public var network: NetworkStats?
    public var disk: DiskStats?
    public var battery: BatteryStats?
    public var processes: [ProcessRow]?

    public init(uptime: TimeInterval) {
        self.uptime = uptime
    }
}
