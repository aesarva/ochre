/// Разбивка ядер кластера на ряды карты кристалла: не больше `maxPerRow` в ряду, ряды поровну.
public enum DieMapRows {
    public static let maxPerRow = 12

    public static func split(count: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        let rows = (count + maxPerRow - 1) / maxPerRow
        let perRow = (count + rows - 1) / rows
        return stride(from: 0, to: count, by: perRow).map { $0..<min($0 + perRow, count) }
    }
}
