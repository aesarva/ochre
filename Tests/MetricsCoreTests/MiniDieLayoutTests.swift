import Testing
@testable import MetricsCore

@Suite struct MiniDieLayoutTests {
    func cpu(_ sizes: [Int]) -> CPUStats {
        var cores: [CoreLoad] = []; var i = 0
        // CPU нумерует ядра от старшего level к младшему (см. CoreTopology)
        for (level, size) in sizes.enumerated().reversed() {
            for _ in 0..<size { cores.append(CoreLoad(index: i, level: level, percent: Double(i))); i += 1 }
        }
        return CPUStats(totalPercent: 0,
                        clusters: sizes.indices.map { ClusterLoad(level: $0, name: "L\($0)", percent: 0) },
                        cores: cores)
    }
    @Test func columnsForKnownChips() {
        #expect(MiniDieLayout.columns(clusterSizes: [6, 12]) == 6)   // M5 Pro
        #expect(MiniDieLayout.columns(clusterSizes: [4, 4]) == 4)    // M1
        #expect(MiniDieLayout.columns(clusterSizes: [12, 4]) == 6)   // M3 Max
    }
    @Test func ultraFitsThreeRows() {
        #expect(MiniDieLayout.columns(clusterSizes: [16, 8]) == 8)
        #expect(Set(MiniDieLayout.cells(cpu([16, 8])).map(\.row)).count <= 3)
    }
    @Test func m5ProCells() {
        let cells = MiniDieLayout.cells(cpu([6, 12]))
        #expect(cells.count == 18)
        #expect(cells.filter { $0.row == 0 }.count == 6)
        #expect(cells.filter { $0.row == 1 }.count == 6)
        #expect(cells.filter { $0.row == 2 }.count == 6)
        #expect(cells.allSatisfy { $0.column < 6 })
    }
    @Test func singleClusterFallback() {
        #expect(MiniDieLayout.cells(cpu([10])).count == 10)
        #expect(MiniDieLayout.columns(clusterSizes: [10]) == 4)
    }
    @Test func manyClustersDoNotSplitRows() {
        #expect(MiniDieLayout.columns(clusterSizes: [2, 2, 2, 2]) == 3)
        #expect(Set(MiniDieLayout.cells(cpu([2, 2, 2, 2])).map(\.row)).count == 3)
    }
    @Test func zeroCores() {
        #expect(MiniDieLayout.columns(clusterSizes: []) == 1)
        #expect(MiniDieLayout.cells(CPUStats(totalPercent: 0, clusters: [], cores: [])).isEmpty)
    }
}

@Suite struct GPUBarsTests {
    @Test func litCount() {
        #expect(GPUBars.litCount(utilization: 0, total: 20) == 0)
        #expect(GPUBars.litCount(utilization: 1, total: 20) == 1)
        #expect(GPUBars.litCount(utilization: 50, total: 20) == 10)
        #expect(GPUBars.litCount(utilization: 100, total: 20) == 20)
        #expect(GPUBars.litCount(utilization: 140, total: 20) == 20)
        #expect(GPUBars.litCount(utilization: 50, total: 0) == 0)
    }
    @Test func parsesCoreCount() {
        let s = GPUCollector.parse([["PerformanceStatistics": ["Device Utilization %": 8], "gpu-core-count": 20]])
        #expect(s == GPUStats(utilizationPercent: 8, coreCount: 20))
        #expect(GPUCollector.parse([["PerformanceStatistics": ["Device Utilization %": 8]]])?.coreCount == nil)
    }
}
