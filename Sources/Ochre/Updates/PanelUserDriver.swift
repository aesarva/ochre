import Foundation
import MetricsCore
import OSLog
import Sparkle

/// Интерфейс Sparkle без окон: переводит его вызовы в события `UpdateEvent`, а показ остаётся панели и значку.
/// Решения, которых Sparkle ждёт от пользователя, принимаются здесь: установка — по кнопке в панели,
/// перезапуск — сразу, без второго нажатия.
@MainActor
final class PanelUserDriver: NSObject, SPUUserDriver {
    private let onEvent: (UpdateEvent) -> Void
    private let onShowPanel: () -> Void
    private let onOfferExpired: () -> Void
    /// Ответ Sparkle на найденное обновление; вызывается ровно один раз.
    private var pendingChoice: ((SPUUserUpdateChoice) -> Void)?
    /// Пока ответ не дан, Sparkle не проверяет обновления. Через сутки предложение снимается и проверяется заново,
    /// чтобы Ochre, работающий неделями, не предлагал 1.1, когда уже вышла 1.2.
    private var offerExpiry: Task<Void, Never>?
    private let offerLifetime: Duration
    /// Ручная проверка: её результат и ошибки показываются, фоновой — нет.
    private var userInitiated = false
    private let logger = Logger(subsystem: "com.alexsarva.Ochre", category: "updates")

    /// `offerLifetime` — сколько держать неустановленное предложение (сутки; меньше — только для отладки).
    init(offerLifetime: Duration, onEvent: @escaping (UpdateEvent) -> Void, onShowPanel: @escaping () -> Void,
         onOfferExpired: @escaping () -> Void) {
        self.offerLifetime = offerLifetime
        self.onEvent = onEvent
        self.onShowPanel = onShowPanel
        self.onOfferExpired = onOfferExpired
    }

    func install() {
        reply(.install)
    }

    private func reply(_ choice: SPUUserUpdateChoice) {
        offerExpiry?.cancel()
        offerExpiry = nil
        guard let reply = pendingChoice else { return }
        pendingChoice = nil
        reply(choice)
    }

    // MARK: Проверка

    func show(_ request: SPUUpdatePermissionRequest,
              reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        userInitiated = true
        onEvent(.checkStarted(userInitiated: true))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void) {
        userInitiated = false
        pendingChoice = reply
        offerExpiry?.cancel()
        offerExpiry = Task { [weak self] in
            guard let lifetime = self?.offerLifetime else { return }
            try? await Task.sleep(for: lifetime, clock: .continuous)
            guard !Task.isCancelled, let self, self.pendingChoice != nil else { return }
            // Sparkle обрабатывает ответ асинхронно, и сессия ещё открыта: новую проверку контроллер запустит,
            // когда Sparkle сообщит о конце цикла.
            self.onEvent(.offerExpired)
            self.onOfferExpired()
            self.reply(.dismiss)
        }
        onEvent(.found(version: appcastItem.displayVersionString,
                       notesURL: appcastItem.releaseNotesURL ?? appcastItem.infoURL))
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        logger.info("No update: \((error as NSError).code)")
        onEvent(.notFound(userInitiated: userInitiated))
        userInitiated = false
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let ns = error as NSError
        logger.error("Updater error \(ns.domain, privacy: .public) \(ns.code): \(ns.localizedDescription, privacy: .public)")
        onEvent(UpdateController.event(for: error, userInitiated: userInitiated))
        userInitiated = false
        acknowledgement()
    }

    // MARK: Скачивание и установка

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        onEvent(.downloadStarted)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        onEvent(.expectedLength(expectedContentLength))
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        onEvent(.received(length))
    }

    func showDownloadDidStartExtractingUpdate() {
        onEvent(.installing)
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        onEvent(.installing)
        reply(.install)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void) {
        onEvent(.installing)
        // Ochre сам закрытию не мешает, но если что-то его задержало, просим ещё раз, а не висим на «Установка…».
        guard !applicationTerminated else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            retryTerminatingApplication()
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {
        onShowPanel()
    }

    func dismissUpdateInstallation() {
        offerExpiry?.cancel()
        offerExpiry = nil
        pendingChoice = nil
        userInitiated = false
        onEvent(.dismissed)
    }
}
