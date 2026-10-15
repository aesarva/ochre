import AppKit
import Observation
import MetricsCore

@MainActor
final class StatusItemController {
    private let store: MetricsStore
    private let settings: SettingsStore
    private let onClick: (NSStatusBarButton) -> Void
    private let statusItem: NSStatusItem
    var button: NSStatusBarButton? { statusItem.button }

    init(store: MetricsStore, settings: SettingsStore, onClick: @escaping (NSStatusBarButton) -> Void) {
        self.store = store
        self.settings = settings
        self.onClick = onClick
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        render()
        observe()
    }

    @objc private func clicked() {
        guard let button = statusItem.button else { return }
        onClick(button)
    }

    private func observe() {
        withObservationTracking {
            _ = store.latest
            _ = store.activeAlerts
            _ = settings.settings.menuBarItems
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observe()
            }
        }
    }

    private func render() {
        let cpu = store.latest.map { store.history.points(.cpuTotal, now: $0.uptime).map(\.value) } ?? []
        let segments = MenuBarContent.segments(
            items: settings.settings.menuBarItems,
            snapshot: store.latest,
            cpuHistory: cpu,
            active: store.activeAlerts
        )
        statusItem.button?.attributedTitle = MenuBarRenderer.attributedTitle(segments)
        statusItem.button?.setAccessibilityLabel(MenuBarContent.spokenLabel(segments))
    }
}
