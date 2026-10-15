/// Полоска GPU на карте кристалла: macOS отдаёт только общую загрузку, поэтому полоски
/// загораются слева направо пропорционально ей.
public enum GPUBars {
    public static let defaultCount = 16

    public static func litCount(utilization: Double, total: Int) -> Int {
        guard total > 0, utilization.isFinite, utilization > 0 else { return 0 }
        let u = min(utilization, 100)
        return max(1, Int((u / 100 * Double(total)).rounded()))
    }
}
