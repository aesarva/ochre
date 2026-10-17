import Testing
@testable import MetricsCore

@Suite struct KeyedCountersTests {
    @Test func firstSampleIsBaseline() {
        var k = KeyedCounters<String>()
        #expect(k.advance(["a": 100], at: 0) == nil)
        let step = k.advance(["a": 160], at: 2)
        #expect(step?.delta == 60); #expect(step?.elapsed == 2)
    }
    @Test func newDeviceStartsFromItsOwnBaseline() {
        var k = KeyedCounters<String>()
        _ = k.advance(["disk0": 1_000], at: 0)
        // Подключили диск с накопленными 100 ГБ: они не должны попасть в скорость.
        #expect(k.advance(["disk0": 1_100, "disk4": 100_000_000_000], at: 2)?.delta == 100)
        #expect(k.advance(["disk0": 1_200, "disk4": 100_000_000_050], at: 4)?.delta == 150)
    }
    @Test func removedDeviceAndCounterResetAreIgnored() {
        var k = KeyedCounters<String>()
        _ = k.advance(["a": 500, "b": 900], at: 0)
        #expect(k.advance(["a": 520, "b": 10], at: 2)?.delta == 20)   // b обнулился — только новая база
        #expect(k.advance(["a": 540], at: 4)?.delta == 20)             // b пропал
    }
    @Test func failedReadKeepsBaseline() {
        var k = KeyedCounters<String>()
        _ = k.advance(["a": 100], at: 0)
        #expect(k.advance([:], at: 2) == nil)                         // ошибка чтения — не новая база из нулей
        let step = k.advance(["a": 300], at: 4)
        #expect(step?.delta == 200); #expect(step?.elapsed == 4)
    }
    @Test func longGapGivesAverageRate() {
        var k = KeyedCounters<String>()
        _ = k.advance(["a": 0], at: 0)
        let step = k.advance(["a": 28_800], at: 28_800)               // 8 часов сна
        #expect(step.map { Double($0.delta) / $0.elapsed } == 1)
    }
    @Test func nonAdvancingClockGivesNoStep() {
        var k = KeyedCounters<String>()
        _ = k.advance(["a": 1], at: 5)
        #expect(k.advance(["a": 2], at: 5) == nil)
    }
}
