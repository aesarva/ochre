import Testing
@testable import MetricsCore

@Suite struct HeatScaleTests {
    func rgb(_ c: HeatColor) -> (Double, Double, Double)? { if case let .rgb(r, g, b) = c { (r, g, b) } else { nil } }
    @Test func coldBelow20() {
        #expect(HeatScale.color(forLoad: 0) == .cold)
        #expect(HeatScale.color(forLoad: 19.9) == .cold)
    }
    @Test func anchors() {
        #expect(HeatScale.color(forLoad: 20) == HeatScale.amber)
        #expect(HeatScale.color(forLoad: 60) == HeatScale.ember)
        #expect(HeatScale.color(forLoad: 90) == HeatScale.hot)
        #expect(HeatScale.color(forLoad: 100) == HeatScale.hot)
        let amber = HeatColor.rgb(red: 1.0, green: 196.0 / 255.0, blue: 107.0 / 255.0)
        let ember = HeatColor.rgb(red: 1.0, green: 138.0 / 255.0, blue: 92.0 / 255.0)
        let hot = HeatColor.rgb(red: 1.0, green: 90.0 / 255.0, blue: 78.0 / 255.0)
        #expect(HeatScale.amber == amber)
        #expect(HeatScale.ember == ember)
        #expect(HeatScale.hot == hot)
    }
    @Test func interpolatesMidpoint() throws {
        let (r, g, b) = try #require(rgb(HeatScale.color(forLoad: 40)))
        #expect(abs(r - 1) < 1e-9); #expect(abs(g - 167/255) < 1e-9); #expect(abs(b - 99.5/255) < 1e-9)
    }
    @Test func clampsOutOfRange() {
        #expect(HeatScale.color(forLoad: 142) == HeatScale.hot)
        #expect(HeatScale.color(forLoad: -5) == .cold)
        #expect(HeatScale.color(forLoad: .nan) == .cold)
    }
    @Test func temperatureLevels() {
        #expect(HeatScale.temperatureLevel(59.9) == .neutral)
        #expect(HeatScale.temperatureLevel(60) == .amber)
        #expect(HeatScale.temperatureLevel(80) == .ember)
        #expect(HeatScale.temperatureLevel(95) == .hot)
        #expect(HeatLevel.neutral.color == .cold); #expect(HeatLevel.hot.color == HeatScale.hot)
    }
}

@Suite struct HeatFractionTests {
    @Test func clampsToUnitRange() {
        #expect(HeatScale.fraction(50) == 0.5)
        #expect(HeatScale.fraction(142) == 1)
        #expect(HeatScale.fraction(-5) == 0)
        #expect(HeatScale.fraction(.nan) == 0)
    }
}
