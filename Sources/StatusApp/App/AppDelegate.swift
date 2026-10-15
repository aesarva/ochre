import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore?
    private var metricsStore: MetricsStore?
    private var popoverController: PopoverController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore()
        let store = MetricsStore(settings: settings)
        let defaults = UserDefaults.standard
        let tab = defaults.string(forKey: "PopoverTab").flatMap(PopoverTab.init(rawValue:)) ?? .overview
        let popover = PopoverController(store: store, initialTab: tab)
        let statusItem = StatusItemController(store: store, settings: settings) { [popover] button in
            popover.toggle(relativeTo: button)
        }
        settingsStore = settings
        metricsStore = store
        popoverController = popover
        statusItemController = statusItem
        store.start()
        if defaults.bool(forKey: "OpenPopoverOnLaunch") {
            Task { @MainActor [popover, statusItem] in
                try? await Task.sleep(for: .seconds(1))
                if let button = statusItem.button { popover.toggle(relativeTo: button) }
            }
        }
        if let dir = defaults.string(forKey: "SnapshotDir") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                SnapshotExporter.export(to: dir, store: store, settings: settings)
            }
        }
    }
}
