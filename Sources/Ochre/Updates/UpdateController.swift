import Foundation
import MetricsCore
import Observation
import OSLog
import Sparkle

/// Владеет обновлятелем Sparkle и публикует состояние обновления для панели, значка и настроек.
@MainActor @Observable
final class UpdateController: NSObject, SPUUpdaterDelegate {
    /// Публикуются по отдельности и только при изменении: значок в строке меню следит лишь за `showsBadge`
    /// и не перерисовывается на каждый пришедший кусок скачивания.
    private(set) var state: UpdateState = .idle
    private(set) var showsBadge = false
    /// Sparkle готов к ручной проверке: обновлятель запущен и сейчас не идёт другая проверка.
    private(set) var canCheckNow = false
    let currentVersion: String
    let currentBuild: String

    @ObservationIgnored private var model = UpdateModel()
    @ObservationIgnored private let feedOverride: String?
    @ObservationIgnored private var driver: PanelUserDriver!
    @ObservationIgnored private var updater: SPUUpdater!
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    /// Снятое по сроку предложение проверяем заново, как только Sparkle закроет его сессию.
    @ObservationIgnored private var recheckAfterCycle = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.alexsarva.Ochre", category: "updates")

    /// `feedOverride` — лента вместо `SUFeedURL` (отладочный параметр `-UpdateFeedURL`);
    /// `offerLifetime` — срок неустановленного предложения (отладочный параметр `-UpdateOfferLifetime <секунды>`).
    init(feedOverride: String?, offerLifetime: Duration = .seconds(24 * 60 * 60), onShowPanel: @escaping () -> Void) {
        self.feedOverride = feedOverride
        let info = Bundle.main.infoDictionary ?? [:]
        currentVersion = info["CFBundleShortVersionString"] as? String ?? "?"
        currentBuild = info["CFBundleVersion"] as? String ?? "?"
        super.init()
        driver = PanelUserDriver(offerLifetime: offerLifetime,
                                 onEvent: { [weak self] in self?.apply($0) },
                                 onShowPanel: onShowPanel,
                                 onOfferExpired: { [weak self] in self?.recheckAfterCycle = true })
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        // Sparkle меняет canCheckForUpdates только в главном потоке.
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckNow = updater.canCheckForUpdates }
        }
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
            apply(.locationUnsupported)
            return
        }
        do {
            try updater.start()
        } catch {
            let ns = error as NSError
            logger.error("Updater failed to start \(ns.domain, privacy: .public) \(ns.code): \(ns.localizedDescription, privacy: .public)")
            apply(Self.event(for: error, userInitiated: true))
        }
    }

    func install() {
        guard case .available = state else { return }
        driver.install()
    }

    /// Ручная проверка; она же «Повторить» после ошибки.
    func checkNow() {
        guard canCheckNow else { return }
        updater.checkForUpdates()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        feedOverride
    }

    /// Конец любой проверки. Фоновая проверка без обновления сама интерфейс не зовёт — узнаём о ней только здесь.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        // Здесь Sparkle уже закрыл сессию и разрешает начать новую.
        if recheckAfterCycle {
            recheckAfterCycle = false
            updater.checkForUpdatesInBackground()
            return
        }
        switch UpdateErrors.cycleOutcome(failed: error != nil, sparkleCode: Self.sparkleCode(of: error)) {
        case .succeeded:
            if updateCheck == .updatesInBackground { apply(.backgroundCheckSucceeded) }
        case .installCanceled:
            // Отменён запрос пароля администратора. Sparkle закрыл сессию молча — предлагаем обновление снова,
            // иначе оно пропало бы до следующей суточной проверки.
            Task { @MainActor [weak self] in self?.updater.checkForUpdatesInBackground() }
        case .failed:
            break
        }
    }

    static func event(for error: any Error, userInitiated: Bool) -> UpdateEvent {
        UpdateErrors.event(sparkleCode: sparkleCode(of: error), message: error.localizedDescription,
                           userInitiated: userInitiated)
    }

    private static func sparkleCode(of error: (any Error)?) -> Int? {
        guard let error = error as NSError?, error.domain == SUSparkleErrorDomain else { return nil }
        return error.code
    }

    private func apply(_ event: UpdateEvent) {
        model.apply(event)
        if model.state != state { state = model.state }
        if model.showsBadge != showsBadge { showsBadge = model.showsBadge }
    }
}
