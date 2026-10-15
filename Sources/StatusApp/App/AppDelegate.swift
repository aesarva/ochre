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
        let popover = PopoverController(store: store)
        let statusItem = StatusItemController(store: store, settings: settings) { [popover] button in
            popover.toggle(relativeTo: button)
        }
        settingsStore = settings
        metricsStore = store
        popoverController = popover
        statusItemController = statusItem
        store.start()
    }
}
