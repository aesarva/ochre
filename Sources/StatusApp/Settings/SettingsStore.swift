import Foundation
import Observation
import MetricsCore

@MainActor
@Observable
final class SettingsStore {
    static let defaultsKey = "settings.v1"

    var settings: AppSettings {
        didSet { defaults.set(settings.encoded(), forKey: Self.defaultsKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = AppSettings.decode(defaults.data(forKey: Self.defaultsKey))
    }
}
