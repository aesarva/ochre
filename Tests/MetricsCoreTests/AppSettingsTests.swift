import Testing
import Foundation
@testable import MetricsCore

@Suite struct AppSettingsTests {
    @Test func roundTrip() {
        var s = AppSettings.default; s.refreshInterval = 5; s.menuBarItems = [.icon, .network]
        #expect(AppSettings.decode(s.encoded()) == s)
    }
    @Test func garbageDecodesToDefault() {
        #expect(AppSettings.decode(nil) == .default)
        #expect(AppSettings.decode(Data("{oops".utf8)) == .default)
    }
    @Test func partialDecodeKeepsKnownFields() {
        let s = AppSettings.decode(Data(#"{"refreshInterval":5}"#.utf8))
        #expect(s.refreshInterval == 5); #expect(s.menuBarItems == [.cpuPercent, .temperature])
        #expect(s.alerts == .default)
    }
    @Test func invalidIntervalFallsBackTo2() {
        #expect(AppSettings.decode(Data(#"{"refreshInterval":0.01}"#.utf8)).refreshInterval == 2)
    }
    @Test func badAlertsFallBackWithoutLosingOtherFields() {
        let json = #"{"alerts":{"bogusKind":{"enabled":true,"threshold":1,"duration":1}},"refreshInterval":5}"#
        let s = AppSettings.decode(Data(json.utf8))
        #expect(s.refreshInterval == 5)
        #expect(s.alerts == .default)
    }
    @Test func unknownMenuBarItemFallsBackToDefaultItems() {
        let s = AppSettings.decode(Data(#"{"menuBarItems":["bogus"],"refreshInterval":1}"#.utf8))
        #expect(s.menuBarItems == [.cpuPercent, .temperature])
        #expect(s.refreshInterval == 1)
    }
}
