import Foundation

public struct ProcessRow: Sendable, Equatable, Identifiable {
    public let pid: Int32
    public let name: String
    /// nil until a previous sample of the same process exists. May exceed 100 on multi-core.
    public let cpuPercent: Double?
    public let memoryBytes: UInt64
    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuPercent: Double?, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}
