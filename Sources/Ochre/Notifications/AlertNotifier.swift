import Foundation
import MetricsCore
import UserNotifications
import os

@MainActor
protocol AlertNotifier {
    func notify(_ event: AlertEvent)
}

@MainActor
final class UserNotificationNotifier: NSObject, AlertNotifier, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.alexsarva.Ochre", category: "notifications")
    private var authorizationRequested = false
    private var loggedNoBundle = false
    private var isDelegate = false

    /// Пока открыта панель или настройки, приложение активно, а без делегата система не показывает
    /// уведомления активного приложения — оповещение терялось бы, хотя cooldown уже пошёл.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func becomeDelegateIfNeeded() {
        guard !isDelegate else { return }
        isDelegate = true
        UNUserNotificationCenter.current().delegate = self
    }

    /// `UNUserNotificationCenter.current()` raises an NSException without a bundle identifier (bare binary / `swift run`).
    private func notificationsAvailable() -> Bool {
        if Bundle.main.bundleIdentifier != nil { return true }
        if !loggedNoBundle {
            loggedNoBundle = true
            logger.warning("No bundle identifier (not running from an .app); notifications disabled")
        }
        return false
    }

    /// Asks for permission when it has not been decided yet. Denied/unavailable: one warning, no crash.
    func requestAuthorizationIfNeeded() {
        guard notificationsAvailable(), !authorizationRequested else { return }
        becomeDelegateIfNeeded()
        authorizationRequested = true
        let logger = logger
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .notDetermined else {
                if status == .denied { logger.warning("Notifications are denied; alerts are highlighted only") }
                return
            }
            do {
                if try await center.requestAuthorization(options: [.alert, .sound]) == false {
                    logger.warning("Notification authorization was not granted; alerts are highlighted only")
                }
            } catch {
                logger.warning("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func notify(_ event: AlertEvent) {
        guard notificationsAvailable() else { return }
        requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(event.kind.rawValue)-\(UUID())", content: content, trigger: nil)
        let logger = logger
        let kind = event.kind.rawValue
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                logger.info("Notification added: \(kind, privacy: .public)")
            } catch {
                logger.warning("Notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
