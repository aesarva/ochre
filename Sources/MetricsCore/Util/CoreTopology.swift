/// A group of cores sharing one performance level (e.g. "Performance", "Efficiency").
public struct PerfLevel: Sendable, Equatable {
    public let index: Int
    public let name: String
    public let coreCount: Int

    public init(index: Int, name: String, coreCount: Int) {
        self.index = index
        self.name = name
        self.coreCount = coreCount
    }
}

public enum CoreTopology {
    /// Maps each logical CPU to the `index` of its performance level.
    /// Logical CPUs are handed out from the level with the highest `index` down to the lowest.
    /// If `levels` is empty, a `coreCount` is negative, or the counts do not add up to
    /// `totalCores`, every entry is `0`.
    public static func levelForEachCore(levels: [PerfLevel], totalCores: Int) -> [Int] {
        let fallback = Array(repeating: 0, count: max(totalCores, 0))
        guard totalCores >= 0,
              !levels.isEmpty,
              levels.allSatisfy({ $0.coreCount >= 0 }),
              levels.reduce(0, { $0 + $1.coreCount }) == totalCores else {
            return fallback
        }
        var result: [Int] = []
        result.reserveCapacity(totalCores)
        for level in levels.sorted(by: { $0.index > $1.index }) {
            result.append(contentsOf: Array(repeating: level.index, count: level.coreCount))
        }
        return result
    }
}
