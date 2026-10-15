import Foundation
import MetricsCore
import UserNotifications
import os

@MainActor
protocol AlertNotifier {
    func notify(_ event: AlertEvent)
}

@MainActor
final class UserNotificationNotifier: AlertNotifier {
    private let logger = Logger(subsystem: "local.statusapp", category: "notifications")
    private var authorizationRequested = false

    /// Asks for permission when it has not been decided yet. Denied/unavailable: one warning, no crash.
    func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
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
