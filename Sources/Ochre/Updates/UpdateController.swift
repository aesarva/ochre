import Foundation
import MetricsCore
import Observation
import OSLog
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
        let bundle = Bundle.main.bundleURL
        let readOnly = (try? bundle.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
        guard UpdateLocation.canUpdate(bundlePath: bundle.path, volumeIsReadOnly: readOnly) else {
            model.apply(.locationUnsupported)
            return
        }
        do {
            try updater.start()
        } catch {
            let ns = error as NSError
            Logger(subsystem: "com.alexsarva.Ochre", category: "updates")
                .error("Updater failed to start \(ns.domain, privacy: .public) \(ns.code): \(ns.localizedDescription, privacy: .public)")
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

    /// Фоновая проверка без обновления сама интерфейс не зовёт — узнаём о ней только здесь.
    /// «Обновлений нет» Sparkle сообщает ошибкой `SUNoUpdateError`, это тоже успешная проверка.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard updateCheck == .updatesInBackground else { return }
        let noUpdate = (error as NSError?).map {
            $0.domain == SUSparkleErrorDomain && $0.code == Int(SUError.noUpdateError.rawValue)
        }
        if noUpdate ?? true { model.apply(.backgroundCheckSucceeded) }
    }
}
