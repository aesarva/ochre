import AppKit
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let store: MetricsStore
    private let popover = NSPopover()

    init(store: MetricsStore) {
        self.store = store
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: Text("StatusApp").padding())
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            store.isPopoverOpen = true
        }
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPopoverOpen = false
    }
}
