import Foundation

/// Reads aggregate disk throughput (IOBlockStorageDriver) and mounted local volume capacity.
public struct DiskCollector {
    private var readRate = CounterRate()
    private var writeRate = CounterRate()

    private var volumes: [VolumeInfo] = []
    private var volumesReadAt: TimeInterval = -.infinity
    /// Ёмкость томов меняется медленно, а её чтение стоит ~14 мс.
    private static let volumesMaxAge: TimeInterval = 30

    public init() {}

    public mutating func sample(now: TimeInterval) -> DiskStats? {
        var read: UInt64 = 0
        var write: UInt64 = 0
        for props in IORegistry.properties(ofClass: "IOBlockStorageDriver") {
            guard let stats = props["Statistics"] as? [String: Any] else { continue }
            read &+= (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write &+= (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        if now - volumesReadAt >= Self.volumesMaxAge {
            volumes = Self.mountedVolumes()
            volumesReadAt = now
        }
        let system = volumes.first { $0.path == "/" }?.available
        return DiskStats(readPerSecond: readRate.update(read, at: now),
                         writePerSecond: writeRate.update(write, at: now),
                         volumes: volumes, systemVolumeAvailable: system)
    }

    static func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsLocalKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityForImportantUsageKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                               options: .skipHiddenVolumes) else { return [] }
        return urls.compactMap { url -> VolumeInfo? in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsLocal == true,
                  let total = v.volumeTotalCapacity, total > 0,
                  let available = v.volumeAvailableCapacityForImportantUsage else { return nil }
            let path = url.path
            let name = v.volumeName ?? (path as NSString).lastPathComponent
            return VolumeInfo(name: name, path: path, total: UInt64(total),
                              available: UInt64(max(0, available)))
        }
    }
}
