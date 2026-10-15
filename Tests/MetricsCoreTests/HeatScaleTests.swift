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
        // Горчичная шкала — та же, что на сайте: #E3BF5C → #CC8F25 → #B4462A.
        let amber = HeatColor.rgb(red: 227.0 / 255.0, green: 191.0 / 255.0, blue: 92.0 / 255.0)
        let ember = HeatColor.rgb(red: 204.0 / 255.0, green: 143.0 / 255.0, blue: 37.0 / 255.0)
        let hot = HeatColor.rgb(red: 180.0 / 255.0, green: 70.0 / 255.0, blue: 42.0 / 255.0)
        #expect(HeatScale.amber == amber)
        #expect(HeatScale.ember == ember)
        #expect(HeatScale.hot == hot)
    }
    @Test func interpolatesMidpoint() throws {
        let (r, g, b) = try #require(rgb(HeatScale.color(forLoad: 40)))
        #expect(abs(r - 215.5/255) < 1e-9); #expect(abs(g - 167/255) < 1e-9); #expect(abs(b - 64.5/255) < 1e-9)
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

@Suite struct TileInkTests {
    // Цифры на плитке табло: светлые на графите и на «жаре», тёмные на янтаре и углях.
    @Test func lightOnColdAndHot() {
        #expect(HeatScale.tileInk(forLoad: 0) == .light)
        #expect(HeatScale.tileInk(forLoad: 19.9) == .light)
        #expect(HeatScale.tileInk(forLoad: 90) == .light)
        #expect(HeatScale.tileInk(forLoad: 142) == .light)
        #expect(HeatScale.tileInk(forLoad: .nan) == .light)
    }
    @Test func darkOnAmberAndEmber() {
        #expect(HeatScale.tileInk(forLoad: 20) == .dark)
        #expect(HeatScale.tileInk(forLoad: 60) == .dark)
        #expect(HeatScale.tileInk(forLoad: 89.9) == .dark)
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
