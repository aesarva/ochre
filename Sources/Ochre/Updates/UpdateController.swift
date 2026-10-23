import Foundation
import MetricsCore
import Observation
import Sparkle

/// Владеет обновлятелем Sparkle и публикует состояние обновления для панели, значка и настроек.
@MainActor @Observable
final class UpdateController: NSObject, SPUUpdaterDelegate {
    private(set) var model = UpdateModel()
    let currentVersion: String
    let currentBuild: String

    @ObservationIgnored private let feedOverride: String?
    @ObservationIgnored private var driver: PanelUserDriver!
    @ObservationIgnored private var updater: SPUUpdater!

    /// `feedOverride` — лента вместо `SUFeedURL` (отладочный параметр `-UpdateFeedURL`).
    init(feedOverride: String?, onShowPanel: @escaping () -> Void) {
        self.feedOverride = feedOverride
        let info = Bundle.main.infoDictionary ?? [:]
        currentVersion = info["CFBundleShortVersionString"] as? String ?? "?"
        currentBuild = info["CFBundleVersion"] as? String ?? "?"
        super.init()
        driver = PanelUserDriver(onEvent: { [weak self] in self?.model.apply($0) }, onShowPanel: onShowPanel)
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
    }

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) { updater.automaticallyChecksForUpdates = newValue }
        }
    }

    func start() {
        do {
            try updater.start()
        } catch {
            model.apply(PanelUserDriver.event(for: error, userInitiated: true))
        }
    }

    func install() {
        guard case .available = model.state else { return }
        driver.install()
    }

    /// Ручная проверка; она же «Повторить» после ошибки.
    func checkNow() {
        updater.checkForUpdates()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        feedOverride
    }
}
