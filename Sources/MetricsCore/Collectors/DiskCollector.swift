import Foundation

/// Reads aggregate disk throughput (IOBlockStorageDriver) and mounted local volume capacity.
/// Counters are compared per drive, so attaching a drive or a failed registry read never shows up as a burst.
public struct DiskCollector {
    private var reads = KeyedCounters<UInt64>()
    private var writes = KeyedCounters<UInt64>()

    private var volumes: [VolumeInfo] = []
    private var volumesReadAt: TimeInterval = -.infinity
    /// Ёмкость томов меняется медленно, а её чтение стоит ~14 мс.
    private static let volumesMaxAge: TimeInterval = 30

    public init() {}

    public mutating func sample(now: TimeInterval) -> DiskStats? {
        var read: [UInt64: UInt64] = [:]
        var write: [UInt64: UInt64] = [:]
        for entry in IORegistry.entries(ofClass: "IOBlockStorageDriver", keys: ["Statistics"]) {
            guard let stats = entry.properties["Statistics"] as? [String: Any] else { continue }
            read[entry.id] = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value
            write[entry.id] = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value
        }
        let r = reads.advance(read, at: now)
        let w = writes.advance(write, at: now)
        if now - volumesReadAt >= Self.volumesMaxAge {
            volumes = Self.mountedVolumes()
            volumesReadAt = now
        }
        let system = volumes.first { $0.path == "/" }?.available
        return DiskStats(readPerSecond: r.map { Double($0.delta) / $0.elapsed },
                         writePerSecond: w.map { Double($0.delta) / $0.elapsed },
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
