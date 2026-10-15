import AppKit
import MetricsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore?
    private var metricsStore: MetricsStore?
    private var popoverController: PopoverController?
    private var statusItemController: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private let notifier = UserNotificationNotifier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore()
        let store = MetricsStore(settings: settings)
        let defaults = UserDefaults.standard
        let tab = defaults.string(forKey: "PopoverTab").flatMap(PopoverTab.init(rawValue:)) ?? .overview
        let settingsWindow = SettingsWindowController(settings: settings)
        var popoverRef: PopoverController?
        let popover = PopoverController(store: store, initialTab: tab) {
            popoverRef?.close()
            settingsWindow.show()
        }
        popoverRef = popover
        self.settingsWindow = settingsWindow
        let statusItem = StatusItemController(store: store, settings: settings) { [popover] button in
            popover.toggle(relativeTo: button)
        }
        settingsStore = settings
        metricsStore = store
        popoverController = popover
        statusItemController = statusItem
        store.onAlertEvents = { [notifier] events in events.forEach(notifier.notify) }
        requestAuthorizationWhileAlertsEnabled(settings)
        store.start()
        if defaults.bool(forKey: "OpenPopoverOnLaunch") {
            Task { @MainActor [popover, statusItem] in
                try? await Task.sleep(for: .seconds(1))
                if let button = statusItem.button { popover.toggle(relativeTo: button) }
            }
        }
        if let dir = defaults.string(forKey: "SnapshotDir") {
            store.isPopoverOpen = true // sample processes and 2 s sensors before rendering
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                SnapshotExporter.export(to: dir, store: store, settings: settings)
            }
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
