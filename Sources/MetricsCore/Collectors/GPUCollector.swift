import Foundation

public struct GPUCollector {
    public init() {}

    /// Максимальная загрузка среди всех `IOAccelerator`.
    public func sample() -> GPUStats? {
        let values = IORegistry.properties(ofClass: "IOAccelerator").compactMap { props -> Double? in
            guard let stats = props["PerformanceStatistics"] as? [String: Any],
                  let n = stats["Device Utilization %"] as? NSNumber else { return nil }
            return n.doubleValue
        }
        guard let top = values.max() else { return nil }
        return GPUStats(utilizationPercent: Swift.min(Swift.max(top, 0), 100))
    }
}
