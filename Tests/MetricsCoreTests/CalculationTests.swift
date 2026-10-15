import Testing
@testable import MetricsCore

@Suite struct CalculationTests {
    @Test func firstUpdateIsNil() {
        var r = CounterRate()
        #expect(r.update(1000, at: 10) == nil)
        #expect(r.update(3000, at: 12) == 1000)
    }
    @Test func counterDecreaseGivesNil() {
        var r = CounterRate()
        _ = r.update(5000, at: 0)
        #expect(r.update(100, at: 1) == nil)      // сброс интерфейса
        #expect(r.update(1100, at: 2) == 1000)    // новая база
    }
    @Test func longGapGivesAverageRate() {
        var r = CounterRate()
        _ = r.update(0, at: 0)
        #expect(r.update(28_800, at: 28_800) == 1) // 8 часов сна
    }
    @Test func cpuPercent() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let b = CPUTicks(user: 200, system: 100, idle: 1100, nice: 100)
        #expect(CPULoad.percent(from: a, to: b) == 40)
        #expect(CPULoad.percent(from: a, to: a) == nil)
        let idle0 = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let idle1 = CPUTicks(user: 0, system: 0, idle: 500, nice: 0)
        #expect(CPULoad.percent(from: [a, idle0], to: [b, idle1]) == 20)   // 200 busy / 1000 total
    }
    @Test func topologySuperPerformance() {   // Mac17,9: cpu0…11 → level 1, cpu12…17 → level 0
        let levels = [PerfLevel(index: 0, name: "Super", coreCount: 6),
                      PerfLevel(index: 1, name: "Performance", coreCount: 12)]
        #expect(CoreTopology.levelForEachCore(levels: levels, totalCores: 18)
                == Array(repeating: 1, count: 12) + Array(repeating: 0, count: 6))
    }
    @Test func topologyM1() {
        let levels = [PerfLevel(index: 0, name: "Performance", coreCount: 4),
                      PerfLevel(index: 1, name: "Efficiency", coreCount: 4)]
        #expect(CoreTopology.levelForEachCore(levels: levels, totalCores: 8) == [1, 1, 1, 1, 0, 0, 0, 0])
    }
    @Test func topologyMismatchFallsBackToZero() {
        #expect(CoreTopology.levelForEachCore(levels: [], totalCores: 3) == [0, 0, 0])
    }
}
