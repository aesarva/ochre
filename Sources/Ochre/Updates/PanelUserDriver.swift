import Foundation
import MetricsCore
import Sparkle

/// Интерфейс Sparkle без окон: переводит его вызовы в события `UpdateEvent`, а показ остаётся панели и значку.
/// Решения, которых Sparkle ждёт от пользователя, принимаются здесь: установка — по кнопке в панели,
/// перезапуск — сразу, без второго нажатия.
@MainActor
final class PanelUserDriver: NSObject, SPUUserDriver {
    private let onEvent: (UpdateEvent) -> Void
    private let onShowPanel: () -> Void
    /// Ответ Sparkle на найденное обновление; вызывается ровно один раз.
    private var pendingChoice: ((SPUUserUpdateChoice) -> Void)?
    /// Ручная проверка: её результат и ошибки показываются, фоновой — нет.
    private var userInitiated = false

    init(onEvent: @escaping (UpdateEvent) -> Void, onShowPanel: @escaping () -> Void) {
        self.onEvent = onEvent
        self.onShowPanel = onShowPanel
    }

    func install() {
        guard let reply = pendingChoice else { return }
        pendingChoice = nil
        reply(.install)
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
        onEvent(.found(version: appcastItem.displayVersionString,
                       notesURL: appcastItem.releaseNotesURL ?? appcastItem.infoURL))
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        onEvent(.notFound(userInitiated: userInitiated))
        userInitiated = false
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        onEvent(.error(message: error.localizedDescription, userInitiated: userInitiated))
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
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {
        onShowPanel()
    }

    func dismissUpdateInstallation() {
        pendingChoice = nil
        onEvent(.dismissed)
    }
}
