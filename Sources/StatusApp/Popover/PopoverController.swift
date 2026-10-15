import AppKit
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let store: MetricsStore
    private let initialTab: PopoverTab
    private let onOpenSettings: () -> Void
    private var popover: NSPopover?

    init(store: MetricsStore, initialTab: PopoverTab = .overview, onOpenSettings: @escaping () -> Void = {}) {
        self.store = store
        self.initialTab = initialTab
        self.onOpenSettings = onOpenSettings
        super.init()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { if self?.popover?.isShown == true { self?.close() } }
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: PopoverView(store: store, initialTab: initialTab, onOpenSettings: onOpenSettings))
            self.popover = popover
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            store.isPopoverOpen = true
        }
    }

    func close() {
        popover?.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPopoverOpen = false
        popover?.contentViewController = nil
        popover = nil
    }
}
