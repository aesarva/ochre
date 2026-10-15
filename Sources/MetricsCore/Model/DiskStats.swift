public struct VolumeInfo: Sendable, Equatable {
    public let name: String
    public let path: String
    public let total: UInt64
    public let available: UInt64

    public init(name: String, path: String, total: UInt64, available: UInt64) {
        self.name = name
        self.path = path
        self.total = total
        self.available = available
    }
}

public struct DiskStats: Sendable, Equatable {
    public let readPerSecond: Double?
    public let writePerSecond: Double?
    public let volumes: [VolumeInfo]
    public let systemVolumeAvailable: UInt64?

    public init(readPerSecond: Double?, writePerSecond: Double?,
                volumes: [VolumeInfo], systemVolumeAvailable: UInt64?) {
        self.readPerSecond = readPerSecond
        self.writePerSecond = writePerSecond
        self.volumes = volumes
        self.systemVolumeAvailable = systemVolumeAvailable
    }
}
