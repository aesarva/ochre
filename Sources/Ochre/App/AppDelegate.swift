import AppKit
import MetricsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore?
    private var metricsStore: MetricsStore?
    private var popoverController: PopoverController?
    private var statusItemController: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var updateController: UpdateController?
    private let notifier = UserNotificationNotifier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacySettings()
        let settings = SettingsStore()
        let store = MetricsStore(settings: settings)
        // Debug args come only from the command line (argument domain), never from persisted defaults.
        let defaults = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        let tab = (defaults["PopoverTab"] as? String).flatMap(PopoverTab.init(rawValue:)) ?? .overview
        weak var popoverRef: PopoverController?
        weak var statusItemRef: StatusItemController?
        let updates = UpdateController(feedOverride: defaults["UpdateFeedURL"] as? String) {
            if let popover = popoverRef, !popover.isShown, let button = statusItemRef?.button {
                popover.toggle(relativeTo: button)
            }
        }
        let settingsWindow = SettingsWindowController(settings: settings, store: store, updates: updates)
        let popover = PopoverController(store: store, updates: updates, initialTab: tab) {
            popoverRef?.close()
            settingsWindow.show()
        }
        popoverRef = popover
        self.settingsWindow = settingsWindow
        let statusItem = StatusItemController(store: store, settings: settings, updates: updates) { [popover] button in
            popover.toggle(relativeTo: button)
        }
        statusItemRef = statusItem
        settingsStore = settings
        metricsStore = store
        popoverController = popover
        statusItemController = statusItem
        updateController = updates
        updates.start()
        store.onAlertEvents = { [notifier] events in events.forEach(notifier.notify) }
        requestAuthorizationWhileAlertsEnabled(settings)
        store.start()
        if Self.flag(defaults["OpenPopoverOnLaunch"]) {
            Task { @MainActor [popover, statusItem] in
                try? await Task.sleep(for: .seconds(1))
                if let button = statusItem.button { popover.toggle(relativeTo: button) }
            }
        }
        if let dir = defaults["SnapshotDir"] as? String {
            store.isPopoverOpen = true // sample processes and 2 s sensors before rendering
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                SnapshotExporter.export(to: dir, store: store, settings: settings, updates: updates)
                await settingsWindow.exportSnapshots(to: URL(fileURLWithPath: dir, isDirectory: true))
                store.isPopoverOpen = false
            }
        }
    }

    /// Настройки старых сборок лежат под прежним bundle id — забираем их при первом запуске.
    private func migrateLegacySettings() {
        let legacies = SettingsMigration.legacyBundleIdentifiers
            .filter { $0 != Bundle.main.bundleIdentifier }
            .compactMap(UserDefaults.init(suiteName:))
        SettingsMigration.migrate(key: SettingsStore.defaultsKey, fromFirstOf: legacies, to: UserDefaults.standard)
    }

    private static func flag(_ value: Any?) -> Bool {
        switch value {
        case let b as Bool: b
        case let s as String: ["YES", "TRUE", "1"].contains(s.uppercased())
        default: false
        }
    }

    /// Requests notification permission at launch and whenever settings change with a rule enabled.
    private func requestAuthorizationWhileAlertsEnabled(_ settings: SettingsStore) {
        if settings.settings.alerts.rules.values.contains(where: \.enabled) {
            notifier.requestAuthorizationIfNeeded()
        }
        withObservationTracking {
            _ = settings.settings
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.requestAuthorizationWhileAlertsEnabled(settings)
            }
        }
    }
}
