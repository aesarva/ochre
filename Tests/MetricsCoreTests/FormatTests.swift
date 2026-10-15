import Testing
@testable import MetricsCore

@Suite struct FormatTests {
    @Test func percent() {
        #expect(Format.percent(23.4) == "23%")
        #expect(Format.percent(142.3) == "142%")
        #expect(Format.percent(nil) == "—")
    }
    @Test func celsius() { #expect(Format.celsius(57.6) == "58°") }
    @Test func bytes() {
        #expect(Format.bytes(0) == "0 Б")
        #expect(Format.bytes(512) == "512 Б")
        #expect(Format.bytes(1536) == "1.5 КБ")
        #expect(Format.bytes(UInt64(14.2 * 1_073_741_824)) == "14.2 ГБ")
        #expect(Format.bytes(212 * 1_073_741_824) == "212 ГБ")
    }
    @Test func rates() {
        #expect(Format.rate(2.4 * 1_048_576) == "2.4 МБ/с")
        #expect(Format.compactRate(2.4 * 1_048_576) == "2.4M")
        #expect(Format.compactRate(120 * 1024) == "120K")
        #expect(Format.compactRate(300) == "0K")
        #expect(Format.compactRate(nil) == "—")
    }
    @Test func wattsAndRpm() {
        #expect(Format.watts(14.63) == "14.6 Вт")
        #expect(Format.rpm(2315) == "2315 об/мин")
    }
    @Test func roundingBoundariesMoveToNextUnit() {
        #expect(Format.bytes(1024 * 1024 - 1) == "1.0 МБ")
        #expect(Format.bytes(102_359) == "100 КБ")
        #expect(Format.compactRate(1024) == "1.0K")
    }
}

@Suite struct NonFiniteFormatTests {
    @Test func nonFiniteRendersAsDash() {
        #expect(Format.percent(.nan) == "—")
        #expect(Format.percent(.infinity) == "—")
        #expect(Format.celsius(.nan) == "—")
        #expect(Format.watts(.infinity) == "—")
    }
    @Test func integer() {
        #expect(Format.integer(34.6) == "35")
        #expect(Format.integer(.nan) == "—")
        #expect(Format.integer(nil) == "—")
    }
}
