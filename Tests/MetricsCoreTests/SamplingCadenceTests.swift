import Testing
@testable import MetricsCore

@Suite struct SamplingCadenceTests {
    @Test func closedPanelUsesSetting() {
        #expect(SamplingCadence.interval(popoverOpen: false, setting: 5) == 5)
        #expect(SamplingCadence.interval(popoverOpen: false, setting: 1) == 1)
    }
    @Test func openPanelRefreshesEveryTwoSecondsAtMost() {
        #expect(SamplingCadence.interval(popoverOpen: true, setting: 5) == 2)
        #expect(SamplingCadence.interval(popoverOpen: true, setting: 2) == 2)
        #expect(SamplingCadence.interval(popoverOpen: true, setting: 1) == 1)
    }
}
