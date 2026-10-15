import Testing
@testable import MetricsCore

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
