import Foundation

public struct HistoryPoint: Sendable, Equatable {
    public let t: TimeInterval
    public let value: Double

    public init(t: TimeInterval, value: Double) {
        self.t = t
        self.value = value
    }
}

public enum Series: Hashable, Sendable {
    case cpuTotal, cluster(Int), memoryUsed
    case networkDown, networkUp, diskRead, diskWrite
}

/// Time-based history: one ring buffer per series, trimmed by timestamp on read.
public struct MetricsHistory: Sendable {
    public let window: TimeInterval
    public let capacity: Int
    private var buffers: [Series: RingBuffer<HistoryPoint>] = [:]

    public init(window: TimeInterval = 600, capacity: Int = 600) {
        self.window = window
        self.capacity = capacity
    }

    public mutating func record(_ snapshot: Snapshot) {
        let t = snapshot.uptime
        func add(_ series: Series, _ value: Double?) {
            guard let value else { return }
            buffers[series, default: RingBuffer(capacity: capacity)].append(HistoryPoint(t: t, value: value))
        }
        if let cpu = snapshot.cpu {
            add(.cpuTotal, cpu.totalPercent)
            for c in cpu.clusters { add(.cluster(c.level), c.percent) }
        }
        add(.memoryUsed, snapshot.memory?.usedPercent)
        add(.networkDown, snapshot.network?.downPerSecond)
        add(.networkUp, snapshot.network?.upPerSecond)
        add(.diskRead, snapshot.disk?.readPerSecond)
        add(.diskWrite, snapshot.disk?.writePerSecond)
    }

    public func points(_ series: Series, now: TimeInterval) -> [HistoryPoint] {
        guard let buffer = buffers[series] else { return [] }
        let cutoff = now - window
        return buffer.elements.filter { $0.t >= cutoff }
    }
}
