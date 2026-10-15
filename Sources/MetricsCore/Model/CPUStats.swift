public struct ClusterLoad: Sendable, Equatable {
    public let level: Int
    public let name: String
    public let percent: Double

    public init(level: Int, name: String, percent: Double) {
        self.level = level
        self.name = name
        self.percent = percent
    }
}

public struct CoreLoad: Sendable, Equatable {
    public let index: Int
    public let level: Int
    public let percent: Double

    public init(index: Int, level: Int, percent: Double) {
        self.index = index
        self.level = level
        self.percent = percent
    }
}

public struct CPUStats: Sendable, Equatable {
    public let totalPercent: Double
    /// Level 0 first.
    public let clusters: [ClusterLoad]
    public let cores: [CoreLoad]

    public init(totalPercent: Double, clusters: [ClusterLoad], cores: [CoreLoad]) {
        self.totalPercent = totalPercent
        self.clusters = clusters
        self.cores = cores
    }
}
