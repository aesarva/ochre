import Testing
import Foundation
@testable import MetricsCore

@Suite struct SettingsMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.migration.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func copiesLegacySettingsWhenCurrentHasNone() {
        let legacy = makeDefaults(), current = makeDefaults()
        legacy.set(Data("old".utf8), forKey: "settings.v1")
        #expect(SettingsMigration.migrate(key: "settings.v1", from: legacy, to: current))
        #expect(current.data(forKey: "settings.v1") == Data("old".utf8))
    }

    @Test func keepsCurrentSettingsWhenPresent() {
        let legacy = makeDefaults(), current = makeDefaults()
        legacy.set(Data("old".utf8), forKey: "settings.v1")
        current.set(Data("new".utf8), forKey: "settings.v1")
        #expect(!SettingsMigration.migrate(key: "settings.v1", from: legacy, to: current))
        #expect(current.data(forKey: "settings.v1") == Data("new".utf8))
    }

    @Test func doesNothingWithoutLegacySettings() {
        let legacy = makeDefaults(), current = makeDefaults()
        #expect(!SettingsMigration.migrate(key: "settings.v1", from: legacy, to: current))
        #expect(current.data(forKey: "settings.v1") == nil)
    }

    @Test func takesSettingsFromNewestLegacyThatHasThem() {
        let newest = makeDefaults(), oldest = makeDefaults(), current = makeDefaults()
        newest.set(Data("mid".utf8), forKey: "settings.v1")
        oldest.set(Data("old".utf8), forKey: "settings.v1")
        #expect(SettingsMigration.migrate(key: "settings.v1", fromFirstOf: [newest, oldest], to: current))
        #expect(current.data(forKey: "settings.v1") == Data("mid".utf8))
    }

    @Test func fallsBackToOlderLegacy() {
        let newest = makeDefaults(), oldest = makeDefaults(), current = makeDefaults()
        oldest.set(Data("old".utf8), forKey: "settings.v1")
        #expect(SettingsMigration.migrate(key: "settings.v1", fromFirstOf: [newest, oldest], to: current))
        #expect(current.data(forKey: "settings.v1") == Data("old".utf8))
    }

    @Test func legacyIdentifiersAreNewestFirst() {
        #expect(SettingsMigration.legacyBundleIdentifiers == ["com.alexsarva.StatusApp", "local.statusapp.StatusApp"])
    }
}
