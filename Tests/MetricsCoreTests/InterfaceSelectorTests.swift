import Testing
@testable import MetricsCore

@Suite struct InterfaceSelectorTests {
    let c: [String: InterfaceCounters] = [
        "en0": .init(rx: 100, tx: 10), "en1": .init(rx: 5, tx: 1), "utun3": .init(rx: 90, tx: 9)]
    @Test func picksPrimary() throws {
        let r = try #require(InterfaceSelector.select(c, primary: "en0"))
        #expect(r.name == "en0"); #expect(r.counters == .init(rx: 100, tx: 10))
    }
    @Test func sumsEnWhenNoPrimary() throws {
        let r = try #require(InterfaceSelector.select(c, primary: nil))
        #expect(r.name == nil); #expect(r.counters == .init(rx: 105, tx: 11))
    }
    @Test func nilWithoutEthernet() {
        #expect(InterfaceSelector.select(["lo0": .init(rx: 1, tx: 1)], primary: "utun9") == nil)
    }
}
