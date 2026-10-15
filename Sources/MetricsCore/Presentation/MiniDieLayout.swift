/// Ячейка мини-кристалла в строке меню.
public struct MiniDieCell: Equatable, Sendable {
    public let row: Int
    public let column: Int
    public let load: Double

    public init(row: Int, column: Int, load: Double) {
        self.row = row
        self.column = column
        self.load = load
    }
}

/// Раскладка ядер в сетку не выше трёх рядов: кластеры по порядку (level 0 первым),
/// каждый с новой строки; при большем числе кластеров — все ядра подряд.
public enum MiniDieLayout {
    public static let maxRows = 3

    public static func columns(clusterSizes: [Int]) -> Int {
        let sizes = clusterSizes.filter { $0 > 0 }
        let total = sizes.reduce(0, +)
        guard total > 0 else { return 1 }
        for c in 1...total where rows(sizes, columns: c) <= maxRows { return c }
        return total
    }

    public static func cells(_ cpu: CPUStats) -> [MiniDieCell] {
        let clusters = Dictionary(grouping: cpu.cores, by: \.level)
            .sorted { $0.key < $1.key }
            .map { $0.value.sorted { $0.index < $1.index } }
        let c = columns(clusterSizes: clusters.map(\.count))
        let groups = clusters.count <= maxRows ? clusters : [clusters.flatMap { $0 }]
        var result: [MiniDieCell] = []
        var rowBase = 0
        for group in groups {
            for (i, core) in group.enumerated() {
                result.append(MiniDieCell(row: rowBase + i / c, column: i % c, load: core.percent))
            }
            rowBase += (group.count + c - 1) / c
        }
        return result
    }

    private static func rows(_ sizes: [Int], columns c: Int) -> Int {
        if sizes.count > maxRows { return (sizes.reduce(0, +) + c - 1) / c }
        return sizes.reduce(0) { $0 + ($1 + c - 1) / c }
    }
}
