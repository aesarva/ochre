import Foundation

public struct GPUCollector {
    public init() {}

    /// Максимальная загрузка среди всех `IOAccelerator`.
    public func sample() -> GPUStats? {
        Self.parse(IORegistry.properties(ofClass: "IOAccelerator"))
    }

    /// Чистая часть: загрузка (`PerformanceStatistics["Device Utilization %"]`) и число ядер (`gpu-core-count`).
    static func parse(_ services: [[String: Any]]) -> GPUStats? {
        let values = services.compactMap { props -> Double? in
            guard let stats = props["PerformanceStatistics"] as? [String: Any],
                  let n = stats["Device Utilization %"] as? NSNumber else { return nil }
            return n.doubleValue
        }
        guard let top = values.max() else { return nil }
        let cores = services.compactMap { ($0["gpu-core-count"] as? NSNumber)?.intValue }.filter { $0 > 0 }.max()
        return GPUStats(utilizationPercent: Swift.min(Swift.max(top, 0), 100), coreCount: cores)
    }
}
