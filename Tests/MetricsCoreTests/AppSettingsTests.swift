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
    @Test func hugeAlertValuesAreClamped() throws {
        let json = #"{"enabled":true,"threshold":1e300,"duration":-5}"#
        let rule = try JSONDecoder().decode(AlertRuleConfig.self, from: Data(json.utf8))
        #expect(rule.threshold == 1000)
        #expect(rule.duration == 0)
        let long = try JSONDecoder().decode(AlertRuleConfig.self, from: Data(#"{"enabled":false,"threshold":-1,"duration":99999}"#.utf8))
        #expect(long.threshold == 0 && long.duration == 3600)
    }
    @Test func settingsWithHugeAlertValuesDecode() {
        let json = #"{"refreshInterval":5,"alerts":{"rules":{"cpuLoad":{"enabled":true,"threshold":1e300,"duration":1e300}}}}"#
        let s = AppSettings.decode(Data(json.utf8))
        #expect(s.refreshInterval == 5)
        #expect(s.alerts.rule(.cpuLoad).threshold == 1000)
        #expect(s.alerts.rule(.cpuLoad).duration == 3600)
    }
}
