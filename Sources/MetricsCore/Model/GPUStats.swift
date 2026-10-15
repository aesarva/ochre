public struct GPUStats: Sendable, Equatable {
    public let utilizationPercent: Double
    /// Число ядер GPU (`gpu-core-count`), если система его отдаёт.
    public let coreCount: Int?

    public init(utilizationPercent: Double, coreCount: Int? = nil) {
        self.utilizationPercent = utilizationPercent
        self.coreCount = coreCount
    }
}
